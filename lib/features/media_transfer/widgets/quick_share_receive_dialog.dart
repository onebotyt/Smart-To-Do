import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:synctask/features/media_transfer/media_transfer_controller.dart';
import 'package:synctask/features/media_transfer/models/media_transfer.dart';
import 'package:synctask/features/sync/sync_controller.dart';

class QuickShareReceiveDialog extends StatefulWidget {
  const QuickShareReceiveDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const QuickShareReceiveDialog(),
    );
  }

  @override
  State<QuickShareReceiveDialog> createState() => _QuickShareReceiveDialogState();
}

class _QuickShareReceiveDialogState extends State<QuickShareReceiveDialog> {
  String? _token;
  String _activeIp = '127.0.0.1';
  int _port = 43884;
  String _deviceName = 'Device';
  bool _isLoading = true;
  StreamSubscription<MediaTransferItem>? _receivedSub;
  MediaTransferItem? _lastReceivedItem;

  @override
  void initState() {
    super.initState();
    _initQuickShare();
  }

  Future<void> _initQuickShare() async {
    final mediaCtrl = context.read<MediaTransferController>();
    final syncCtrl = context.read<SyncController>();

    final token = mediaCtrl.syncEngine.generateQuickShareToken();
    final port = mediaCtrl.syncEngine.port;

    String bestIp = '127.0.0.1';
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          final ip = addr.address;
          if (!addr.isLoopback && !ip.startsWith('127.') && !ip.startsWith('169.254.')) {
            bestIp = ip;
            break;
          }
        }
        if (bestIp != '127.0.0.1') break;
      }
    } catch (_) {}

    final localName = syncCtrl.localDeviceName;

    if (mounted) {
      setState(() {
        _token = token;
        _activeIp = bestIp;
        _port = port;
        _deviceName = localName;
        _isLoading = false;
      });

      _receivedSub = mediaCtrl.onMediaReceived.listen((item) {
        if (mounted) {
          setState(() {
            _lastReceivedItem = item;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _receivedSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mediaCtrl = context.watch<MediaTransferController>();

    final activeInbound = mediaCtrl.transfers.firstWhere(
      (t) => !t.isOutgoing && t.status == MediaTransferStatus.transferring,
      orElse: () => MediaTransferItem(
        id: '',
        fileName: '',
        filePath: '',
        fileSize: 0,
        senderId: '',
        senderName: '',
        receiverId: '',
        receiverName: '',
        isOutgoing: false,
        status: MediaTransferStatus.failed,
      ),
    );
    final hasActive = activeInbound.id.isNotEmpty;

    final qrPayload = jsonEncode({
      'type': 'synctask_quickshare',
      'ip': _activeIp,
      'port': _port,
      'token': _token ?? '',
      'device_name': _deviceName,
    });

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.qr_code_2_rounded, color: Color(0xFF2563EB), size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Ready to Receive Media',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Unpaired Quick Share • Wi-Fi P2P',
                      style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 20),

          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(),
            )
          else ...[
            // QR Code Container
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: QrImageView(
                data: qrPayload,
                version: QrVersions.auto,
                size: 200,
                backgroundColor: Colors.white,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: Color(0xFF1E293B),
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: Color(0xFF1E293B),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Instruction badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.center_focus_weak_rounded, size: 16, color: Color(0xFF2563EB)),
                  const SizedBox(width: 8),
                  Text(
                    'Scan with sender device to instantly transfer',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Listening on $_activeIp : $_port',
              style: TextStyle(fontSize: 11, color: theme.colorScheme.outline),
            ),
            const SizedBox(height: 16),

            // Active Inbound Transfer Live Card
            if (hasActive)
              Card(
                color: const Color(0xFF2563EB).withValues(alpha: 0.08),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Receiving: ${activeInbound.fileName}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '${(activeInbound.progress * 100).toInt()}%',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: activeInbound.progress,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  ),
                ),
              ),

            // Last Completed Transfer Card
            if (_lastReceivedItem != null && !hasActive)
              Card(
                color: Colors.green.withValues(alpha: 0.08),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: ListTile(
                  leading: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 28),
                  title: Text(
                    _lastReceivedItem!.fileName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: const Text('Received successfully!', style: TextStyle(fontSize: 11, color: Colors.green)),
                  trailing: FilledButton.tonal(
                    style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
                    onPressed: () => mediaCtrl.openFile(_lastReceivedItem!.filePath),
                    child: const Text('Open'),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
