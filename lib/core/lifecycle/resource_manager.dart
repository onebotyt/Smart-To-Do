import 'dart:async';
import 'package:flutter/foundation.dart';
import 'resource_state.dart';

/// Central resource lifecycle manager for Sky Suite.
/// Enforces process tracking, RAM budget safeguards, idle model unloading,
/// and prioritized worker execution.
class ResourceManager extends ChangeNotifier {
  static final ResourceManager _instance = ResourceManager._internal();
  factory ResourceManager() => _instance;
  static ResourceManager get instance => _instance;
  ResourceManager._internal();

  /// Maximum allowed RAM (in MB) allocated to AI models and engineering workers
  /// to ensure the 8 GB host machine remains smooth and responsive.
  static const int maxWorkerMemoryBudgetMb = 2400;

  /// Low memory threshold where optional background workers are paused.
  static const int memoryPressureThresholdMb = 1800;

  /// Default idle timeout before an unused model worker is unloaded.
  Duration modelIdleUnloadTimeout = const Duration(seconds: 90);

  final Map<String, WorkerInfo> _workers = {};
  Timer? _idleCheckTimer;

  final StreamController<List<WorkerInfo>> _workerStream =
      StreamController<List<WorkerInfo>>.broadcast();
  Stream<List<WorkerInfo>> get workerStream => _workerStream.stream;

  List<WorkerInfo> get allWorkers => List.unmodifiable(_workers.values.toList());

  List<WorkerInfo> get activeWorkers =>
      List.unmodifiable(_workers.values.where((w) => w.isRunning).toList());

  int get totalEstimatedMemoryMb =>
      _workers.values.where((w) => w.isRunning).fold(0, (sum, w) => sum + w.estimatedMemoryMb);

  bool get isUnderMemoryPressure => totalEstimatedMemoryMb >= memoryPressureThresholdMb;

  /// Registers or updates a worker in the manager.
  WorkerInfo registerWorker({
    required String id,
    required String name,
    required WorkerType type,
    required ResourcePriority priority,
    int estimatedMemoryMb = 0,
    String? details,
  }) {
    final worker = WorkerInfo(
      id: id,
      name: name,
      type: type,
      priority: priority,
      state: WorkerState.starting,
      estimatedMemoryMb: estimatedMemoryMb,
      statusDetails: details,
    );
    _workers[id] = worker;
    _startIdleCheckIfNeeded();
    _notifyChanges();
    return worker;
  }

  /// Updates a worker's lifecycle state.
  void updateWorkerState(
    String id,
    WorkerState newState, {
    String? details,
    int? estimatedMemoryMb,
  }) {
    final worker = _workers[id];
    if (worker == null) return;

    worker.state = newState;
    worker.lastActiveAt = DateTime.now();
    if (details != null) worker.statusDetails = details;
    if (estimatedMemoryMb != null) worker.estimatedMemoryMb = estimatedMemoryMb;

    if (newState == WorkerState.stopped || newState == WorkerState.failed) {
      worker.estimatedMemoryMb = 0;
    }

    _notifyChanges();
  }

  /// Touches a worker to reset its idle timer (e.g. when receiving a query).
  void touchWorker(String id) {
    final worker = _workers[id];
    if (worker != null) {
      worker.lastActiveAt = DateTime.now();
      if (worker.state == WorkerState.ready) {
        worker.state = WorkerState.busy;
      }
      _notifyChanges();
    }
  }

  /// Marks a worker as ready (idle/waiting for next request).
  void markWorkerIdle(String id) {
    final worker = _workers[id];
    if (worker != null && worker.isRunning) {
      worker.state = WorkerState.ready;
      worker.lastActiveAt = DateTime.now();
      _notifyChanges();
    }
  }

  /// Requests a model worker to be unloaded from RAM.
  Future<bool> unloadModel(String id) async {
    final worker = _workers[id];
    if (worker == null || !worker.isModel || !worker.isRunning) return false;

    worker.state = WorkerState.stopping;
    worker.statusDetails = 'Unloading model from RAM...';
    _notifyChanges();

    // Give worker time to finish/cancel cleanly
    await Future.delayed(const Duration(milliseconds: 50));
    worker.state = WorkerState.stopped;
    worker.estimatedMemoryMb = 0;
    worker.statusDetails = 'Model unloaded; weights preserved on disk';
    _notifyChanges();
    return true;
  }

  /// Gracefully cancels and stops optional background workers (Priority 5 and 6)
  /// when memory pressure occurs.
  void pauseOptionalWorkers() {
    for (final w in _workers.values) {
      if (w.isRunning && w.priority >= ResourcePriority.priority5Indexing) {
        w.state = WorkerState.stopping;
        w.statusDetails = 'Paused due to memory pressure';
        w.estimatedMemoryMb = 0;
      }
    }
    _notifyChanges();
  }

  /// Removes a worker from manager.
  void unregisterWorker(String id) {
    final worker = _workers.remove(id);
    if (worker != null) {
      _notifyChanges();
    }
  }

  /// Gracefully requests stopping all active engineering workers and unloads all models.
  Future<void> stopAllWorkers() async {
    for (final w in _workers.values) {
      if (w.isRunning) {
        w.state = WorkerState.stopping;
        w.statusDetails = 'Graceful shutdown requested';
      }
    }
    _notifyChanges();

    await Future.delayed(const Duration(milliseconds: 100));

    for (final w in _workers.values) {
      w.state = WorkerState.stopped;
      w.estimatedMemoryMb = 0;
      w.statusDetails = 'Stopped';
    }
    _idleCheckTimer?.cancel();
    _idleCheckTimer = null;
    _notifyChanges();
  }

  void _startIdleCheckIfNeeded() {
    if (_idleCheckTimer != null && _idleCheckTimer!.isActive) return;
    _idleCheckTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _checkIdleModels();
    });
  }

  void _checkIdleModels() {
    final now = DateTime.now();
    for (final w in _workers.values) {
      if (w.isModel && w.state == WorkerState.ready) {
        if (now.difference(w.lastActiveAt) >= modelIdleUnloadTimeout) {
          unloadModel(w.id);
        }
      }
    }
  }

  void _notifyChanges() {
    notifyListeners();
    if (!_workerStream.isClosed) {
      _workerStream.add(allWorkers);
    }
  }

  @override
  void dispose() {
    _idleCheckTimer?.cancel();
    _workerStream.close();
    super.dispose();
  }
}
