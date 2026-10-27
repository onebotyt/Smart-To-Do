import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:synctask/core/ai/model_gateway.dart';
import 'package:synctask/core/lifecycle/resource_manager.dart';
import 'package:synctask/data/database/memory_database.dart';
import 'package:synctask/data/models/task.dart';
import 'package:synctask/data/repositories/memory_repository.dart';
import 'package:synctask/features/sky/sky_controller.dart';
import 'package:synctask/features/sky/widgets/sky_mascot_widget.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Sky AI Controller & Model Gateway Tests', () {
    late MemoryRepository memoryRepo;
    late ManagedModelGateway gateway;
    late SkyController sky;

    setUp(() async {
      final db = await MemoryDatabase.open(path: inMemoryDatabasePath);
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
  });
}
