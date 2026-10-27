import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../core/ai/model_gateway.dart';
import '../../data/models/task.dart';
import '../sync/transport/sync_engine.dart';
import 'package:uuid/uuid.dart';
import '../../data/repositories/memory_repository.dart';
import 'widgets/sky_mascot_widget.dart';
import '../../platform/voice_service.dart';
import '../tasks/task_controller.dart';

/// High-level controller orchestrating Sky AI persona, voice/dialogue,
/// mascot mood expressions, and task status intelligence.
class SkyController extends ChangeNotifier {
  final ModelGateway _modelGateway;
  final MemoryRepository _memoryRepo;
  TaskController? taskController;
  VoiceService? voiceService;
  bool isVoiceOutputEnabled = true;

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

  void setMood(SkyMascotMood newMood) {
    _moodResetTimer?.cancel();
    _mood = newMood;
    notifyListeners();
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
    if (syncEngine != null) {
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

        // Try offloading to connected peer
        // If not completed within 2.5s, fall back to local
        final p2pFuture = completer.future.timeout(const Duration(milliseconds: 2500));
        response = await p2pFuture;
      } catch (_) {
        // Fallback to local engine automatically
        response = null;
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
    _moodResetTimer?.cancel();
    super.dispose();
  }
  /// Automatically interprets natural language task operations.
  Future<String?> _handleTaskAction(String query) async {
    final lower = query.trim().toLowerCase();

    // 1. Briefing request
    if (RegExp(r'\b(briefing|daily brief|status report|what do i have|schedule)\b').hasMatch(lower)) {
      final tasks = taskController?.tasks ?? [];
      return generateBriefing(tasks);
    }

    // 2. Next recommended task
    if (RegExp(r'\b(next task|what should i do|what next|recommend task)\b').hasMatch(lower)) {
      final tasks = taskController?.tasks ?? [];
      return recommendNextAction(tasks);
    }

    // 3. Create / Add Task
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

    // 4. Complete / Mark Done
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

    // 5. Delete / Remove
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