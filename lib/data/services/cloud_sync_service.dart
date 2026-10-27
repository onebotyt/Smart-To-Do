import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/task.dart';
import '../repositories/task_repository.dart';

/// User profile data returned by the cloud backend
class CloudUser {
  final String id;
  final String email;
  final String displayName;
  final String photoUrl;
  final bool isPremium;
  final DateTime? premiumExpiresAt;

  const CloudUser({
    required this.id,
    required this.email,
    required this.displayName,
    this.photoUrl = '',
    this.isPremium = false,
    this.premiumExpiresAt,
  });

  factory CloudUser.fromJson(Map<String, dynamic> json) {
    return CloudUser(
      id: json['id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      displayName: json['displayName'] as String? ?? 'SyncTask User',
      photoUrl: json['photoUrl'] as String? ?? '',
      isPremium: json['isPremium'] as bool? ?? false,
      premiumExpiresAt: json['premiumExpiresAt'] != null
          ? DateTime.tryParse(json['premiumExpiresAt'].toString())
          : null,
    );
  }
}

/// Cloud Sync & Authentication Service connecting SyncTask (Pure Edition)
/// to the MongoDB Atlas + Render backend.
class CloudSyncService extends ChangeNotifier {
  static const String _tokenKey = 'synctask_cloud_jwt';
  static const String _userKey = 'synctask_cloud_user';
  static const String _backendUrlKey = 'synctask_backend_url';
  static const String _lastSyncKey = 'synctask_last_cloud_sync';
  static const String _isPremiumKey = 'synctask_is_premium';

  // Default production backend on Render (user can configure custom URL)
  static const String defaultBackendUrl = 'https://to-do-backend.onrender.com';

  String _backendUrl = defaultBackendUrl;
  String? _jwtToken;
  CloudUser? _currentUser;
  bool _isSyncing = false;
  int _lastSyncTimestamp = 0;
  bool _isPremium = false;

  CloudSyncService() {
    _loadState();
  }

  String get backendUrl => _backendUrl;
  String? get jwtToken => _jwtToken;
  CloudUser? get currentUser => _currentUser;
  bool get isAuthenticated => _jwtToken != null && _jwtToken!.isNotEmpty;
  bool get isSyncing => _isSyncing;
  bool get isPremium => _isPremium || (_currentUser?.isPremium ?? false);
  int get lastSyncTimestamp => _lastSyncTimestamp;

  Future<void> _loadState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _backendUrl = prefs.getString(_backendUrlKey) ?? defaultBackendUrl;
      _jwtToken = prefs.getString(_tokenKey);
      _lastSyncTimestamp = prefs.getInt(_lastSyncKey) ?? 0;
      _isPremium = prefs.getBool(_isPremiumKey) ?? false;

      final userJson = prefs.getString(_userKey);
      if (userJson != null) {
        _currentUser = CloudUser.fromJson(jsonDecode(userJson));
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<void> setBackendUrl(String url) async {
    _backendUrl = url.trim().replaceAll(RegExp(r'/+$'), '');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_backendUrlKey, _backendUrl);
    notifyListeners();
  }

  /// Sign In with Google credentials and receive JWT from Render backend.
  Future<bool> signInWithGoogle({
    required String idToken,
    String? email,
    String? displayName,
    String? photoUrl,
  }) async {
    _isSyncing = true;
    notifyListeners();

    try {
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
      final uri = Uri.parse('$_backendUrl/api/auth/google');
      final request = await client.postUrl(uri);
      request.headers.contentType = ContentType.json;

      request.write(jsonEncode({
        'idToken': idToken,
        'googleProfile': {
          'email': email,
          'name': displayName,
          'photo': photoUrl,
        },
      }));

      final response = await request.close();
      final bodyStr = await utf8.decoder.bind(response).join();
      client.close();

      if (response.statusCode == 200) {
        final data = jsonDecode(bodyStr);
        _jwtToken = data['token'] as String?;
        if (data['user'] != null) {
          _currentUser = CloudUser.fromJson(data['user'] as Map<String, dynamic>);
          _isPremium = _currentUser!.isPremium;
        }

        final prefs = await SharedPreferences.getInstance();
        if (_jwtToken != null) await prefs.setString(_tokenKey, _jwtToken!);
        if (_currentUser != null) {
          await prefs.setString(_userKey, jsonEncode(data['user']));
          await prefs.setBool(_isPremiumKey, _isPremium);
        }

        _isSyncing = false;
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('[CloudSync] Google Login error: $e');
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
    return false;
  }

  /// Sign out from cloud backend.
  Future<void> signOut() async {
    _jwtToken = null;
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
    notifyListeners();
  }

  /// Activate or simulate ₹10/month Ad-Free subscription.
  Future<bool> activateAdFreePlan({String? purchaseToken}) async {
    _isPremium = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isPremiumKey, true);
    notifyListeners();

    if (!isAuthenticated) return true;

    try {
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
      final uri = Uri.parse('$_backendUrl/api/subscription/activate');
      final request = await client.postUrl(uri);
      request.headers.contentType = ContentType.json;
      request.headers.set('Authorization', 'Bearer $_jwtToken');

      request.write(jsonEncode({
        'purchaseToken': purchaseToken ?? 'token_${DateTime.now().millisecondsSinceEpoch}',
        'planId': 'ad_free_monthly_inr10',
        'durationDays': 30,
      }));

      final response = await request.close();
      client.close();
      return response.statusCode == 200;
    } catch (_) {
      return true; // Local premium stays active even if offline
    }
  }

  /// Perform incremental cloud sync with MongoDB Atlas via Render backend.
  Future<void> syncWithCloud(TaskRepository taskRepo) async {
    if (!isAuthenticated || _isSyncing) return;
    _isSyncing = true;
    notifyListeners();

    try {
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);

      // 1. PUSH: Push local tasks modified since last sync
      final localTasks = await taskRepo.list();
      final pushList = localTasks.map((t) => {
        'id': t.id,
        'title': t.title,
        'notes': t.notes,
        'priority': t.priority,
        'completed': t.completed,
        'category': t.category,
        'dueAt': t.dueAt,
        'recurrence': t.recurrence.name,
        'revision': t.revision,
        'deviceId': t.deviceId,
        'isDeleted': false,
        'createdAt': t.createdAt,
        'updatedAt': t.updatedAt,
      }).toList();

      final pushUri = Uri.parse('$_backendUrl/api/sync/push');
      final pushReq = await client.postUrl(pushUri);
      pushReq.headers.contentType = ContentType.json;
      pushReq.headers.set('Authorization', 'Bearer $_jwtToken');
      pushReq.write(jsonEncode({'tasks': pushList}));
      final pushRes = await pushReq.close();
      await pushRes.drain();

      // 2. PULL: Pull remote delta modifications
      final pullUri = Uri.parse('$_backendUrl/api/sync/pull?since=$_lastSyncTimestamp');
      final pullReq = await client.getUrl(pullUri);
      pullReq.headers.set('Authorization', 'Bearer $_jwtToken');
      final pullRes = await pullReq.close();

      if (pullRes.statusCode == 200) {
        final body = await utf8.decoder.bind(pullRes).join();
        final data = jsonDecode(body);
        final serverTime = data['serverTime'] as int? ?? DateTime.now().millisecondsSinceEpoch;
        final remoteTasks = data['tasks'] as List<dynamic>? ?? [];

        for (final item in remoteTasks) {
          final tMap = item as Map<String, dynamic>;
          final taskId = tMap['id'] as String;
          final isDeleted = tMap['isDeleted'] as bool? ?? false;

          final existing = await taskRepo.getById(taskId);
          if (isDeleted) {
            if (existing != null && !existing.deleted) {
              await taskRepo.delete(taskId);
            }
          } else {
            final recurrence = Recurrence.values.firstWhere(
              (r) => r.name == (tMap['recurrence'] ?? 'none'),
              orElse: () => Recurrence.none,
            );

            final remoteTask = Task(
              id: taskId,
              title: tMap['title'] as String? ?? 'Untitled',
              notes: tMap['notes'] as String? ?? '',
              priority: tMap['priority'] as int? ?? 0,
              completed: tMap['completed'] as bool? ?? false,
              category: tMap['category'] as String? ?? '',
              dueAt: tMap['dueAt'] as int?,
              recurrence: recurrence,
              createdAt: tMap['createdAt'] as int? ?? DateTime.now().millisecondsSinceEpoch,
              updatedAt: tMap['updatedAt'] as int? ?? DateTime.now().millisecondsSinceEpoch,
              revision: tMap['revision'] as int? ?? 1,
              deviceId: tMap['deviceId'] as String? ?? 'cloud',
            );

            await taskRepo.applyRemoteTask(remoteTask);
          }
        }

        _lastSyncTimestamp = serverTime;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(_lastSyncKey, _lastSyncTimestamp);
      }

      client.close();
    } catch (e) {
      debugPrint('[CloudSync] Sync error: $e');
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }
}
