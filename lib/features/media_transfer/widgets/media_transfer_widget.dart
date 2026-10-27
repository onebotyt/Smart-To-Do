import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:synctask/data/models/device.dart';
import 'package:synctask/features/media_transfer/media_transfer_controller.dart';
import 'package:synctask/features/media_transfer/models/media_transfer.dart';

class MediaTransferSection extends StatelessWidget {
  final Device? selectedDevice;

  const MediaTransferSection({
    super.key,
    this.selectedDevice,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<MediaTransferController>(
      builder: (context, controller, _) {
        final transfers = controller.transfers;

        return Card(
          elevation: 0,
          margin: const EdgeInsets.symmetric(vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
              width: 0.8,
            ),
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
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.swap_horizontal_circle_outlined,
                        color: Theme.of(context).colorScheme.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Direct P2P Media & File Share',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Quick Share / AirDrop style over local Wi-Fi & Hotspot',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (selectedDevice != null &&
                        selectedDevice!.trusted &&
                        selectedDevice!.ipAddress != null)
                      FilledButton.icon(
                        icon: const Icon(Icons.upload_file, size: 16),
                        label: const Text('Send File'),
                        onPressed: () async {
                          final count = await controller.pickAndSendFiles(selectedDevice!);
                          if (count > 0 && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Sending $count file(s) to ${selectedDevice!.name}...'),
                              ),
                            );
                          }
                        },
                      ),
                  ],
                ),
                if (transfers.isEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        'No media transfers yet. Tap "Send File" on any paired device to share photos, videos, or documents.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Recent Transfers (${transfers.length})',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => controller.clearHistory(),
                        icon: const Icon(Icons.clear_all, size: 16),
                        label: const Text('Clear History', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: transfers.length,
                    separatorBuilder: (_, __) => const Divider(height: 12),
                    itemBuilder: (context, index) {
                      return MediaTransferTile(
                        item: transfers[index],
                        onOpen: () => controller.openFile(transfers[index].filePath),
                        onDismiss: () => controller.removeTransfer(transfers[index].id),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class MediaTransferTile extends StatelessWidget {
  final MediaTransferItem item;
  final VoidCallback onOpen;
  final VoidCallback onDismiss;

  const MediaTransferTile({
    super.key,
    required this.item,
    required this.onOpen,
    required this.onDismiss,
  });

  IconData _getFileIcon(String fileName) {
    final ext = fileName.toLowerCase().split('.').last;
    switch (ext) {
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'webp':
      case 'bmp':
        return Icons.image_outlined;
      case 'mp4':
      case 'mkv':
      case 'mov':
      case 'avi':
      case 'webm':
        return Icons.video_file_outlined;
      case 'mp3':
      case 'wav':
      case 'm4a':
      case 'flac':
      case 'ogg':
        return Icons.audio_file_outlined;
      case 'pdf':
        return Icons.picture_as_pdf_outlined;
      case 'doc':
      case 'docx':
      case 'txt':
        return Icons.description_outlined;
      case 'zip':
      case 'rar':
      case '7z':
      case 'tar':
      case 'gz':
        return Icons.folder_zip_outlined;
      case 'apk':
        return Icons.android;
      default:
        return Icons.insert_drive_file_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOutgoing = item.isOutgoing;
    final isTransferring = item.status == MediaTransferStatus.transferring;
    final isCompleted = item.status == MediaTransferStatus.completed;
    final isFailed = item.status == MediaTransferStatus.failed;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      decoration: BoxDecoration(
        color: isTransferring
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.15)
            : null,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _getFileIcon(item.fileName),
                color: theme.colorScheme.primary,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isOutgoing
                          ? 'To: ${item.receiverName} • ${item.formattedSize}'
                          : 'From: ${item.senderName} • ${item.formattedSize}',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (isCompleted && !isOutgoing && item.filePath.isNotEmpty)
                FilledButton.tonalIcon(
                  onPressed: onOpen,
                  icon: const Icon(Icons.file_open_outlined, size: 16),
                  label: const Text('Open'),
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                )
              else if (isCompleted && isOutgoing)
                const Chip(
                  avatar: Icon(Icons.check_circle, size: 14, color: Colors.green),
                  label: Text('Sent', style: TextStyle(fontSize: 11, color: Colors.green)),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                )
              else if (isFailed)
                Chip(
                  avatar: const Icon(Icons.error_outline, size: 14, color: Colors.red),
                  label: Text(
                    item.errorMessage ?? 'Failed',
                    style: const TextStyle(fontSize: 11, color: Colors.red),
                  ),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                )
              else if (isTransferring)
                Text(
                  '${(item.progress * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              IconButton(
                icon: const Icon(Icons.close, size: 16),
                visualDensity: VisualDensity.compact,
                tooltip: 'Dismiss',
                onPressed: onDismiss,
              ),
            ],
          ),
          if (isTransferring) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: item.progress > 0 ? item.progress : null,
                minHeight: 5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
