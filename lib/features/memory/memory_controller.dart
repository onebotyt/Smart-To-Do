import 'package:flutter/foundation.dart';
import '../../data/models/memory_item.dart';
import '../../data/repositories/memory_repository.dart';

/// Lightweight controller for shared memory access.
/// Provides bounded queries that never consume high memory.
class MemoryController extends ChangeNotifier {
  final MemoryRepository _repo;
  List<MemoryItem> _recentMemories = [];
  bool _isLoading = false;

  MemoryController(this._repo);

  List<MemoryItem> get recentMemories => List.unmodifiable(_recentMemories);
  bool get isLoading => _isLoading;

  /// Loads recent memories (bounded to top 25).
  Future<void> loadRecentMemories({String? category}) async {
    _isLoading = true;
    notifyListeners();

    try {
      _recentMemories = await _repo.getMemories(category: category, limit: 25);
    } catch (_) {
      _recentMemories = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Searches memories with a query string.
  Future<List<MemoryItem>> search(String query) async {
    return _repo.searchMemories(query, limit: 15);
  }

  /// Adds a new memory.
  Future<String> addMemory({
    required String content,
    String category = 'general',
    String source = 'user',
    double confidence = 1.0,
  }) async {
    final id = await _repo.saveMemory(
      content: content,
      category: category,
      source: source,
      confidence: confidence,
    );
    await loadRecentMemories();
    return id;
  }

  /// Removes a memory item.
  Future<void> removeMemory(String id) async {
    await _repo.deleteMemory(id);
    await loadRecentMemories();
  }

  /// Logs a conversation turn with Sky AI.
  Future<void> logMessage({
    required String sessionId,
    required String role,
    required String content,
  }) async {
    await _repo.recordMessage(
      sessionId: sessionId,
      role: role,
      content: content,
    );
  }

  /// Retrieves messages for a conversation session.
  Future<List<ConversationMessage>> getHistory(String sessionId) async {
    return _repo.getConversationHistory(sessionId, limit: 50);
  }
}
