import 'dart:async';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../core/lifecycle/resource_manager.dart';
import '../../core/lifecycle/resource_state.dart';
import '../../data/database/projects_database.dart';

/// Summary metadata produced by scanning and indexing a project workspace.
class ProjectGraphSummary {
  final int totalFiles;
  final int totalLines;
  final int totalSymbols;
  final Map<String, int> extensionCounts;
  final List<Map<String, dynamic>> topFiles;
  final List<Map<String, dynamic>> sampleSymbols;

  const ProjectGraphSummary({
    required this.totalFiles,
    required this.totalLines,
    required this.totalSymbols,
    required this.extensionCounts,
    required this.topFiles,
    required this.sampleSymbols,
  });

  factory ProjectGraphSummary.empty() => const ProjectGraphSummary(
        totalFiles: 0,
        totalLines: 0,
        totalSymbols: 0,
        extensionCounts: {},
        topFiles: [],
        sampleSymbols: [],
      );
}

/// Lightweight service that indexes workspace file trees and extracts AST symbols
/// into [ProjectsDatabase] while obeying strict 8 GB RAM limits.
class ProjectGraphService {
  final Database projectsDb;
  final ResourceManager resourceManager;

  static const int maxIndexedFiles = 400;
  static const int maxFileSizeBytes = 120 * 1024; // 120 KB max per file
  static const Set<String> ignoredDirectories = {
    '.git',
    '.dart_tool',
    'node_modules',
    'build',
    '.idea',
    '.vscode',
    '.gradle',
    'bin',
    'obj',
    'Pods',
    'DerivedData',
  };

  static const Set<String> codeExtensions = {
    '.dart',
    '.py',
    '.js',
    '.ts',
    '.kt',
    '.java',
    '.cpp',
    '.c',
    '.h',
    '.cs',
    '.go',
    '.rs',
  };

  ProjectGraphService({
    required this.projectsDb,
    ResourceManager? resourceManager,
  }) : resourceManager = resourceManager ?? ResourceManager.instance;

  /// Scans the project directory, extracts code symbols, and stores them in [ProjectsDatabase].
  Future<ProjectGraphSummary> indexProject({
    required String projectId,
    required String rootPath,
    void Function(String message, double progress)? onProgress,
  }) async {
    final workerId = 'proj_index_$projectId';
    resourceManager.registerWorker(
      id: workerId,
      name: 'Project Indexer ($projectId)',
      type: WorkerType.projectIndexer,
      priority: ResourcePriority.priority5Indexing,
      estimatedMemoryMb: 45,
    );

    final dir = Directory(rootPath);
    if (!await dir.exists()) {
      resourceManager.unregisterWorker(workerId);
      return ProjectGraphSummary.empty();
    }

    final fileRows = <Map<String, dynamic>>[];
    final symbolRows = <Map<String, dynamic>>[];
    final extCounts = <String, int>{};
    int totalLines = 0;

    try {
      resourceManager.updateWorkerState(workerId, WorkerState.busy);
      onProgress?.call('Discovering project files...', 0.1);

      final entities = <File>[];
      await for (final entity in dir.list(recursive: true, followLinks: false)) {
        // Enforce memory safety
        if (resourceManager.isUnderMemoryPressure) {
          onProgress?.call('Paused due to system memory pressure', 0.2);
          await Future.delayed(const Duration(milliseconds: 500));
        }

        if (entity is! File) continue;

        final relPath = p.relative(entity.path, from: rootPath);
        final parts = p.split(relPath);
        if (parts.any((segment) => ignoredDirectories.contains(segment))) {
          continue;
        }

        final ext = p.extension(entity.path).toLowerCase();
        if (codeExtensions.contains(ext) || ext == '.md' || ext == '.json' || ext == '.yaml') {
          entities.add(entity);
          if (entities.length >= maxIndexedFiles) break;
        }
      }

      final totalFound = entities.length;
      final now = DateTime.now().millisecondsSinceEpoch;

      for (int i = 0; i < totalFound; i++) {
        final file = entities[i];
        final relPath = p.relative(file.path, from: rootPath).replaceAll('\\', '/');
        final ext = p.extension(file.path).toLowerCase();

        extCounts[ext] = (extCounts[ext] ?? 0) + 1;

        int lines = 0;
        int size = 0;

        try {
          final stat = await file.stat();
          size = stat.size;

          if (size <= maxFileSizeBytes) {
            final content = await file.readAsString();
            lines = '\n'.allMatches(content).length + 1;
            totalLines += lines;

            if (codeExtensions.contains(ext)) {
              _extractSymbols(
                content: content,
                filePath: relPath,
                projectId: projectId,
                outputList: symbolRows,
              );
            }
          }
        } catch (_) {
          // Skip unreadable files cleanly
        }

        fileRows.add({
          'id': const Uuid().v4(),
          'project_id': projectId,
          'path': relPath,
          'extension': ext,
          'line_count': lines,
          'byte_size': size,
          'indexed_at': now,
        });

        if (i % 20 == 0 || i == totalFound - 1) {
          final prog = 0.1 + (0.8 * (i + 1) / (totalFound == 0 ? 1 : totalFound));
          onProgress?.call('Indexed ${i + 1} of $totalFound files...', prog);
        }
      }

      onProgress?.call('Persisting project index...', 0.95);
      await ProjectsDatabase.replaceProjectIndex(
        projectsDb,
        projectId: projectId,
        files: fileRows,
        symbols: symbolRows,
      );

      resourceManager.updateWorkerState(workerId, WorkerState.ready);
      onProgress?.call('Indexing complete', 1.0);

      fileRows.sort((a, b) => (b['line_count'] as int).compareTo(a['line_count'] as int));

      return ProjectGraphSummary(
        totalFiles: fileRows.length,
        totalLines: totalLines,
        totalSymbols: symbolRows.length,
        extensionCounts: extCounts,
        topFiles: fileRows.take(15).toList(),
        sampleSymbols: symbolRows.take(25).toList(),
      );
    } catch (_) {
      resourceManager.updateWorkerState(workerId, WorkerState.failed);
      rethrow;
    } finally {
      resourceManager.unregisterWorker(workerId);
    }
  }

  /// Extracts classes, functions, and interfaces using lightweight regex.
  void _extractSymbols({
    required String content,
    required String filePath,
    required String projectId,
    required List<Map<String, dynamic>> outputList,
  }) {
    final lines = content.split('\n');
    final classRegex = RegExp(r'^\s*(?:abstract\s+)?(?:class|interface|struct|enum)\s+([A-Za-z0-9_]+)');
    final funcRegex = RegExp(r'^\s*(?:Future<[^>]+>|void|[A-Za-z0-9_]+)\s+([a-zA-Z0-9_]+)\s*\(');

    for (int i = 0; i < lines.length; i++) {
      if (outputList.length >= 600) break; // Keep symbol storage bounded

      final line = lines[i];
      final classMatch = classRegex.firstMatch(line);
      if (classMatch != null && classMatch.groupCount >= 1) {
        outputList.add({
          'id': const Uuid().v4(),
          'project_id': projectId,
          'file_path': filePath,
          'symbol_name': classMatch.group(1)!,
          'symbol_type': 'class',
          'line_number': i + 1,
        });
        continue;
      }

      final funcMatch = funcRegex.firstMatch(line);
      if (funcMatch != null && funcMatch.groupCount >= 1) {
        final name = funcMatch.group(1)!;
        if (name != 'if' && name != 'for' && name != 'while' && name != 'switch') {
          outputList.add({
            'id': const Uuid().v4(),
            'project_id': projectId,
            'file_path': filePath,
            'symbol_name': name,
            'symbol_type': 'function',
            'line_number': i + 1,
          });
        }
      }
    }
  }

  /// Loads the existing index summary from [ProjectsDatabase] without rescan.
  Future<ProjectGraphSummary> loadExistingSummary(String projectId) async {
    final files = await ProjectsDatabase.getProjectFiles(projectsDb, projectId);
    final symbols = await ProjectsDatabase.getProjectSymbols(projectsDb, projectId);

    final extCounts = <String, int>{};
    int totalLines = 0;

    for (final f in files) {
      final ext = f['extension'] as String? ?? '';
      extCounts[ext] = (extCounts[ext] ?? 0) + 1;
      totalLines += (f['line_count'] as int? ?? 0);
    }

    return ProjectGraphSummary(
      totalFiles: files.length,
      totalLines: totalLines,
      totalSymbols: symbols.length,
      extensionCounts: extCounts,
      topFiles: files.take(15).toList(),
      sampleSymbols: symbols.take(25).toList(),
    );
  }
}
