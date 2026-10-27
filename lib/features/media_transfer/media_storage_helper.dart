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
  if (Platform.isAndroid) {
    try {
      baseDir = await getExternalStorageDirectory();
    } catch (_) {}
    if (baseDir == null) {
      try {
        baseDir = await getApplicationDocumentsDirectory();
      } catch (_) {}
    }
  } else {
    try {
      baseDir = await getDownloadsDirectory();
    } catch (_) {}
    if (baseDir == null) {
      try {
        baseDir = await getApplicationDocumentsDirectory();
      } catch (_) {}
    }
  }

  baseDir ??= Directory.systemTemp;

  try {
    final syncTaskDir = Directory(path.join(baseDir.path, 'SyncTask'));
    if (!syncTaskDir.existsSync()) {
      syncTaskDir.createSync(recursive: true);
    }
    return syncTaskDir;
  } catch (_) {
    try {
      if (!baseDir.existsSync()) {
        baseDir.createSync(recursive: true);
      }
      return baseDir;
    } catch (_) {
      return Directory.systemTemp;
    }
  }
}

String sanitizeFileName(String name) {
  return name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
}
