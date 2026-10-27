import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:synctask/data/database/memory_database.dart';
import 'package:synctask/data/repositories/memory_repository.dart';
import 'package:synctask/features/memory/memory_controller.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('MemoryRepository & MemoryController Unit Tests', () {
    late Database db;
    late MemoryRepository repository;
    late MemoryController controller;

    setUp(() async {
      db = await MemoryDatabase.open(path: inMemoryDatabasePath);
      await db.delete('memories');
      await db.delete('conversations');
      repository = MemoryRepository(db);
      controller = MemoryController(repository);
    });

    tearDown(() async {
      await db.close();
    });

    test('Saves memory and retrieves with category filtering', () async {
      final id1 = await repository.saveMemory(
        content: 'Preferred LLM model is Qwen 2.5 Coder',
        category: 'preferences',
      );
      final id2 = await repository.saveMemory(
        content: 'Sprint deadline is November 15th',
        category: 'project',
      );

      expect(id1, isNotEmpty);
      expect(id2, isNotEmpty);

      final all = await repository.getMemories();
      expect(all.length, 2);

      final prefs = await repository.getMemories(category: 'preferences');
      expect(prefs.length, 1);
      expect(prefs.first.content, contains('Qwen 2.5'));
    });

    test('Searches memories by keyword with bounded limit', () async {
      await repository.saveMemory(content: 'Always format code with 2 spaces indent');
      await repository.saveMemory(content: 'Use atomic transactions for SQLite writes');
      await repository.saveMemory(content: 'Never log sensitive task notes');

      final results = await repository.searchMemories('SQLite');
      expect(results.length, 1);
      expect(results.first.content, contains('atomic transactions'));

      // Test empty query returns empty
      final emptyResults = await repository.searchMemories('');
      expect(emptyResults, isEmpty);
    });

    test('Deletes memory by ID successfully', () async {
      final id = await repository.saveMemory(content: 'Temporary note to be forgotten');
      final before = await repository.getMemories();
      expect(before.length, 1);

      await repository.deleteMemory(id);
      final after = await repository.getMemories();
      expect(after, isEmpty);
    });

    test('Logs conversation messages and retrieves in chronological order', () async {
      const sessionId = 'session-101';
      await repository.recordMessage(sessionId: sessionId, role: 'user', content: 'Sky, summarize today tasks');
      await repository.recordMessage(sessionId: sessionId, role: 'assistant', content: 'You have 3 tasks due today.');

      final history = await repository.getConversationHistory(sessionId);
      expect(history.length, 2);
      expect(history[0].role, 'user');
      expect(history[1].role, 'assistant');

      await repository.clearConversation(sessionId);
      final cleared = await repository.getConversationHistory(sessionId);
      expect(cleared, isEmpty);
    });

    test('MemoryController loads, adds, and removes items reactively', () async {
      expect(controller.recentMemories, isEmpty);

      await controller.addMemory(
        content: 'User prefers dark mode',
        category: 'settings',
      );

      expect(controller.recentMemories.length, 1);
      expect(controller.recentMemories.first.content, 'User prefers dark mode');

      final searchRes = await controller.search('dark mode');
      expect(searchRes.length, 1);

      await controller.removeMemory(controller.recentMemories.first.id);
      expect(controller.recentMemories, isEmpty);
    });
  });
}
