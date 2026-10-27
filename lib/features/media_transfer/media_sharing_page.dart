import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:synctask/data/models/device.dart';
import 'package:synctask/features/media_transfer/media_storage_helper.dart';
import 'package:synctask/features/media_transfer/media_transfer_controller.dart';
import 'package:synctask/features/media_transfer/models/media_transfer.dart';
import 'package:synctask/features/sync/devices_page.dart';
import 'package:synctask/features/sync/sync_controller.dart';

/// Dedicated page for Direct Device-to-Device P2P Media & File Sharing
/// (Quick Share / AirDrop style over local Wi-Fi, Hotspot, and Bluetooth).
class MediaSharingPage extends StatefulWidget {
  final Device? initialTargetDevice;

  const MediaSharingPage({super.key, this.initialTargetDevice});

  @override
  State<MediaSharingPage> createState() => _MediaSharingPageState();
}

class _MediaSharingPageState extends State<MediaSharingPage> {
  Device? _selectedDevice;
  String _saveDirPath = '';

  @override
  void initState() {
    super.initState();
    _selectedDevice = widget.initialTargetDevice;
    _loadSaveDirectory();
  }

  Future<void> _loadSaveDirectory() async {
    try {
      final dir = await getMediaSaveDirectory();
      if (mounted) {
        setState(() {
          _saveDirPath = dir.path;
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mediaCtrl = context.watch<MediaTransferController>();
    final syncCtrl = context.watch<SyncController>();

    final pairedDevices = syncCtrl.devices.where((d) => d.trusted).toList();
    if (_selectedDevice == null && pairedDevices.isNotEmpty) {
      _selectedDevice = pairedDevices.first;
    }

    final activeTransfers = mediaCtrl.transfers
        .where((t) => t.status == MediaTransferStatus.transferring)
        .toList();
    final completedTransfers = mediaCtrl.transfers
        .where((t) => t.status != MediaTransferStatus.transferring)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.swap_horizontal_circle_outlined, size: 24),
            SizedBox(width: 10),
            Text('Media Sharing'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.folder_open),
            tooltip: 'Open Saved Media Folder',
            onPressed: () => mediaCtrl.openMediaFolder(),
          ),
          if (completedTransfers.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.cleaning_services_outlined),
              tooltip: 'Clear History',
              onPressed: () {
                mediaCtrl.clearHistory();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Transfer history cleared'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              // 1. Destination Device Target Card
              _buildTargetDeviceCard(context, mediaCtrl, syncCtrl, pairedDevices),
              const SizedBox(height: 16),

              // 2. Storage Location Banner
              _buildStorageBanner(context, mediaCtrl),
              const SizedBox(height: 20),

              // 3. Active Transfers
              if (activeTransfers.isNotEmpty) ...[
                Row(
                  children: [
                    const Icon(Icons.sync, size: 18, color: Colors.blue),
                    const SizedBox(width: 8),
                    Text(
                      'Active Transfers (${activeTransfers.length})',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...activeTransfers.map((item) => _buildTransferItemCard(context, mediaCtrl, item)),
                const SizedBox(height: 20),
              ],

              // 4. Transfer History
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Transfer History (${completedTransfers.length})',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (completedTransfers.isNotEmpty)
                    TextButton.icon(
                      icon: const Icon(Icons.clear_all, size: 16),
                      label: const Text('Clear Finished'),
                      onPressed: () => mediaCtrl.clearHistory(),
                    ),
                ],
              ),
              const SizedBox(height: 8),

              if (completedTransfers.isEmpty && activeTransfers.isEmpty)
                _buildEmptyState(context, pairedDevices.isNotEmpty)
              else
                ...completedTransfers.map((item) => _buildTransferItemCard(context, mediaCtrl, item)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTargetDeviceCard(
    BuildContext context,
    MediaTransferController mediaCtrl,
    SyncController syncCtrl,
    List<Device> pairedDevices,
  ) {
    final theme = Theme.of(context);

    if (pairedDevices.isEmpty) {
      return Card(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const Icon(Icons.devices, size: 40, color: Colors.grey),
              const SizedBox(height: 10),
              const Text(
                'No Paired Devices Found',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 6),
              const Text(
                'Connect your PC or Phone first to send and receive photos, videos, and documents peer-to-peer.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                icon: const Icon(Icons.qr_code_scanner, size: 18),
                label: Text(Platform.isAndroid || Platform.isIOS ? 'Scan PC QR Code' : 'Pair Phone (Show QR Code)'),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const DevicesPage()),
                  );
                },
              ),
            ],
          ),
        ),
      );
    }

    final isSingleDevice = pairedDevices.length == 1;
    final target = _selectedDevice ?? pairedDevices.first;
    final isOnline = target.ipAddress != null && target.ipAddress!.isNotEmpty;

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
                  child: Icon(
                    target.name.toLowerCase().contains('phone') || target.name.toLowerCase().contains('android') || target.name.toLowerCase().contains('pixel') || target.name.toLowerCase().contains('iphone')
                        ? Icons.phone_android
                        : Icons.laptop_chromebook,
                    color: theme.colorScheme.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              target.name,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isOnline ? Colors.green.withValues(alpha: 0.15) : Colors.grey.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: isOnline ? Colors.green : Colors.grey,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isOnline ? 'Online' : 'Offline',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: isOnline ? Colors.green : Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      Text(
                        isOnline ? '${target.ipAddress}:${target.port}' : 'Not connected on current Wi-Fi',
                        style: TextStyle(fontSize: 12, color: theme.colorScheme.outline),
                      ),
                    ],
                  ),
                ),
                if (!isSingleDevice)
                  DropdownButton<Device>(
                    value: target,
                    underline: const SizedBox(),
                    items: pairedDevices.map((d) {
                      return DropdownMenuItem(
                        value: d,
                        child: Text(d.name, style: const TextStyle(fontSize: 13)),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedDevice = val);
                      }
                    },
                  ),
              ],
            ),
            const Divider(height: 24),

            // Send Actions
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  icon: const Icon(Icons.photo_library_outlined, size: 18),
                  label: const Text('Send Photos & Videos'),
                  onPressed: isOnline
                      ? () async {
                          final count = await mediaCtrl.pickAndSendFiles(
                            target,
                            type: FileType.media,
                          );
                          if (count > 0 && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Sending $count media item(s) to ${target.name}...'),
                              ),
                            );
                          }
                        }
                      : null,
                ),
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.upload_file_outlined, size: 18),
                  label: const Text('Send Any File / Document'),
                  onPressed: isOnline
                      ? () async {
                          final count = await mediaCtrl.pickAndSendFiles(
                            target,
                            type: FileType.any,
                          );
                          if (count > 0 && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Sending $count file(s) to ${target.name}...'),
                              ),
                            );
                          }
                        }
                      : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStorageBanner(BuildContext context, MediaTransferController mediaCtrl) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.folder_shared_outlined, size: 20, color: Colors.blueGrey),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Received Files Storage Location:',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
                Text(
                  _saveDirPath.isNotEmpty ? _saveDirPath : 'SyncTask Folder',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => mediaCtrl.openMediaFolder(),
            style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
            child: const Text('Open Folder'),
          ),
        ],
      ),
    );
  }

  Widget _buildTransferItemCard(
    BuildContext context,
    MediaTransferController mediaCtrl,
    MediaTransferItem item,
  ) {
    final theme = Theme.of(context);
    final isOutgoing = item.isOutgoing;
    final isTransferring = item.status == MediaTransferStatus.transferring;
    final isCompleted = item.status == MediaTransferStatus.completed;
    final isFailed = item.status == MediaTransferStatus.failed;

    IconData fileIcon;
    final ext = item.fileName.split('.').last.toLowerCase();
    if (['jpg', 'jpeg', 'png', 'webp', 'gif'].contains(ext)) {
      fileIcon = Icons.image;
    } else if (['mp4', 'mkv', 'mov', 'webm'].contains(ext)) {
      fileIcon = Icons.videocam;
    } else if (['pdf', 'doc', 'docx', 'txt'].contains(ext)) {
      fileIcon = Icons.description;
    } else if (['zip', 'rar', '7z', 'tar', 'gz'].contains(ext)) {
      fileIcon = Icons.folder_zip;
    } else if (['mp3', 'm4a', 'wav', 'aac'].contains(ext)) {
      fileIcon = Icons.music_note;
    } else {
      fileIcon = Icons.insert_drive_file;
    }

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isTransferring
              ? Colors.blue.withValues(alpha: 0.5)
              : (isFailed
                  ? Colors.red.withValues(alpha: 0.3)
                  : theme.colorScheme.outlineVariant.withValues(alpha: 0.3)),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? Colors.green.withValues(alpha: 0.12)
                        : (isFailed
                            ? Colors.red.withValues(alpha: 0.12)
                            : Colors.blue.withValues(alpha: 0.12)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    fileIcon,
                    color: isCompleted
                        ? Colors.green
                        : (isFailed ? Colors.red : Colors.blue),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.fileName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            isOutgoing ? Icons.arrow_upward : Icons.arrow_downward,
                            size: 12,
                            color: isOutgoing ? Colors.indigo : Colors.teal,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isOutgoing ? 'To ${item.receiverName}' : 'From ${item.senderName}',
                            style: TextStyle(fontSize: 11, color: theme.colorScheme.outline),
                          ),
                          const Text(' • ', style: TextStyle(color: Colors.grey)),
                          Text(
                            _formatBytes(item.fileSize),
                            style: TextStyle(fontSize: 11, color: theme.colorScheme.outline),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (isCompleted && item.filePath.isNotEmpty)
                  FilledButton.tonal(
                    onPressed: () => mediaCtrl.openFile(item.filePath),
                    style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
                    child: const Text('Open'),
                  ),
                if (isFailed)
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    tooltip: 'Remove',
                    onPressed: () => mediaCtrl.removeTransfer(item.id),
                  ),
              ],
            ),
            if (isTransferring) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: item.progress > 0 ? item.progress : null,
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_formatBytes(item.bytesTransferred)} of ${_formatBytes(item.fileSize)}',
                    style: const TextStyle(fontSize: 10.5, color: Colors.grey),
                  ),
                  Text(
                    '${(item.progress * 100).toInt()}%',
                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.blue),
                  ),
                ],
              ),
            ],
            if (isFailed && item.errorMessage != null) ...[
              const SizedBox(height: 6),
              Text(
                'Error: ${item.errorMessage}',
                style: const TextStyle(color: Colors.red, fontSize: 11),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool hasPairedDevices) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      alignment: Alignment.center,
      child: Column(
        children: [
          Icon(Icons.swap_horizontal_circle_outlined, size: 48, color: Colors.grey.withValues(alpha: 0.4)),
          const SizedBox(height: 12),
          const Text(
            'No Media Transfers Yet',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 6),
          Text(
            hasPairedDevices
                ? 'Tap "Send Photos & Videos" or "Send Any File" above to share files directly with your paired devices.'
                : 'Pair your PC and phone first to start sharing files and photos peer-to-peer.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: Colors.grey),
          ),
        ],
      ),
    );
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
}
