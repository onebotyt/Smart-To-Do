import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:synctask/core/lifecycle/resource_manager.dart';
import 'package:synctask/core/lifecycle/resource_state.dart';
import 'package:synctask/data/database/memory_database.dart';
import 'package:synctask/data/database/projects_database.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('ResourceManager Lifecycle & RAM Budget Tests', () {
    late ResourceManager manager;

    setUp(() {
      manager = ResourceManager();
    });

    tearDown(() async {
      await manager.stopAllWorkers();
    });

    test('Initializes with empty workers and zero memory footprint', () {
      expect(manager.allWorkers, isEmpty);
      expect(manager.activeWorkers, isEmpty);
      expect(manager.totalEstimatedMemoryMb, 0);
      expect(manager.isUnderMemoryPressure, isFalse);
    });

    test('Registers worker, updates state, and tracks memory accurately', () {
      final worker = manager.registerWorker(
        id: 'model-qwen-1',
        name: 'Qwen 2.5 1.5B',
        type: WorkerType.modelWorker,
        priority: ResourcePriority.priority3UserAi,
        estimatedMemoryMb: 950,
      );

      expect(worker.state, WorkerState.starting);
      expect(manager.totalEstimatedMemoryMb, 950);
      expect(manager.activeWorkers.length, 1);

      manager.updateWorkerState('model-qwen-1', WorkerState.ready);
      expect(manager.allWorkers.first.state, WorkerState.ready);
      expect(manager.totalEstimatedMemoryMb, 950);

      manager.touchWorker('model-qwen-1');
      expect(manager.allWorkers.first.state, WorkerState.busy);

      manager.markWorkerIdle('model-qwen-1');
      expect(manager.allWorkers.first.state, WorkerState.ready);
    });

    test('Detects memory pressure and pauses optional workers (Priority 5 and 6)', () {
      // Register an indexing worker (Priority 5)
      manager.registerWorker(
        id: 'indexer-1',
        name: 'AST Symbol Indexer',
        type: WorkerType.projectIndexer,
        priority: ResourcePriority.priority5Indexing,
        estimatedMemoryMb: 250,
      );

      // Register heavy model that pushes memory over threshold (1800 MB)
      manager.registerWorker(
        id: 'model-heavy',
        name: 'Heavy Code LLM',
        type: WorkerType.modelWorker,
        priority: ResourcePriority.priority3UserAi,
        estimatedMemoryMb: 1900,
      );

      expect(manager.isUnderMemoryPressure, isTrue);

      manager.pauseOptionalWorkers();

      final indexer = manager.allWorkers.firstWhere((w) => w.id == 'indexer-1');
      expect(indexer.state, WorkerState.stopping);
      expect(indexer.estimatedMemoryMb, 0);
    });

    test('Unload model releases estimated memory and preserves stopped state', () async {
      manager.registerWorker(
        id: 'model-test',
        name: 'Test Model',
        type: WorkerType.modelWorker,
        priority: ResourcePriority.priority3UserAi,
        estimatedMemoryMb: 800,
      );
      manager.updateWorkerState('model-test', WorkerState.ready);

      final unloaded = await manager.unloadModel('model-test');
      expect(unloaded, isTrue);

      final worker = manager.allWorkers.firstWhere((w) => w.id == 'model-test');
      expect(worker.state, WorkerState.stopped);
      expect(worker.estimatedMemoryMb, 0);
      expect(manager.totalEstimatedMemoryMb, 0);
    });

    test('stopAllWorkers stops all active workers and resets RAM', () async {
      manager.registerWorker(
        id: 'agent-1',
        name: 'Coding Agent Subprocess',
        type: WorkerType.codingAgent,
        priority: ResourcePriority.priority4BuildsTests,
        estimatedMemoryMb: 150,
      );
      manager.registerWorker(
        id: 'indexer-2',
        name: 'Source Graph Indexer',
        type: WorkerType.projectIndexer,
        priority: ResourcePriority.priority5Indexing,
        estimatedMemoryMb: 300,
      );

      expect(manager.activeWorkers.length, 2);
      expect(manager.totalEstimatedMemoryMb, 450);

      await manager.stopAllWorkers();

      expect(manager.activeWorkers, isEmpty);
      expect(manager.totalEstimatedMemoryMb, 0);
      for (final w in manager.allWorkers) {
        expect(w.state, WorkerState.stopped);
      }
    });
  });

  group('MemoryDatabase Isolated SQLite Tests', () {
    late Database db;

    setUp(() async {
      db = await MemoryDatabase.open(path: inMemoryDatabasePath);
    });

    tearDown(() async {
      await db.close();
    });

    test('Stores and retrieves memories with category filtering and keyword search', () async {
      final id1 = await MemoryDatabase.addMemory(
        db,
        content: 'User prefers dark mode and vim keybindings',
        category: 'preferences',
      );
      final id2 = await MemoryDatabase.addMemory(
        db,
        content: 'Project architecture uses clean layered domain models',
        category: 'architecture',
      );

      expect(id1, isNotEmpty);
      expect(id2, isNotEmpty);

      final all = await MemoryDatabase.getMemories(db);
      expect(all.length, 2);

      final prefs = await MemoryDatabase.getMemories(db, category: 'preferences');
      expect(prefs.length, 1);
      expect(prefs.first['content'], contains('vim keybindings'));

      final search = await MemoryDatabase.searchMemories(db, 'clean layered');
      expect(search.length, 1);
      expect(search.first['category'], 'architecture');
    });

    test('Stores conversation history for sessions in chronological order', () async {
      const sessionId = 'session-test-42';
      await MemoryDatabase.addMessage(db, sessionId: sessionId, role: 'user', content: 'Sky, analyze the codebase');
      await MemoryDatabase.addMessage(db, sessionId: sessionId, role: 'assistant', content: 'Analyzing project graph...');

      final messages = await MemoryDatabase.getSessionMessages(db, sessionId);
      expect(messages.length, 2);
      expect(messages[0]['role'], 'user');
      expect(messages[1]['role'], 'assistant');
    });
  });

  group('ProjectsDatabase Isolated SQLite Tests', () {
    late Database db;

    setUp(() async {
      db = await ProjectsDatabase.open(path: inMemoryDatabasePath);
    });

    tearDown(() async {
      await db.close();
    });

    test('Creates project, records session, checkpoints, and finishes cleanly', () async {
      final projId = await ProjectsDatabase.createProject(
        db,
        name: 'SyncTask Core',
        rootPath: 'D:/to-do',
        description: 'Cross-platform P2P task manager',
      );
      expect(projId, isNotEmpty);

      final projects = await ProjectsDatabase.listProjects(db);
      expect(projects.length, 1);
      expect(projects.first['name'], 'SyncTask Core');

      final sessionId = await ProjectsDatabase.startSession(
        db,
        projectId: projId,
        title: 'Phase 1 Architecture Scaffolding',
      );
      expect(sessionId, isNotEmpty);

      await ProjectsDatabase.saveCheckpoint(
        db,
        sessionId: sessionId,
        stepIndex: 1,
        summary: 'Scaffolded lifecycle and database files',
        gitCommit: 'abc1234',
      );

      await ProjectsDatabase.finishSession(db, sessionId);

      final proj = await ProjectsDatabase.getProject(db, projId);
      expect(proj, isNotNull);
      expect(proj!['id'], projId);
    });
  });
}
