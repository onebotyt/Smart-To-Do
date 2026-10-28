import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:provider/provider.dart';
import 'package:synctask/data/models/device.dart';
import 'package:synctask/features/media_transfer/media_storage_helper.dart';
import 'package:synctask/features/media_transfer/media_transfer_controller.dart';
import 'package:synctask/features/media_transfer/models/media_transfer.dart';
import 'package:synctask/features/sync/devices_page.dart';
import 'package:synctask/features/sync/sync_controller.dart';
import 'package:synctask/platform/native_media_service.dart';
import 'package:synctask/platform/window_service.dart';
import 'package:synctask/features/sync/qr_scan_page.dart';
import 'package:synctask/features/media_transfer/widgets/quick_share_receive_dialog.dart';
import 'package:synctask/features/media_transfer/widgets/bulk_send_sheet.dart';

/// Dedicated page for Direct Device-to-Device P2P Media & File Sharing
/// (Quick Share / AirDrop style over local Wi-Fi, Hotspot, and Bluetooth).
class MediaSharingPage extends StatefulWidget {
  final Device? initialTargetDevice;

  const MediaSharingPage({super.key, this.initialTargetDevice});

  @override
  State<MediaSharingPage> createState() => _MediaSharingPageState();
}

class _MediaSharingPageState extends State<MediaSharingPage> with WidgetsBindingObserver {
  Device? _selectedDevice;
  String _saveDirPath = '';
  String? _clipboardImagePath;
  bool _isSelectMode = false;
  final Set<String> _selectedTransferIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _selectedDevice = widget.initialTargetDevice;
    _loadSaveDirectory();
    _checkClipboardImage();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkClipboardImage();
    }
  }

  Future<void> _handleScanAndSend(BuildContext context, MediaTransferController mediaCtrl) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      if (Platform.isWindows) {
        await PlatformWindowService.setAlwaysOnTop(false);
      }

      final picked = await FilePicker.pickFiles(
        type: FileType.any,
      );

      if (picked.isEmpty) return;

      final files = picked
          .map((p) => p.path)
          .whereType<String>()
          .where((p) => File(p).existsSync())
          .map((p) => File(p))
          .toList();

      if (files.isEmpty || !mounted) return;

      final scanResult = await navigator.push<Map<String, dynamic>>(
        MaterialPageRoute(
          builder: (_) => QRScanPage(
            title: 'Scan Receiver QR Code',
            prompt: 'Point camera at the receiver\'s screen to send ${files.length} file(s)',
          ),
        ),
      );

      if (scanResult == null || !mounted) return;

      final host = scanResult['ip'] as String?;
      final port = scanResult['port'] as int? ?? 43884;
      final token = scanResult['token'] as String?;
      final targetName = (scanResult['device_name'] as String?) ?? 'Target Device';

      if (host == null || token == null) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Invalid Quick Share QR code'), backgroundColor: Colors.red),
        );
        return;
      }

      messenger.showSnackBar(
        SnackBar(
          content: Text('⚡ Sending ${files.length} file(s) to $targetName...'),
          duration: const Duration(seconds: 2),
        ),
      );

      final count = await mediaCtrl.sendFilesViaQuickShare(
        host: host,
        port: port,
        token: token,
        targetDeviceName: targetName,
        files: files,
      );

      if (mounted) {
        if (count > 0) {
          messenger.showSnackBar(
            SnackBar(
              content: Text('🎉 Successfully sent $count file(s) to $targetName!'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          messenger.showSnackBar(
            SnackBar(
              content: Text('Failed to transfer files to $targetName. Check network connection.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildQuickShareActionsCard(BuildContext context, MediaTransferController mediaCtrl) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.25),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: theme.colorScheme.primary.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Instant Quick Share (No Pairing)',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Select media & scan the receiver\'s QR code to transfer directly',
                        style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  flex: 5,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                    label: const Text('Scan & Send'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => _handleScanAndSend(context, mediaCtrl),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 5,
                  child: FilledButton.tonalIcon(
                    icon: const Icon(Icons.folder_zip_rounded, size: 18),
                    label: const Text('Bulk Send'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => BulkSendSheet.show(context),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 4,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.qr_code_rounded, size: 18),
                    label: const Text('Receive'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => QuickShareReceiveDialog.show(context),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _checkClipboardImage() async {
    try {
      final imgPath = await NativeMediaService.getClipboardImage();
      if (mounted && imgPath != null && File(imgPath).existsSync()) {
        setState(() {
          _clipboardImagePath = imgPath;
        });
      }
    } catch (_) {}
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

  bool _isImageFile(String path) {
    final ext = path.split('.').last.toLowerCase();
    return ['jpg', 'jpeg', 'png', 'webp', 'gif', 'bmp'].contains(ext);
  }

  bool _isVideoFile(String path) {
    final ext = path.split('.').last.toLowerCase();
    return ['mp4', 'mkv', 'mov', 'webm', 'avi', '3gp'].contains(ext);
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
              // Clipboard Screenshot Quick Share Banner
              if (_clipboardImagePath != null && pairedDevices.isNotEmpty) ...[
                _buildClipboardScreenshotCard(context, mediaCtrl, pairedDevices.first),
                const SizedBox(height: 14),
              ],

              // 0. Instant Quick Share (Unpaired Scan & Send)
              _buildQuickShareActionsCard(context, mediaCtrl),
              const SizedBox(height: 14),

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
                    _isSelectMode
                        ? '${_selectedTransferIds.length} of ${completedTransfers.length} Selected'
                        : 'Transfer History (${completedTransfers.length})',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: _isSelectMode ? const Color(0xFF2563EB) : null,
                    ),
                  ),
                  if (completedTransfers.isNotEmpty)
                    Row(
                      children: [
                        if (_isSelectMode) ...[
                          TextButton(
                            onPressed: () {
                              setState(() {
                                if (_selectedTransferIds.length == completedTransfers.length) {
                                  _selectedTransferIds.clear();
                                } else {
                                  _selectedTransferIds.addAll(completedTransfers.map((t) => t.id));
                                }
                              });
                            },
                            child: Text(
                              _selectedTransferIds.length == completedTransfers.length
                                  ? 'Deselect'
                                  : 'Select All',
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _isSelectMode = false;
                                _selectedTransferIds.clear();
                              });
                            },
                            child: const Text('Done'),
                          ),
                        ] else ...[
                          IconButton(
                            icon: const Icon(Icons.checklist_rounded, size: 20),
                            tooltip: 'Select Multiple',
                            onPressed: () {
                              setState(() {
                                _isSelectMode = true;
                                _selectedTransferIds.clear();
                              });
                            },
                          ),
                          TextButton.icon(
                            icon: const Icon(Icons.clear_all, size: 16),
                            label: const Text('Clear'),
                            onPressed: () => mediaCtrl.clearHistory(),
                          ),
                        ],
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 8),

              if (_isSelectMode && _selectedTransferIds.isNotEmpty) ...[
                Card(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: Row(
                      children: [
                        Text(
                          '${_selectedTransferIds.length} item(s) selected',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const Spacer(),
                        FilledButton.icon(
                          icon: const Icon(Icons.send_rounded, size: 16),
                          label: const Text('Send Selected'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            visualDensity: VisualDensity.compact,
                          ),
                          onPressed: () {
                            final files = completedTransfers
                                .where((t) => _selectedTransferIds.contains(t.id))
                                .map((t) => File(t.filePath))
                                .where((f) => f.existsSync())
                                .toList();
                            if (files.isNotEmpty) {
                              BulkSendSheet.show(context, initialFiles: files);
                            }
                          },
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                          tooltip: 'Delete Selected',
                          onPressed: () {
                            mediaCtrl.removeTransfers(_selectedTransferIds);
                            setState(() {
                              _selectedTransferIds.clear();
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],

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

  Widget _buildClipboardScreenshotCard(
    BuildContext context,
    MediaTransferController mediaCtrl,
    Device targetDevice,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final file = File(_clipboardImagePath!);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF3B82F6).withValues(alpha: 0.5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 50,
              height: 50,
              child: Image.file(
                file,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(Icons.image, size: 28),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.screenshot_monitor, size: 16, color: Color(0xFF2563EB)),
                    SizedBox(width: 5),
                    Text(
                      'Screenshot in Clipboard',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Send directly to ${targetDevice.name}',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.send_rounded, size: 16),
            label: const Text('Send'),
            style: FilledButton.styleFrom(
              visualDensity: VisualDensity.compact,
              backgroundColor: const Color(0xFF2563EB),
            ),
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final ok = await mediaCtrl.sendSingleFile(targetDevice, file);
              if (!mounted) return;
              if (ok) {
                setState(() => _clipboardImagePath = null);
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Screenshot sent to ${targetDevice.name}!'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            tooltip: 'Dismiss',
            onPressed: () => setState(() => _clipboardImagePath = null),
          ),
        ],
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
                  radius: 22,
                  backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12),
                  child: Icon(
                    target.name.toLowerCase().contains('pc') || target.name.toLowerCase().contains('windows')
                        ? Icons.laptop_windows
                        : Icons.smartphone,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isSingleDevice) ...[
                        Row(
                          children: [
                            Text(
                              target.name,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(width: 8),
                            _buildOnlineStatusBadge(isOnline),
                          ],
                        ),
                        if (target.ipAddress != null)
                          Text(
                            '${target.ipAddress}:${target.port}',
                            style: TextStyle(fontSize: 12, color: theme.colorScheme.outline),
                          ),
                      ] else ...[
                        DropdownButtonHideUnderline(
                          child: DropdownButton<Device>(
                            value: target,
                            isExpanded: true,
                            items: pairedDevices.map((d) {
                              return DropdownMenuItem<Device>(
                                value: d,
                                child: Text(d.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                              );
                            }).toList(),
                            onChanged: (newDev) {
                              if (newDev != null) {
                                setState(() => _selectedDevice = newDev);
                              }
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Divider(height: 1),
            const SizedBox(height: 16),

            // Share Action Buttons
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    icon: const Icon(Icons.photo_library_outlined, size: 20),
                    label: const Text('Send Photos & Videos'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: isOnline
                        ? () => mediaCtrl.pickAndSendFiles(target, type: FileType.media)
                        : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    icon: const Icon(Icons.file_present_outlined, size: 20),
                    label: const Text('Send Any File / Document'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: isOnline
                        ? () => mediaCtrl.pickAndSendFiles(target, type: FileType.any)
                        : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOnlineStatusBadge(bool isOnline) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: isOnline
            ? Colors.green.withValues(alpha: 0.15)
            : Colors.grey.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isOnline ? Colors.green.withValues(alpha: 0.5) : Colors.grey,
        ),
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
          const SizedBox(width: 5),
          Text(
            isOnline ? 'Online' : 'Offline',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isOnline ? Colors.green : Colors.grey,
            ),
          ),
        ],
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
    final file = File(item.filePath);
    final fileExists = item.filePath.isNotEmpty && file.existsSync();

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isTransferring
              ? const Color(0xFF3880FF).withValues(alpha: 0.6)
              : (isFailed
                  ? Colors.red.withValues(alpha: 0.4)
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
                if (_isSelectMode) ...[
                  Checkbox(
                    value: _selectedTransferIds.contains(item.id),
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          _selectedTransferIds.add(item.id);
                        } else {
                          _selectedTransferIds.remove(item.id);
                        }
                      });
                    },
                  ),
                  const SizedBox(width: 4),
                ],
                // Real Image / Video / Document Thumbnail
                _buildItemThumbnail(context, item, fileExists, file),
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

                // Share Button (Mobile System App Chooser)
                if (isCompleted && fileExists && Platform.isAndroid)
                  IconButton(
                    icon: const Icon(Icons.share_outlined, size: 20),
                    tooltip: 'Share with Apps',
                    onPressed: () => mediaCtrl.shareTransfer(item),
                  ),

                // Open Button
                if (isCompleted && fileExists)
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
                  backgroundColor: Colors.grey.withValues(alpha: 0.2),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${(item.progress * 100).toInt()}% transferring...',
                    style: const TextStyle(fontSize: 11, color: Colors.blue),
                  ),
                  Text(
                    '${_formatBytes(item.bytesTransferred)} of ${_formatBytes(item.fileSize)}',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ],
            if (isFailed && item.errorMessage != null) ...[
              const SizedBox(height: 6),
              Text(
                item.errorMessage!,
                style: const TextStyle(fontSize: 11, color: Colors.red),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildItemThumbnail(
    BuildContext context,
    MediaTransferItem item,
    bool fileExists,
    File file,
  ) {
    const size = 48.0;

    // Real Image Thumbnail
    if (fileExists && _isImageFile(item.filePath)) {
      return GestureDetector(
        onTap: () => _openLightbox(context, file),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white24, width: 1),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
          ),
          clipBehavior: Clip.antiAlias,
          child: Image.file(
            file,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildFallbackIcon(item),
          ),
        ),
      );
    }

    // Video Thumbnail with Play Badge
    if (fileExists && _isVideoFile(item.filePath)) {
      return GestureDetector(
        onTap: () => OpenFilex.open(file.path),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: const Color(0xFF1E1B4B),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.deepPurpleAccent.withValues(alpha: 0.5)),
          ),
          child: const Stack(
            alignment: Alignment.center,
            children: [
              Icon(Icons.videocam, color: Colors.deepPurpleAccent, size: 28),
              Icon(Icons.play_circle_fill, color: Colors.white, size: 18),
            ],
          ),
        ),
      );
    }

    return _buildFallbackIcon(item);
  }

  Widget _buildFallbackIcon(MediaTransferItem item) {
    const size = 48.0;
    final ext = item.fileName.split('.').last.toLowerCase();
    IconData icon;
    Color color;

    if (_isVideoFile(item.fileName)) {
      icon = Icons.videocam;
      color = Colors.deepPurpleAccent;
    } else if (['pdf', 'doc', 'docx', 'txt'].contains(ext)) {
      icon = Icons.description;
      color = Colors.redAccent;
    } else if (['zip', 'rar', '7z', 'tar', 'gz'].contains(ext)) {
      icon = Icons.folder_zip;
      color = Colors.amber;
    } else if (['mp3', 'm4a', 'wav', 'aac'].contains(ext)) {
      icon = Icons.music_note;
      color = Colors.teal;
    } else {
      icon = Icons.insert_drive_file;
      color = Colors.blue;
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 1),
          Text(
            ext.toUpperCase(),
            style: TextStyle(
              fontSize: 8.5,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  void _openLightbox(BuildContext context, File file) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => Stack(
        children: [
          Center(
            child: InteractiveViewer(
              child: Image.file(file),
            ),
          ),
          Positioned(
            top: 40,
            right: 20,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
              onPressed: () => Navigator.pop(ctx),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool hasPairedDevice) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.swap_horizontal_circle_outlined, size: 48, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            const Text(
              'No Media Transfers Yet',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text(
              hasPairedDevice
                  ? 'Tap "Send Photos & Videos" or "Send Any File" above to share files directly with your paired devices.'
                  : 'Pair your Phone or PC first to transfer photos, videos, and files directly.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}
