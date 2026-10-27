import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:synctask/core/logger/app_logger.dart';
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
  bool _isDownloading = false;
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
    if (!mounted) return;
    setState(() {
      _isDownloading = true;
      _errorMessage = null;
      _status = 'Connecting...';
    });

    final downloadUrl = widget.release.downloadUrl;
    final tempDir = await getTemporaryDirectory();
    final ext = Platform.isAndroid
        ? '.apk'
        : (Platform.isWindows
            ? (downloadUrl.toLowerCase().contains('.exe') ? '.exe' : '.zip')
            : '');
    final saveFile = File('${tempDir.path}/synctask_update$ext');

    const int maxAttempts = 5;
    int attempt = 0;
    bool success = false;

    while (attempt < maxAttempts && !success && mounted) {
      attempt++;
      HttpClient? client;
      try {
        client = HttpClient()
          ..connectionTimeout = const Duration(seconds: 30)
          ..idleTimeout = const Duration(seconds: 30);

        int existingBytes = 0;
        if (await saveFile.exists()) {
          existingBytes = await saveFile.length();
        }

        if (_totalBytes > 0 && existingBytes >= _totalBytes) {
          success = true;
          break;
        }

        final uri = Uri.parse(downloadUrl);
        final request = await client.getUrl(uri);
        _activeRequest = request;
        request.headers.set('User-Agent', 'SyncTask-App');
        request.headers.set('Accept-Encoding', 'identity');

        if (existingBytes > 0) {
          request.headers.set('Range', 'bytes=$existingBytes-');
          if (mounted) {
            setState(() {
              _status = 'Resuming download (${_formatBytes(existingBytes)})...';
            });
          }
        } else {
          if (mounted) {
            setState(() {
              _status = 'Downloading ${widget.release.versionTag}...';
            });
          }
        }

        final response = await request.close();

        // 200 OK (fresh download), 206 Partial Content (resumed)
        if (response.statusCode != HttpStatus.ok &&
            response.statusCode != HttpStatus.partialContent) {
          if (response.statusCode == HttpStatus.requestedRangeNotSatisfiable) {
            if (await saveFile.exists()) await saveFile.delete();
            existingBytes = 0;
            continue;
          }
          throw HttpException('HTTP ${response.statusCode}');
        }

        if (response.statusCode == HttpStatus.partialContent) {
          final contentRange = response.headers.value(HttpHeaders.contentRangeHeader);
          if (contentRange != null && contentRange.contains('/')) {
            final totalStr = contentRange.split('/').last;
            final parsedTotal = int.tryParse(totalStr);
            if (parsedTotal != null && parsedTotal > 0) {
              _totalBytes = parsedTotal;
            }
          } else if (_totalBytes == 0 && response.contentLength > 0) {
            _totalBytes = existingBytes + response.contentLength;
          }
        } else {
          existingBytes = 0;
          if (await saveFile.exists()) await saveFile.delete();
          if (response.contentLength > 0) {
            _totalBytes = response.contentLength;
          }
        }

        final openMode = existingBytes > 0 ? FileMode.append : FileMode.write;
        final sink = saveFile.openWrite(mode: openMode);
        int received = existingBytes;

        await for (final chunk in response) {
          sink.add(chunk);
          received += chunk.length;
          if (mounted) {
            setState(() {
              _downloadedBytes = received;
              if (_totalBytes > 0) {
                _progress = (received / _totalBytes).clamp(0.0, 1.0);
              }
            });
          }
        }

        await sink.flush();
        await sink.close();

        if (_totalBytes > 0 && received < _totalBytes) {
          throw HttpException('Connection closed prematurely ($received/$_totalBytes bytes)');
        }

        success = true;
      } catch (e) {
        client?.close(force: true);
        AppLogger.warning('update', 'Download attempt $attempt/$maxAttempts failed: $e');

        if (attempt < maxAttempts) {
          if (mounted) {
            setState(() {
              _status = 'Connection interrupted. Resuming ($attempt/$maxAttempts)...';
            });
          }
          await Future.delayed(Duration(seconds: attempt * 2));
        } else {
          if (mounted) {
            String displayError = 'Connection lost while downloading. Please check your network and try again.';
            if (e is SocketException) {
              displayError = 'Network error: Unable to connect to update server.';
            } else if (e is HttpException) {
              displayError = 'Download was interrupted. Click Retry Download to resume from where it stopped.';
            }
            setState(() {
              _errorMessage = displayError;
              _status = 'Download paused';
              _isDownloading = false;
            });
          }
          return;
        }
      } finally {
        client?.close(force: true);
      }
    }

    if (success && mounted) {
      setState(() {
        _isComplete = true;
        _isDownloading = false;
        _progress = 1.0;
        _status = 'Download complete! Preparing to install...';
      });

      await Future.delayed(const Duration(milliseconds: 500));
      await _executeInstall(saveFile);
    }
  }

  Future<void> _executeInstall(File downloadedFile) async {
    try {
      if (Platform.isWindows) {
        final installerPath = downloadedFile.path;
        final isZip = !installerPath.toLowerCase().endsWith('.exe');

        // Official native Windows update installer (zero cmd.exe window)
        try {
          const nativeChannel = MethodChannel('com.synctask/native_update');
          final ok = await nativeChannel.invokeMethod<bool>('installUpdate', {
            'installerPath': installerPath,
            'isZip': isZip,
          });
          if (ok == true) return;
        } catch (e) {
          AppLogger.warning('update', 'Native Win32 update installer fallback: $e');
        }

        // Silent Inno Setup fallback without cmd prompt window
        if (!isZip) {
          await Process.start(
            installerPath,
            ['/VERYSILENT', '/SUPPRESSMSGBOXES', '/FORCECLOSEAPPLICATIONS', '/NORESTART'],
            mode: ProcessStartMode.detached,
          );
          exit(0);
        } else {
          final currentExe = Platform.resolvedExecutable;
          final targetDir = File(currentExe).parent.path;
          final runnerScript = File('${downloadedFile.parent.path}/silent_zip_update.bat');
          await runnerScript.writeAsString('''@echo off
timeout /t 1 /nobreak >nul
taskkill /F /IM synctask.exe >nul 2>&1
timeout /t 1 /nobreak >nul
powershell -NoProfile -NonInteractive -WindowStyle Hidden -Command "Expand-Archive -Path '${downloadedFile.path}' -DestinationPath '$targetDir' -Force"
timeout /t 1 /nobreak >nul
start "" "$currentExe"
del "%~f0" >nul 2>&1
''');
          await Process.start('cmd.exe', ['/c', runnerScript.path], mode: ProcessStartMode.detached);
          exit(0);
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
              _isComplete
                  ? Icons.check_circle
                  : (_errorMessage != null ? Icons.error_outline : Icons.cloud_download),
              color: _isComplete
                  ? Colors.green
                  : (_errorMessage != null ? Colors.amber : theme.colorScheme.primary),
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
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline, color: Colors.red, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red, fontSize: 12, height: 1.3),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (_errorMessage != null && !_isDownloading) ...[
          FilledButton.icon(
            onPressed: () {
              _startDownload();
            },
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Retry Download'),
          ),
          OutlinedButton.icon(
            onPressed: () async {
              final updateService = GitHubUpdateService();
              await updateService.launchDownload(widget.release.downloadUrl);
              if (context.mounted) Navigator.pop(context);
            },
            icon: const Icon(Icons.open_in_browser, size: 16),
            label: const Text('Open in Browser'),
          ),
        ],
        if (_errorMessage != null || _isComplete)
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Dismiss'),
          ),
      ],
    );
  }
}
