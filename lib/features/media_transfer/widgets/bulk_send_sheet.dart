import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:provider/provider.dart';
import 'package:synctask/data/models/device.dart';
import 'package:synctask/features/media_transfer/media_transfer_controller.dart';
import 'package:synctask/features/sync/qr_scan_page.dart';
import 'package:synctask/features/sync/sync_controller.dart';
import 'package:synctask/platform/window_service.dart';

class BulkSendSheet extends StatefulWidget {
  final List<File>? initialFiles;

  const BulkSendSheet({super.key, this.initialFiles});

  static Future<void> show(BuildContext context, {List<File>? initialFiles}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => BulkSendSheet(initialFiles: initialFiles),
    );
  }

  @override
  State<BulkSendSheet> createState() => _BulkSendSheetState();
}

class _BulkSendSheetState extends State<BulkSendSheet> {
  final List<File> _stagedFiles = [];
  Device? _selectedDevice;
  bool _sendViaQr = true;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialFiles != null && widget.initialFiles!.isNotEmpty) {
      _stagedFiles.addAll(widget.initialFiles!);
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _pickMoreFiles();
      });
    }
  }

  Future<void> _pickMoreFiles() async {
    try {
      if (Platform.isWindows) {
        await PlatformWindowService.setAlwaysOnTop(false);
      }

      final picked = await FilePicker.pickFiles(
        type: FileType.any,
      );

      if (picked.isEmpty) return;

      final newFiles = picked
          .map((p) => p.path)
          .whereType<String>()
          .where((p) => File(p).existsSync())
          .map((p) => File(p))
          .toList();

      if (mounted) {
        setState(() {
          for (final f in newFiles) {
            if (!_stagedFiles.any((existing) => existing.path == f.path)) {
              _stagedFiles.add(f);
            }
          }
        });
      }
    } catch (_) {}
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  int get _totalBytes {
    int total = 0;
    for (final f in _stagedFiles) {
      try {
        if (f.existsSync()) total += f.lengthSync();
      } catch (_) {}
    }
    return total;
  }

  Future<void> _handleSend(BuildContext context) async {
    if (_stagedFiles.isEmpty) return;
    final mediaCtrl = context.read<MediaTransferController>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    setState(() => _isSending = true);

    if (_sendViaQr || _selectedDevice == null) {
      // 1. Send via QR Quick Share
      final scanResult = await navigator.push<Map<String, dynamic>>(
        MaterialPageRoute(
          builder: (_) => QRScanPage(
            title: 'Scan Receiver QR Code',
            prompt: 'Point camera at receiver screen to send ${_stagedFiles.length} file(s)',
          ),
        ),
      );

      if (scanResult == null) {
        if (mounted) setState(() => _isSending = false);
        return;
      }

      final host = scanResult['ip'] as String?;
      final port = scanResult['port'] as int? ?? 43884;
      final token = scanResult['token'] as String?;
      final targetName = (scanResult['device_name'] as String?) ?? 'Target Device';

      if (host == null || token == null) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Invalid Quick Share QR code'), backgroundColor: Colors.red),
        );
        if (mounted) setState(() => _isSending = false);
        return;
      }

      navigator.pop(); // close sheet
      messenger.showSnackBar(
        SnackBar(
          content: Text('⚡ Sending ${_stagedFiles.length} file(s) to $targetName...'),
          duration: const Duration(seconds: 2),
        ),
      );

      final count = await mediaCtrl.sendFilesViaQuickShare(
        host: host,
        port: port,
        token: token,
        targetDeviceName: targetName,
        files: List.from(_stagedFiles),
      );

      if (count > 0) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('🎉 Successfully sent $count file(s) to $targetName!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      // 2. Send to Paired Device
      final target = _selectedDevice!;
      navigator.pop(); // close sheet

      messenger.showSnackBar(
        SnackBar(
          content: Text('⚡ Sending ${_stagedFiles.length} file(s) to ${target.name}...'),
          duration: const Duration(seconds: 2),
        ),
      );

      final count = await mediaCtrl.sendMultipleFiles(
        target,
        List.from(_stagedFiles),
      );

      if (count > 0) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('🎉 Successfully sent $count file(s) to ${target.name}!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final syncCtrl = context.watch<SyncController>();
    final pairedDevices = syncCtrl.devices.where((d) => d.trusted && d.ipAddress != null).toList();

    if (_selectedDevice == null && pairedDevices.isNotEmpty) {
      _selectedDevice = pairedDevices.first;
    }

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.folder_zip_rounded, color: Color(0xFF2563EB), size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Bulk Media Sender',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${_stagedFiles.length} file(s) selected • ${_formatSize(_totalBytes)}',
                      style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add More'),
                onPressed: _pickMoreFiles,
              ),
            ],
          ),
          const SizedBox(height: 14),

          // File List
          if (_stagedFiles.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              alignment: Alignment.center,
              child: Column(
                children: [
                  const Icon(Icons.upload_file_rounded, size: 48, color: Colors.grey),
                  const SizedBox(height: 8),
                  const Text('No files selected yet'),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    icon: const Icon(Icons.folder_open_rounded),
                    label: const Text('Select Files from Device'),
                    onPressed: _pickMoreFiles,
                  ),
                ],
              ),
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _stagedFiles.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (context, idx) {
                  final file = _stagedFiles[idx];
                  final name = path.basename(file.path);
                  int size = 0;
                  try { size = file.lengthSync(); } catch (_) {}

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.insert_drive_file_outlined, size: 22, color: Color(0xFF2563EB)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                _formatSize(size),
                                style: TextStyle(fontSize: 11, color: theme.colorScheme.outline),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          tooltip: 'Remove',
                          onPressed: () {
                            setState(() {
                              _stagedFiles.removeAt(idx);
                            });
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 16),

          // Send Destination Selector
          const Text('Send Destination', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.qr_code_scanner, size: 16),
                      SizedBox(width: 6),
                      Text('Scan QR (Any Device)'),
                    ],
                  ),
                  selected: _sendViaQr,
                  onSelected: (val) => setState(() => _sendViaQr = true),
                ),
              ),
              if (pairedDevices.isNotEmpty) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: ChoiceChip(
                    label: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.devices, size: 16),
                        const SizedBox(width: 6),
                        Text(pairedDevices.length == 1 ? pairedDevices.first.name : 'Paired Device'),
                      ],
                    ),
                    selected: !_sendViaQr,
                    onSelected: (val) => setState(() => _sendViaQr = false),
                  ),
                ),
              ],
            ],
          ),

          if (!_sendViaQr && pairedDevices.length > 1) ...[
            const SizedBox(height: 8),
            DropdownButtonFormField<Device>(
              initialValue: _selectedDevice,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              items: pairedDevices.map((d) {
                return DropdownMenuItem<Device>(
                  value: d,
                  child: Text(d.name),
                );
              }).toList(),
              onChanged: (dev) => setState(() => _selectedDevice = dev),
            ),
          ],
          const SizedBox(height: 16),

          // Action Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              icon: _isSending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send_rounded),
              label: Text(
                _isSending
                    ? 'Connecting & Sending...'
                    : 'Send ${_stagedFiles.length} File(s) (${_formatSize(_totalBytes)})',
              ),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _stagedFiles.isEmpty || _isSending
                  ? null
                  : () => _handleSend(context),
            ),
          ),
        ],
      ),
    );
  }
}
