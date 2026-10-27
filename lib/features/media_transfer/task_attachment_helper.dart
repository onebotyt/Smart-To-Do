import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as path;
import 'package:synctask/features/media_transfer/media_storage_helper.dart';

class TaskAttachmentHelper {
  static final RegExp _tagRegex = RegExp(r'\[attachment:(.+?)\]');

  /// Extracts list of local file paths attached to a task's notes.
  static List<String> extractAttachments(String notes) {
    if (notes.isEmpty) return [];
    return _tagRegex
        .allMatches(notes)
        .map((m) => m.group(1)?.trim() ?? '')
        .where((p) => p.isNotEmpty)
        .toList();
  }

  /// Returns note text without the [attachment:...] tags.
  static String cleanNoteText(String notes) {
    if (notes.isEmpty) return '';
    return notes.replaceAll(_tagRegex, '').trim();
  }

  /// Appends an attachment tag to notes text.
  static String formatNoteWithAttachments(String baseNote, List<String> attachments) {
    final clean = cleanNoteText(baseNote);
    if (attachments.isEmpty) return clean;
    final tags = attachments.map((a) => '[attachment:$a]').join('\n');
    return clean.isEmpty ? tags : '$clean\n$tags';
  }

  /// Picks a file and stores it into SyncTask/attachments folder.
  static Future<String?> pickAndStoreAttachment() async {
    try {
      final files = await FilePicker.pickFiles(type: FileType.any);
      if (files.isEmpty) return null;

      final srcPath = files.first.path;
      if (srcPath == null) return null;

      final srcFile = File(srcPath);
      if (!srcFile.existsSync()) return null;

      final saveDir = await getMediaSaveDirectory();
      final attachDir = Directory(path.join(saveDir.path, 'attachments'));
      if (!attachDir.existsSync()) {
        attachDir.createSync(recursive: true);
      }

      final fileName = sanitizeFileName(path.basename(srcPath));
      String destPath = path.join(attachDir.path, fileName);
      if (File(destPath).existsSync()) {
        final ext = path.extension(fileName);
        final base = path.basenameWithoutExtension(fileName);
        final ts = DateTime.now().millisecondsSinceEpoch;
        destPath = path.join(attachDir.path, '${base}_$ts$ext');
      }

      final saved = await srcFile.copy(destPath);
      return saved.path;
    } catch (_) {
      return null;
    }
  }

  /// Opens an attachment file with native app.
  static Future<OpenResult> openAttachment(String filePath) async {
    return await OpenFilex.open(filePath);
  }
}
