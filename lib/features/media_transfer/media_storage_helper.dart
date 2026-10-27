import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

Directory? _testSaveDirectory;

void setMediaSaveDirectoryForTesting(Directory? dir) {
  _testSaveDirectory = dir;
}

Future<Directory> getMediaSaveDirectory() async {
  if (_testSaveDirectory != null) {
    if (!_testSaveDirectory!.existsSync()) {
      _testSaveDirectory!.createSync(recursive: true);
    }
    return _testSaveDirectory!;
  }

  Directory? baseDir;
  try {
    baseDir = await getDownloadsDirectory();
  } catch (_) {}

  if (baseDir == null) {
    try {
      baseDir = await getApplicationDocumentsDirectory();
    } catch (_) {}
  }

  baseDir ??= Directory.systemTemp;
  final syncTaskDir = Directory(path.join(baseDir.path, 'SyncTask'));
  if (!syncTaskDir.existsSync()) {
    syncTaskDir.createSync(recursive: true);
  }
  return syncTaskDir;
}

String sanitizeFileName(String name) {
  return name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
}
