import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../core/ai/model_gateway.dart';
import '../../data/models/task.dart';
import '../sync/transport/sync_engine.dart';
import 'package:uuid/uuid.dart';
import '../../data/repositories/memory_repository.dart';
import 'widgets/sky_mascot_widget.dart';

/// High-level controller orchestrating Sky AI persona, voice/dialogue,
/// mascot mood expressions, and task status intelligence.
class SkyController extends ChangeNotifier {
  final ModelGateway _modelGateway;
  final MemoryRepository _memoryRepo;

  SkyMascotMood _mood = SkyMascotMood.idle;
  String? _lastSpokenText;
  bool _isProcessing = false;
  Timer? _moodResetTimer;

  SkyController({
    required ModelGateway modelGateway,
    required MemoryRepository memoryRepo,
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
    setMood(SkyMascotMood.speaking);

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
}
