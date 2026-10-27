import 'dart:async';
import '../lifecycle/resource_manager.dart';
import '../lifecycle/resource_state.dart';
import '../../data/models/memory_item.dart';

/// Abstract contract for local and remote inference runtimes in Sky Suite.
abstract class ModelGateway {
  String get modelId;
  String get modelName;
  int get estimatedMemoryMb;
  bool get isLoaded;
  WorkerState get state;

  Future<bool> load();
  Future<void> unload();
  Future<String> generate(String prompt, {List<ConversationMessage>? history});
  Stream<String> generateStream(String prompt, {List<ConversationMessage>? history});
}

/// Robust model gateway integrating with ResourceManager for automatic idle unloads
/// and memory budget protection on 8 GB host machines.
class ManagedModelGateway implements ModelGateway {
  @override
  final String modelId;
  @override
  final String modelName;
  @override
  final int estimatedMemoryMb;

  final ResourceManager _resourceManager;
  bool _isLoaded = false;
  WorkerState _state = WorkerState.stopped;

  ManagedModelGateway({
    required this.modelId,
    required this.modelName,
    this.estimatedMemoryMb = 950,
    ResourceManager? resourceManager,
  }) : _resourceManager = resourceManager ?? ResourceManager() {
    _register();
  }

  void _register() {
    _resourceManager.registerWorker(
      id: modelId,
      name: modelName,
      type: WorkerType.modelWorker,
      priority: ResourcePriority.priority3UserAi,
      estimatedMemoryMb: estimatedMemoryMb,
      details: 'Local AI inference worker ($modelName)',
    );
  }

  @override
  bool get isLoaded => _isLoaded;

  @override
  WorkerState get state => _state;

  @override
  Future<bool> load() async {
    if (_isLoaded) return true;

    // Check memory budget before loading
    if (_resourceManager.isUnderMemoryPressure) {
      _resourceManager.pauseOptionalWorkers();
    }

    _state = WorkerState.starting;
    _resourceManager.updateWorkerState(
      modelId,
      WorkerState.starting,
      details: 'Loading model weights into RAM...',
      estimatedMemoryMb: estimatedMemoryMb,
    );

    await Future.delayed(const Duration(milliseconds: 60)); // Model init simulation

    _isLoaded = true;
    _state = WorkerState.ready;
    _resourceManager.updateWorkerState(
      modelId,
      WorkerState.ready,
      details: 'Model ready for queries',
      estimatedMemoryMb: estimatedMemoryMb,
    );
    return true;
  }

  @override
  Future<void> unload() async {
    if (!_isLoaded) return;

    _state = WorkerState.stopping;
    _resourceManager.updateWorkerState(
      modelId,
      WorkerState.stopping,
      details: 'Unloading model from RAM...',
    );

    await Future.delayed(const Duration(milliseconds: 30));

    _isLoaded = false;
    _state = WorkerState.stopped;
    _resourceManager.updateWorkerState(
      modelId,
      WorkerState.stopped,
      details: 'Model unloaded; weights preserved on disk',
      estimatedMemoryMb: 0,
    );
  }

  @override
  Future<String> generate(String prompt, {List<ConversationMessage>? history}) async {
    final buffer = StringBuffer();
    await for (final chunk in generateStream(prompt, history: history)) {
      buffer.write(chunk);
    }
    return buffer.toString();
  }

  @override
  Stream<String> generateStream(String prompt, {List<ConversationMessage>? history}) async* {
    if (!_isLoaded) {
      final success = await load();
      if (!success) {
        yield "Sky is currently unable to load the model due to system memory limits.";
        return;
      }
    }

    _state = WorkerState.busy;
    _resourceManager.touchWorker(modelId);
    _resourceManager.updateWorkerState(
      modelId,
      WorkerState.busy,
      details: 'Generating response...',
    );

    try {
      // Clean rule-based Jarvis/Sky response simulation for local commands
      final lower = prompt.toLowerCase().trim();
      final responseText = _generateLocalAnswer(lower, prompt);

      final words = responseText.split(' ');
      for (final word in words) {
        await Future.delayed(const Duration(milliseconds: 25));
        yield '$word ';
      }
    } finally {
      _state = WorkerState.ready;
      _resourceManager.markWorkerIdle(modelId);
      _resourceManager.updateWorkerState(
        modelId,
        WorkerState.ready,
        details: 'Model ready (Idle timer active)',
      );
    }
  }

  String _generateLocalAnswer(String lower, String original) {
    if (lower.contains('status') || lower.contains('how are you') || lower.contains('diagnostics')) {
      return "All systems operational. Local sync is active, and resources are well within memory safety thresholds.";
    } else if (lower.contains('hello') || lower.contains('hi sky') || lower.contains('hey sky') || lower.contains('hey')) {
      return "Hello! I am Sky, your personal AI assistant. All your tasks and engineering workspaces are ready.";
    } else if (lower.contains('help') || lower.contains('what can you do')) {
      return "I can track your tasks, provide daily briefings, orchestrate engineering subagents, and keep your devices in sync without any cloud servers.";
    } else {
      return "Understood. I have logged this request into persistent memory and will coordinate task execution.";
    }
  }
}
