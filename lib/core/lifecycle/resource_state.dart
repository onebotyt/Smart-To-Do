/// Explicit lifecycle states for background components, local LLMs, and agent workers.
enum WorkerState {
  stopped,
  starting,
  ready,
  busy,
  stopping,
  failed,
}

/// Category of background worker managed by the resource manager.
enum WorkerType {
  modelWorker,
  codingAgent,
  projectIndexer,
  buildJob,
  memoryWorker,
}

/// Resource priority hierarchy (1 = highest / indispensable, 6 = lowest / deferrable).
enum ResourcePriority {
  /// Priority 1: Task database integrity, alarms, reminders.
  priority1TaskIntegrity(1),

  /// Priority 2: Interactive SyncTask UI & native floating overlays.
  priority2InteractiveApp(2),

  /// Priority 3: Active user-requested AI interaction.
  priority3UserAi(3),

  /// Priority 4: Active local compilation, build, and test jobs.
  priority4BuildsTests(4),

  /// Priority 5: Project background indexing, AST parsing, embeddings.
  priority5Indexing(5),

  /// Priority 6: Background knowledge synthesis and maintenance.
  priority6Maintenance(6);

  final int rank;
  const ResourcePriority(this.rank);

  bool operator <(ResourcePriority other) => rank < other.rank;
  bool operator <=(ResourcePriority other) => rank <= other.rank;
  bool operator >(ResourcePriority other) => rank > other.rank;
  bool operator >=(ResourcePriority other) => rank >= other.rank;
}

/// Information snapshot of an active or managed worker.
class WorkerInfo {
  final String id;
  final String name;
  final WorkerType type;
  final ResourcePriority priority;
  WorkerState state;
  final DateTime startedAt;
  DateTime lastActiveAt;
  int estimatedMemoryMb;
  String? statusDetails;

  WorkerInfo({
    required this.id,
    required this.name,
    required this.type,
    required this.priority,
    this.state = WorkerState.stopped,
    DateTime? startedAt,
    DateTime? lastActiveAt,
    this.estimatedMemoryMb = 0,
    this.statusDetails,
  })  : startedAt = startedAt ?? DateTime.now(),
        lastActiveAt = lastActiveAt ?? DateTime.now();

  bool get isRunning =>
      state == WorkerState.starting ||
      state == WorkerState.ready ||
      state == WorkerState.busy;

  bool get isModel => type == WorkerType.modelWorker;

  Duration get idleDuration => DateTime.now().difference(lastActiveAt);

  WorkerInfo copyWith({
    WorkerState? state,
    DateTime? lastActiveAt,
    int? estimatedMemoryMb,
    String? statusDetails,
  }) {
    final info = WorkerInfo(
      id: id,
      name: name,
      type: type,
      priority: priority,
      state: state ?? this.state,
      startedAt: startedAt,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      estimatedMemoryMb: estimatedMemoryMb ?? this.estimatedMemoryMb,
      statusDetails: statusDetails ?? this.statusDetails,
    );
    return info;
  }
}
