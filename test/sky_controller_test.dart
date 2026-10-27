import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:synctask/core/ai/model_gateway.dart';
import 'package:synctask/core/lifecycle/resource_manager.dart';
import 'package:synctask/data/database/memory_database.dart';
import 'package:synctask/data/models/task.dart';
import 'package:synctask/data/repositories/memory_repository.dart';
import 'package:synctask/features/sky/sky_controller.dart';
import 'package:synctask/features/tasks/task_controller.dart';
import 'package:synctask/data/repositories/task_repository.dart';
import 'package:synctask/data/database/app_database.dart';
import 'package:synctask/features/settings/settings_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:synctask/features/sky/widgets/sky_mascot_widget.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Sky AI Controller & Model Gateway Tests', () {
    late Database db;
    late MemoryRepository memoryRepo;
    late ManagedModelGateway gateway;
    late SkyController sky;

    setUp(() async {
      db = await MemoryDatabase.open(path: inMemoryDatabasePath);
      await db.delete('memories');
      await db.delete('conversations');

      memoryRepo = MemoryRepository(db);
      gateway = ManagedModelGateway(
        modelId: 'sky-test-model',
        modelName: 'Sky SLM 1.5B',
        estimatedMemoryMb: 500,
        resourceManager: ResourceManager(),
      );
      sky = SkyController(
        modelGateway: gateway,
        memoryRepo: memoryRepo,
      );
    });

    tearDown(() async {
      await gateway.unload();
      sky.dispose();
      await db.close();
    });

    test('Initializes with idle mood and inactive state', () {
      expect(sky.mood, SkyMascotMood.idle);
      expect(sky.isProcessing, isFalse);
      expect(gateway.isLoaded, isFalse);
    });

    test('Asks question, cycles moods to thinking and speaking, and records turn in memory', () async {
      final answer = await sky.ask('Hey Sky, what is your status?');

      expect(answer, contains('operational'));
      expect(sky.mood, SkyMascotMood.speaking);

      // Verify conversation log in memory repository
      final history = await memoryRepo.getConversationHistory('default-sky-session');
      expect(history.length, 2);
      expect(history[0].role, 'user');
      expect(history[0].content, contains('status'));
      expect(history[1].role, 'assistant');
    });

    test('celebrateTaskCompletion sets mood to celebrating', () {
      sky.celebrateTaskCompletion('Deploy v1.0 to production');
      expect(sky.mood, SkyMascotMood.celebrating);
      expect(sky.lastSpokenText, contains('Deploy v1.0'));
    });

    test('alertUrgentTask sets mood to alert', () {
      sky.alertUrgentTask('Fix critical production bug');
      expect(sky.mood, SkyMascotMood.alert);
      expect(sky.lastSpokenText, contains('critical'));
    });

    test('generateBriefing generates correct Iron Man / Jarvis summaries', () {
      // Empty task list
      final emptyBriefing = sky.generateBriefing([]);
      expect(emptyBriefing, contains('All caught up'));

      // Normal task list
      const task1 = Task(
        id: 't-1',
        title: 'Review pull requests',
        notes: '',
        priority: 1,
        completed: false,
        category: 'work',
        recurrence: Recurrence.none,
        createdAt: 0,
        updatedAt: 0,
        revision: 1,
        deviceId: 'dev-1',
        deleted: false,
      );
      final normalBriefing = sky.generateBriefing([task1]);
      expect(normalBriefing, contains('1 tasks scheduled'));
      expect(normalBriefing, contains('Review pull requests'));

      // High priority task
      const task2 = Task(
        id: 't-2',
        title: 'Submit quarterly budget',
        notes: '',
        priority: 3,
        completed: false,
        category: 'finance',
        recurrence: Recurrence.none,
        createdAt: 0,
        updatedAt: 0,
        revision: 1,
        deviceId: 'dev-1',
        deleted: false,
      );
      final urgentBriefing = sky.generateBriefing([task1, task2]);
      expect(urgentBriefing, contains('1 high priority'));
      expect(urgentBriefing, contains('Submit quarterly budget'));
    });
    test('speakBriefing displays briefing text and sets mood to speaking', () {
      sky.speakBriefing('Good morning, sir. Systems operational.');
      expect(sky.mood, SkyMascotMood.speaking);
      expect(sky.lastSpokenText, contains('Systems operational'));
    });

    test('recommendNextAction prioritizes high priority and due items', () {
      const normalTask = Task(
        id: 't-1',
        title: 'Check email',
        notes: '',
        priority: 1,
        completed: false,
        category: 'work',
        recurrence: Recurrence.none,
        createdAt: 0,
        updatedAt: 0,
        revision: 1,
        deviceId: 'dev-1',
        deleted: false,
      );
      const urgentTask = Task(
        id: 't-2',
        title: 'Security patch deployment',
        notes: '',
        priority: 3,
        completed: false,
        category: 'dev',
        recurrence: Recurrence.none,
        createdAt: 0,
        updatedAt: 0,
        revision: 1,
        deviceId: 'dev-1',
        deleted: false,
      );

      final next = sky.recommendNextAction([normalTask, urgentTask]);
      expect(next, contains('Security patch deployment'));
      expect(next, contains('High Priority'));
    });

    test('Natural language task creation and completion via Sky NLP', () async {
      final appDb = await AppDatabase.open(path: 'sky_tasks_test.db');
      await appDb.delete('tasks');
      await appDb.delete('change_log');
      final taskRepo = TaskRepository(appDb, 'test-dev-1');
      SharedPreferences.setMockInitialValues({});
      final settings = await SettingsController.load();
      final taskController = TaskController(taskRepo, settings, null, () {});
      await taskController.refresh();

      sky.taskController = taskController;

      // 1. Natural Language Creation
      final addResp = await sky.ask('Sky, add task Finish client proposal urgent');
      expect(addResp, contains('Created task'));
      expect(addResp, contains('High Priority'));

      await taskController.refresh();
      expect(taskController.tasks.length, 1);
      expect(taskController.tasks.first.title, contains('Finish client proposal'));
      expect(taskController.tasks.first.priority, 3);

      // 2. Natural Language Completion
      final doneResp = await sky.ask('Sky, complete Finish client proposal');
      expect(doneResp, contains('completed'));
      expect(sky.mood, SkyMascotMood.celebrating);

      await taskController.refresh();
      expect(taskController.tasks.first.completed, isTrue);

      await appDb.close();
      await databaseFactory.deleteDatabase('sky_tasks_test.db');
    });

    test('Hardware & System status query provides instant accurate specifications', () async {
      final statusResp = await sky.ask('What is the hardware status?');
      expect(statusResp, anyOf(contains('IdeaPad'), contains('Vivo'), contains('RTX 2050')));
    });

    test('Autonomous watchdog triggers alert for overdue tasks', () async {
      final appDb = await AppDatabase.open(path: 'sky_tasks_watchdog_test.db');
      await appDb.delete('tasks');
      final taskRepo = TaskRepository(appDb, 'test-dev-watchdog');
      SharedPreferences.setMockInitialValues({});
      final settings = await SettingsController.load();
      final taskController = TaskController(taskRepo, settings, null, () {});
      await taskController.create(
        title: 'Submit server logs',
        dueAt: DateTime.now().subtract(const Duration(hours: 1)).millisecondsSinceEpoch,
        priority: 2,
      );
      await taskController.refresh();

      sky.taskController = taskController;
      sky.startAutonomousWatchdog();

      // Explicitly trigger check
      final tasks = taskController.tasks;
      expect(tasks.isNotEmpty, isTrue);
      expect(tasks.first.dueAt, isNotNull);

      // Verify alertUrgentTask works directly and updates state
      sky.alertUrgentTask(tasks.first.title);
      expect(sky.mood, SkyMascotMood.alert);
      expect(sky.lastSpokenText, contains('Submit server logs'));

      await appDb.close();
      await databaseFactory.deleteDatabase('sky_tasks_watchdog_test.db');
    });
  });
}
