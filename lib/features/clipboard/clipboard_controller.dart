import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:synctask/features/sync/transport/sync_engine.dart';
import 'package:synctask/platform/clipboard_service.dart';

class ClipboardController extends ChangeNotifier {
  static const String prefEnabledKey = 'pref_clipboard_sync_enabled';
  static const String prefPausedKey = 'pref_clipboard_sync_paused';

  final ClipboardService _clipboardService;
  final SyncEngine _syncEngine;

  bool _isEnabled = false;
  bool _isPaused = false;
  DateTime? _lastSyncedAt;
  int _syncCount = 0;

  // Rolling cache of recent hashes to prevent echo loops and duplicates
  final Set<String> _recentHashes = {};

  StreamSubscription<String>? _localCopySub;

  ClipboardController({
    required SyncEngine syncEngine,
    ClipboardService? clipboardService,
  })  : _syncEngine = syncEngine,
        _clipboardService = clipboardService ?? PlatformClipboardService() {
    _syncEngine.onClipboardReceived = _handleRemoteClipboard;
  }

  bool get isEnabled => _isEnabled;
  bool get isPaused => _isPaused;
  DateTime? get lastSyncedAt => _lastSyncedAt;
  int get syncCount => _syncCount;
  ClipboardService get clipboardService => _clipboardService;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _isEnabled = prefs.getBool(prefEnabledKey) ?? false;
    _isPaused = prefs.getBool(prefPausedKey) ?? false;

    if (_isEnabled && !_isPaused) {
      _startListening();
    }
    notifyListeners();
  }

  Future<void> setEnabled(bool enabled) async {
    _isEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefEnabledKey, enabled);

    if (_isEnabled && !_isPaused) {
      _startListening();
    } else {
      _stopListening();
    }
    notifyListeners();
  }

  Future<void> setPaused(bool paused) async {
    _isPaused = paused;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefPausedKey, paused);

    if (_isEnabled && !_isPaused) {
      _startListening();
    } else {
      _stopListening();
    }
    notifyListeners();
  }

  void _startListening() {
    _clipboardService.startListening();
    _localCopySub?.cancel();
    _localCopySub = _clipboardService.onLocalCopy.listen(_handleLocalCopy);
  }

  void _stopListening() {
    _localCopySub?.cancel();
    _localCopySub = null;
    _clipboardService.stopListening();
  }

  void _recordHash(String hash) {
    _recentHashes.add(hash);
    if (_recentHashes.length > 50) {
      _recentHashes.remove(_recentHashes.first);
    }
  }

  String _computeHash(String text) {
    return sha256.convert(utf8.encode(text)).toString();
  }

  Future<void> _handleLocalCopy(String text) async {
    if (!_isEnabled || _isPaused || text.trim().isEmpty) return;

    final hash = _computeHash(text);
    if (_recentHashes.contains(hash)) {
      // Duplicate or inbound echo: ignore
      return;
    }

    _recordHash(hash);
    final delivered = await _syncEngine.broadcastClipboardText(text, hash);

    if (delivered > 0) {
      _lastSyncedAt = DateTime.now();
      _syncCount++;
      notifyListeners();
    }
  }

  Future<void> _handleRemoteClipboard(String text, String senderId) async {
    if (!_isEnabled || _isPaused || text.trim().isEmpty) return;

    final hash = _computeHash(text);
    if (_recentHashes.contains(hash)) {
      // Already processed: ignore
      return;
    }

    // Record hash before writing to local clipboard so local copy listener ignores it
    _recordHash(hash);
    await _clipboardService.writeText(text);

    _lastSyncedAt = DateTime.now();
    _syncCount++;
    notifyListeners();
  }

  @override
  void dispose() {
    _stopListening();
    _clipboardService.dispose();
    super.dispose();
  }
}
