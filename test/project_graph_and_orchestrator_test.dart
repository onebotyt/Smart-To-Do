import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:synctask/core/lifecycle/resource_manager.dart';
import 'package:synctask/data/database/projects_database.dart';
import 'package:synctask/features/studio/agent_orchestrator.dart';
import 'package:synctask/features/studio/project_graph_service.dart';
import 'package:synctask/features/sync/models/sync_message.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  group('ProjectGraphService & AST Symbol Indexing Tests', () {
    late Database db;
    late Directory tempDir;
    late ResourceManager resourceManager;
    late ProjectGraphService graphService;
    late String projectId;

    setUp(() async {
      db = await ProjectsDatabase.open(path: inMemoryDatabasePath);

      tempDir = await Directory.systemTemp.createTemp('synctask_studio_test_');

      // Create test files
      final dartFile = File('${tempDir.path}/main.dart');
      await dartFile.writeAsString('''
class TaskController {
  void initialize() {}
  Future<void> sync() async {}
}

enum SyncState { idle, syncing, failed }
''');

      final pyFile = File('${tempDir.path}/service.py');
      await pyFile.writeAsString('''
class AuthService:
    def verify_token():
        pass
''');

      resourceManager = ResourceManager();
      await resourceManager.stopAllWorkers();
      graphService = ProjectGraphService(projectsDb: db, resourceManager: resourceManager);
      projectId = await ProjectsDatabase.createProject(
        db,
        name: 'Test Project',
        rootPath: tempDir.path,
      );
    });

    tearDown(() async {
      await db.close();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
      await resourceManager.stopAllWorkers();
    });

    test('Indexes files and extracts classes, functions, and enums', () async {
      final summary = await graphService.indexProject(
        projectId: projectId,
        rootPath: tempDir.path,
      );

      expect(summary.totalFiles, 2);
      expect(summary.totalSymbols, greaterThanOrEqualTo(3));
      expect(summary.extensionCounts['.dart'], 1);
      expect(summary.extensionCounts['.py'], 1);

      // Verify database persistence
      final savedFiles = await ProjectsDatabase.getProjectFiles(db, projectId);
      expect(savedFiles.length, 2);

      final savedSymbols = await ProjectsDatabase.getProjectSymbols(db, projectId);
      final names = savedSymbols.map((s) => s['symbol_name']).toList();
      expect(names, contains('TaskController'));
      expect(names, contains('SyncState'));
      expect(names, contains('AuthService'));
    });

    test('Loads existing summary quickly from database without re-scanning', () async {
      await graphService.indexProject(
        projectId: projectId,
        rootPath: tempDir.path,
      );

      final cached = await graphService.loadExistingSummary(projectId);
      expect(cached.totalFiles, 2);
      expect(cached.totalSymbols, greaterThanOrEqualTo(3));
    });
  });

  group('AgentOrchestrator Workflow & Safety Tests', () {
    late Database db;
    late Directory tempDir;
    late ResourceManager resourceManager;
    late AgentOrchestrator orchestrator;
    late String projectId;

    setUp(() async {
      db = await ProjectsDatabase.open(path: inMemoryDatabasePath);

      tempDir = await Directory.systemTemp.createTemp('synctask_agent_test_');
      resourceManager = ResourceManager();
      await resourceManager.stopAllWorkers();
      orchestrator = AgentOrchestrator(projectsDb: db, resourceManager: resourceManager);
      projectId = await ProjectsDatabase.createProject(
        db,
        name: 'Agent Test Project',
        rootPath: tempDir.path,
      );
    });

    tearDown(() async {
      await db.close();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
      await resourceManager.stopAllWorkers();
    });

    test('Executes task successfully with step progression and checkpoints', () async {
      await orchestrator.runTask(
        projectId: projectId,
        taskDescription: 'Implement health check endpoint',
        rootPath: tempDir.path,
      );

      expect(orchestrator.status, 'completed');
      expect(orchestrator.steps.length, 4);
      expect(orchestrator.steps.every((s) => s.status == 'success'), isTrue);

      final sessions = await ProjectsDatabase.listSessions(db, projectId);
      expect(sessions.length, 1);
      expect(sessions.first['status'], 'completed');

      final checkpoints = await ProjectsDatabase.listCheckpoints(db, sessions.first['id']);
      expect(checkpoints.length, 1);
      expect(checkpoints.first['summary'], contains('Implement health check'));
    });

    test('Abort cleanly cancels active task and unregisters worker', () async {
      final taskFuture = orchestrator.runTask(
        projectId: projectId,
        taskDescription: 'Long running optimization task',
        rootPath: tempDir.path,
      );

      // Trigger abort while running
      await Future.delayed(const Duration(milliseconds: 50));
      await orchestrator.abort();
      await taskFuture;

      expect(orchestrator.status, 'aborted');
      expect(orchestrator.isExecuting, isFalse);

      final sessions = await ProjectsDatabase.listSessions(db, projectId);
      expect(sessions.first['status'], 'aborted');
    });
  });

  group('P2P AI Query Protocol Serialization Tests', () {
    test('aiQuery serialization and deserialization', () {
      final msg = SyncMessage.aiQuery(
        senderId: 'device_phone_1',
        queryId: 'q_123',
        prompt: 'Sky, summarize my active tasks for today',
      );

      final jsonStr = msg.toJson();
      final parsed = SyncMessage.fromJson(jsonStr);

      expect(parsed.type, SyncMessageType.aiQuery);
      expect(parsed.senderId, 'device_phone_1');
      expect(parsed.payload['query_id'], 'q_123');
      expect(parsed.payload['prompt'], 'Sky, summarize my active tasks for today');
    });

    test('aiResponse serialization and deserialization', () {
      final msg = SyncMessage.aiResponse(
        senderId: 'device_pc_master',
        queryId: 'q_123',
        text: 'You have 3 tasks pending, sir. None are overdue.',
        isComplete: true,
      );

      final jsonStr = msg.toJson();
      final parsed = SyncMessage.fromJson(jsonStr);

      expect(parsed.type, SyncMessageType.aiResponse);
      expect(parsed.senderId, 'device_pc_master');
      expect(parsed.payload['text'], contains('3 tasks pending'));
      expect(parsed.payload['is_complete'], isTrue);
    });

    test('aiStatus busy notification serialization', () {
      final msg = SyncMessage.aiStatus(
        senderId: 'device_pc_master',
        queryId: 'q_123',
        status: 'busy',
        reason: 'Host machine is compiling code',
      );

      final jsonStr = msg.toJson();
      final parsed = SyncMessage.fromJson(jsonStr);

      expect(parsed.type, SyncMessageType.aiStatus);
      expect(parsed.payload['status'], 'busy');
      expect(parsed.payload['reason'], contains('compiling'));
    });
  });
}
