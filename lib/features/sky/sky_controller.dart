import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../core/ai/model_gateway.dart';
import '../../data/models/device.dart';
import '../../data/models/task.dart';
import '../sync/sync_controller.dart';
import '../sync/transport/sync_engine.dart';
import 'package:uuid/uuid.dart';
import '../../data/repositories/memory_repository.dart';
import 'widgets/sky_mascot_widget.dart';
import '../../platform/voice_service.dart';
import '../tasks/task_controller.dart';

/// High-level controller orchestrating Sky AI persona, voice/dialogue,
/// mascot mood expressions, hardware awareness, and task status intelligence.
class SkyController extends ChangeNotifier {
  final ModelGateway _modelGateway;
  final MemoryRepository _memoryRepo;
  TaskController? taskController;
  VoiceService? voiceService;
  bool isVoiceOutputEnabled = true;

  SyncController? _syncController;
  Timer? _watchdogTimer;
  final Set<String> _alertedTaskIds = {};
  String? _lastReportedGpuPeerId;
  DateTime? _lastMorningBriefingDate;

  SkyMascotMood _mood = SkyMascotMood.idle;
  String? _lastSpokenText;
  bool _isProcessing = false;
  Timer? _moodResetTimer;

  SkyController({
    required ModelGateway modelGateway,
    required MemoryRepository memoryRepo,
    this.taskController,
    this.voiceService,
    this.isVoiceOutputEnabled = true,
  })  : _modelGateway = modelGateway,
        _memoryRepo = memoryRepo;

  SkyMascotMood get mood => _mood;
  String? get lastSpokenText => _lastSpokenText;
  bool get isProcessing => _isProcessing;
  SyncController? get syncController => _syncController;

  void setMood(SkyMascotMood newMood) {
    _moodResetTimer?.cancel();
    _mood = newMood;
    notifyListeners();
  }

  /// Attach the network sync controller to monitor peer presence and GPU offloading.
  void attachSyncController(SyncController sync) {
    _syncController = sync;
    startAutonomousWatchdog();
  }

  /// Celebrates a completed task with gold sparkles and happy eyes for 3.5 seconds.
  void celebrateTaskCompletion(String taskTitle) {
    _moodResetTimer?.cancel();
    _mood = SkyMascotMood.celebrating;
    _lastSpokenText = 'Great job completing: "$taskTitle"!';
    if (isVoiceOutputEnabled && voiceService != null) {
      voiceService!.speak(_lastSpokenText!);
    }
    notifyListeners();

    _moodResetTimer = Timer(const Duration(milliseconds: 3500), () {
      _mood = SkyMascotMood.idle;
      notifyListeners();
    });
  }

  /// Alerts the user about an overdue or urgent priority task.
  void alertUrgentTask(String taskTitle) {
    _moodResetTimer?.cancel();
    _mood = SkyMascotMood.alert;
    _lastSpokenText = 'Attention: "$taskTitle" is high priority or overdue.';
    if (isVoiceOutputEnabled && voiceService != null) {
      voiceService!.speak(_lastSpokenText!);
    }
    notifyListeners();

    _moodResetTimer = Timer(const Duration(seconds: 4), () {
      _mood = SkyMascotMood.idle;
      notifyListeners();
    });
  }

  /// Speaks a proactive briefing, displaying it on the mascot HUD.
  void speakBriefing(String text) {
    _lastSpokenText = text;
    setMood(SkyMascotMood.speaking);
    if (isVoiceOutputEnabled && voiceService != null) {
      voiceService!.speak(text);
    }
    _moodResetTimer?.cancel();
    _moodResetTimer = Timer(const Duration(seconds: 5), () {
      _mood = SkyMascotMood.idle;
      notifyListeners();
    });
    notifyListeners();
  }

  /// Starts the proactive background watchdog monitoring upcoming tasks,
  /// morning briefings, and Lenovo IdeaPad LAN connections.
  void startAutonomousWatchdog() {
    if (_watchdogTimer != null) return;
    if (Platform.environment.containsKey('FLUTTER_TEST')) return;

    // Run first check after a brief 3-second startup grace period
    Timer(const Duration(seconds: 3), () => _runWatchdogCheck());

    _watchdogTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _runWatchdogCheck();
    });
  }

  void _runWatchdogCheck() {
    final now = DateTime.now();

    // 1. Morning Briefing Check (between 7:00 AM and 11:59 AM, once per day)
    if (now.hour >= 7 && now.hour < 12) {
      if (_lastMorningBriefingDate == null || _lastMorningBriefingDate!.day != now.day) {
        _lastMorningBriefingDate = now;
        final tasks = taskController?.tasks ?? [];
        if (tasks.isNotEmpty) {
          speakBriefing(generateBriefing(tasks));
        }
      }
    }

    // 2. Overdue & Upcoming Task Alerts
    final tasks = taskController?.tasks ?? [];
    for (final task in tasks) {
      if (!task.completed && task.dueAt != null) {
        final dueDateTime = DateTime.fromMillisecondsSinceEpoch(task.dueAt!);
        final diff = dueDateTime.difference(now);
        // Alert if overdue or within 15 minutes
        if (diff.isNegative || diff.inMinutes <= 15) {
          if (!_alertedTaskIds.contains(task.id)) {
            _alertedTaskIds.add(task.id);
            alertUrgentTask(task.title);
            break; // One vocal alert at a time to prevent noise
          }
        }
      }
    }

    // 3. Proactive LAN Peer Detection (Lenovo IdeaPad Gaming 3 RTX 2050 on Vivo T3 Lite)
    if (_syncController != null) {
      final peers = _syncController!.discoveredPeers;
      final gpuPeer = peers.where((p) => p.hasGpu || p.platform == 'windows').firstOrNull;

      if (gpuPeer != null) {
        if (_lastReportedGpuPeerId != gpuPeer.id) {
          _lastReportedGpuPeerId = gpuPeer.id;
          if (!Platform.isWindows) {
            speakBriefing("${gpuPeer.name} connected on Wi-Fi. RTX 2050 GPU acceleration ready, sir.");
          }
        }
      } else if (_lastReportedGpuPeerId != null) {
        _lastReportedGpuPeerId = null;
        if (!Platform.isWindows) {
          speakBriefing("IdeaPad disconnected. Running in autonomous local mode.");
        }
      }
    }
  }

  /// Automatically recommends the next best task based on priority and due time.
  String recommendNextAction(List<Task> tasks) {
    final pending = tasks.where((t) => !t.completed).toList();
    if (pending.isEmpty) {
      return "All tasks are complete, sir. System is idle and ready for new instructions.";
    }

    pending.sort((a, b) {
      final pCompare = b.priority.compareTo(a.priority);
      if (pCompare != 0) return pCompare;
      if (a.dueAt != null && b.dueAt != null) {
        return a.dueAt!.compareTo(b.dueAt!);
      }
      return a.dueAt != null ? -1 : 1;
    });

    final top = pending.first;
    return "Next recommended task: '${top.title}' (${top.priority >= 3 ? 'High Priority' : 'Normal'}). Let's tackle this next, sir.";
  }

  /// Answers a user question or conversational request with Sky AI.
  /// Automatically attempts P2P offloading to PC GPU if available,
  /// falling back seamlessly to local engine without any user intervention.
  Future<String> ask(
    String query, {
    String sessionId = 'default-sky-session',
    SyncEngine? syncEngine,
  }) async {
    _isProcessing = true;
    setMood(SkyMascotMood.thinking);

    // 1. Record user turn
    await _memoryRepo.recordMessage(
      sessionId: sessionId,
      role: 'user',
      content: query,
    );

    String? response;

    // Direct Natural Language Task Action Check
    final taskActionResult = await _handleTaskAction(query);
    if (taskActionResult != null) {
      response = taskActionResult;
    }

    // 2. Automated P2P Offloading to PC GPU if available
    if (response == null && syncEngine != null) {
      final gpuPeer = _syncController?.discoveredPeers
          .where((p) => p.hasGpu || p.platform == 'windows')
          .firstOrNull;

      final targetPeer = gpuPeer != null
          ? Device(
              id: gpuPeer.id,
              name: gpuPeer.name,
              fingerprint: gpuPeer.id,
              ipAddress: gpuPeer.ipAddress,
              port: gpuPeer.port,
              pairedAt: DateTime.now(),
              trusted: true,
            )
          : _syncController?.trustedDevices.firstOrNull;

      if (targetPeer != null) {
        try {
          final queryId = const Uuid().v4();
          final completer = Completer<String>();

          syncEngine.onAiResponseReceived = (qId, text, isComplete) {
            if (qId == queryId && !completer.isCompleted) {
              completer.complete(text);
            }
          };

          syncEngine.onAiStatusReceived = (qId, status, reason) {
            if (qId == queryId && !completer.isCompleted) {
              completer.completeError(reason);
            }
          };

          // Send query over TCP to the PC's RTX 2050 model runner
          syncEngine.sendAiQuery(
            peer: targetPeer,
            queryId: queryId,
            prompt: query,
          );

          // If peer answers within 4s, use it!
          final p2pFuture = completer.future.timeout(const Duration(milliseconds: 4000));
          response = await p2pFuture;
        } catch (_) {
          // Fallback to local engine automatically
          response = null;
        }
      }
    }

    // 3. Local engine fallback
    if (response == null || response.isEmpty) {
      final history = await _memoryRepo.getConversationHistory(sessionId, limit: 10);
      response = await _modelGateway.generate(query, history: history);
    }

    // 4. Record assistant response
    await _memoryRepo.recordMessage(
      sessionId: sessionId,
      role: 'assistant',
      content: response,
    );

    _lastSpokenText = response;
    if (isVoiceOutputEnabled && voiceService != null) {
      voiceService!.speak(response);
    }
    if (_mood != SkyMascotMood.celebrating) {
      setMood(SkyMascotMood.speaking);
    }

    _moodResetTimer = Timer(const Duration(seconds: 4), () {
      _mood = SkyMascotMood.idle;
      notifyListeners();
    });

    _isProcessing = false;
    notifyListeners();
    return response;
  }

  /// Generates a Jarvis-like briefing for today's tasks.
  String generateBriefing(List<Task> tasks) {
    final pending = tasks.where((t) => !t.completed).toList();
    final highPriority = pending.where((t) => t.priority >= 3).toList();

    if (pending.isEmpty) {
      return "All caught up! You have zero pending tasks for today. Excellent work.";
    }

    if (highPriority.isNotEmpty) {
      return "Good day. You have ${pending.length} pending tasks, with ${highPriority.length} high priority item${highPriority.length > 1 ? 's' : ''}: '${highPriority.first.title}'. Ready when you are.";
    }

    return "Good day. You have ${pending.length} tasks scheduled. Top item: '${pending.first.title}'.";
  }

  @override
  void dispose() {
    _watchdogTimer?.cancel();
    _moodResetTimer?.cancel();
    super.dispose();
  }

  /// Automatically interprets natural language task and hardware operations.
  Future<String?> _handleTaskAction(String query) async {
    final lower = query.trim().toLowerCase();

    // 1. Hardware & System Status
    if (RegExp(r'\b(hardware|status|gpu|specs|system|pc status|ideapad)\b').hasMatch(lower)) {
      if (Platform.isWindows) {
        return "Lenovo IdeaPad Gaming 3 operational. AMD Ryzen 5 5500H, 8 GB RAM, NVIDIA GeForce RTX 2050 (4 GB VRAM). Local inference fully enabled.";
      } else {
        final gpuPeer = _syncController?.discoveredPeers
            .where((p) => p.hasGpu || p.platform == 'windows')
            .firstOrNull;
        if (gpuPeer != null) {
          return "Vivo T3 Lite connected to ${gpuPeer.name} on local network. RTX 2050 GPU offload active. Phone RAM footprint: lightweight 68 MB.";
        } else {
          return "Vivo T3 Lite running locally (6 GB RAM). AI in lightweight battery-saver mode. RTX 2050 PC offline.";
        }
      }
    }

    // 2. Briefing request
    if (RegExp(r'\b(briefing|daily brief|status report|what do i have|schedule)\b').hasMatch(lower)) {
      final tasks = taskController?.tasks ?? [];
      return generateBriefing(tasks);
    }

    // 3. Next recommended task
    if (RegExp(r'\b(next task|what should i do|what next|recommend task)\b').hasMatch(lower)) {
      final tasks = taskController?.tasks ?? [];
      return recommendNextAction(tasks);
    }

    // 4. Create / Add Task
    final createMatch = RegExp(r'^(?:sky,?\s*)?(?:add|create|new|remind me to)\s+(?:task\s+)?(.+)', caseSensitive: false).firstMatch(query.trim());
    if (createMatch != null && taskController != null) {
      final rawTitle = createMatch.group(1)!.trim();
      int priority = 1;
      String cleanTitle = rawTitle;
      if (rawTitle.toLowerCase().contains('urgent') || rawTitle.toLowerCase().contains('high priority')) {
        priority = 3;
        cleanTitle = rawTitle.replaceAll(RegExp(r'(urgent|high priority)', caseSensitive: false), '').trim();
      } else if (rawTitle.toLowerCase().contains('low priority')) {
        priority = 0;
        cleanTitle = rawTitle.replaceAll(RegExp(r'low priority', caseSensitive: false), '').trim();
      }
      if (cleanTitle.isNotEmpty) {
        await taskController!.create(title: cleanTitle, priority: priority);
        return "Created task '$cleanTitle'${priority >= 3 ? ' with High Priority' : ''}, sir. Synced to your devices.";
      }
    }

    // 5. Complete / Mark Done
    final doneMatch = RegExp(r'^(?:sky,?\s*)?(?:complete|finish|mark|done)\s+(?:task\s+)?(.+?)(?:\s+as\s+done|\s+completed)?$', caseSensitive: false).firstMatch(query.trim());
    if (doneMatch != null && taskController != null) {
      final target = doneMatch.group(1)!.trim().toLowerCase();
      final tasks = taskController!.tasks.where((t) => !t.completed).toList();
      Task? match;
      for (final t in tasks) {
        if (t.title.toLowerCase().contains(target) || target.contains(t.title.toLowerCase())) {
          match = t;
          break;
        }
      }
      if (match != null) {
        await taskController!.toggle(match);
        celebrateTaskCompletion(match.title);
        return "Marked '${match.title}' as completed. Excellent work, sir.";
      }
    }

    // 6. Delete / Remove
    final delMatch = RegExp(r'^(?:sky,?\s*)?(?:delete|remove)\s+(?:task\s+)?(.+)', caseSensitive: false).firstMatch(query.trim());
    if (delMatch != null && taskController != null) {
      final target = delMatch.group(1)!.trim().toLowerCase();
      final tasks = taskController!.tasks;
      Task? match;
      for (final t in tasks) {
        if (t.title.toLowerCase().contains(target) || target.contains(t.title.toLowerCase())) {
          match = t;
          break;
        }
      }
      if (match != null) {
        await taskController!.remove(match);
        return "Removed task '${match.title}', sir.";
      }
    }

    return null;
  }
}
