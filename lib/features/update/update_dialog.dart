import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:synctask/platform/update_service.dart';

class UpdateDownloadDialog extends StatefulWidget {
  final AppRelease release;

  const UpdateDownloadDialog({super.key, required this.release});

  static Future<void> show(BuildContext context, AppRelease release) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => UpdateDownloadDialog(release: release),
    );
  }

  @override
  State<UpdateDownloadDialog> createState() => _UpdateDownloadDialogState();
}

class _UpdateDownloadDialogState extends State<UpdateDownloadDialog>
    with SingleTickerProviderStateMixin {
  double _progress = 0.0;
  int _downloadedBytes = 0;
  int _totalBytes = 0;
  String _status = 'Starting download...';
  bool _isComplete = false;
  String? _errorMessage;
  HttpClientRequest? _activeRequest;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _startDownload();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _activeRequest?.abort();
    super.dispose();
  }

  Future<void> _startDownload() async {
    try {
      final downloadUrl = widget.release.downloadUrl;
      final uri = Uri.parse(downloadUrl);

      final client = HttpClient();
      final request = await client.getUrl(uri);
      _activeRequest = request;
      request.headers.set('User-Agent', 'SyncTask-App');

      final response = await request.close();
      if (response.statusCode != 200) {
        setState(() {
          _errorMessage = 'Download failed (HTTP ${response.statusCode})';
        });
        return;
      }

      final contentLength = response.contentLength;
      setState(() {
        _totalBytes = contentLength > 0 ? contentLength : 0;
        _status = 'Downloading ${widget.release.versionTag}...';
      });

      final tempDir = await getTemporaryDirectory();
      final ext = Platform.isAndroid
          ? '.apk'
          : (Platform.isWindows
              ? (downloadUrl.toLowerCase().contains('.exe') ? '.exe' : '.zip')
              : '');
      final saveFile = File('${tempDir.path}/synctask_update$ext');
      if (await saveFile.exists()) {
        await saveFile.delete();
      }

      final sink = saveFile.openWrite();
      int received = 0;

      await for (final chunk in response) {
        sink.add(chunk);
        received += chunk.length;
        setState(() {
          _downloadedBytes = received;
          if (_totalBytes > 0) {
            _progress = (received / _totalBytes).clamp(0.0, 1.0);
          }
        });
      }

      await sink.flush();
      await sink.close();

      setState(() {
        _isComplete = true;
        _progress = 1.0;
        _status = 'Download complete! Preparing to install...';
      });

      await Future.delayed(const Duration(milliseconds: 600));
      await _executeInstall(saveFile);
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Update error: $e';
        });
      }
    }
  }

  Future<void> _executeInstall(File downloadedFile) async {
    try {
      if (Platform.isWindows) {
        if (downloadedFile.path.endsWith('.exe')) {
          await Process.run('cmd.exe', ['/c', 'start', '', downloadedFile.path]);
          exit(0);
        } else {
          // Automatically extract update and run installer
          final installDir = downloadedFile.parent.path;
          final powershellCmd =
              'Expand-Archive -Path "${downloadedFile.path}" -DestinationPath "$installDir\\synctask_new" -Force; '
              'if (Test-Path "$installDir\\synctask_new\\Install-SyncTask.cmd") { Start-Process cmd.exe -ArgumentList "/c `"$installDir\\synctask_new\\Install-SyncTask.cmd`"" } else { Start-Process "$installDir\\synctask_new\\synctask.exe" }';

          await Process.run('powershell', ['-Command', powershellCmd]);
          exit(0); // Close current app instance so installer/new version takes over
        }
      } else if (Platform.isAndroid) {
        // Direct native APK installation prompt
        try {
          const channel = MethodChannel('com.synctask/installer');
          await channel.invokeMethod('installApk', {'filePath': downloadedFile.path});
          if (mounted) Navigator.pop(context);
        } catch (_) {
          final updateService = GitHubUpdateService();
          await updateService.launchDownload(widget.release.downloadUrl);
          if (mounted) Navigator.pop(context);
        }
      }
    } catch (_) {
      // Fallback: open browser download
      final updateService = GitHubUpdateService();
      await updateService.launchDownload(widget.release.downloadUrl);
      if (mounted) Navigator.pop(context);
    }
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    int i = 0;
    double d = bytes.toDouble();
    while (d >= 1024 && i < suffixes.length - 1) {
      d /= 1024;
      i++;
    }
    return '${d.toStringAsFixed(1)} ${suffixes[i]}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          ScaleTransition(
            scale: Tween<double>(begin: 0.9, end: 1.1).animate(_pulseController),
            child: Icon(
              _isComplete ? Icons.check_circle : Icons.cloud_download,
              color: _isComplete ? Colors.green : theme.colorScheme.primary,
              size: 28,
            ),
          ),
          const SizedBox(width: 12),
          Text(_isComplete ? 'Installing Update' : 'Updating SyncTask'),
        ],
      ),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'SyncTask ${widget.release.versionTag}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text(
              _status,
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(height: 18),

            // Animated Linear Progress Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: _totalBytes > 0 ? _progress : null,
                minHeight: 10,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
              ),
            ),
            const SizedBox(height: 8),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatBytes(_downloadedBytes),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                ),
                Text(
                  _totalBytes > 0
                      ? '${(_progress * 100).toInt()}% of ${_formatBytes(_totalBytes)}'
                      : 'Connecting...',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),

            if (_errorMessage != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (_errorMessage != null || _isComplete)
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Dismiss'),
          ),
      ],
    );
  }
}
