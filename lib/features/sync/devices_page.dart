import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:synctask/data/models/device.dart';
import 'package:synctask/features/sync/discovery/lan_discovery.dart';
import 'package:synctask/features/sync/qr_scan_page.dart';
import 'package:synctask/features/sync/sync_controller.dart';
import 'package:synctask/features/tasks/task_controller.dart';

class DevicesPage extends StatelessWidget {
  const DevicesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<SyncController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Devices & Sync'),
        actions: [
          if (sync.isSyncing)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.sync),
              tooltip: 'Sync All Devices',
              onPressed: sync.devices.isEmpty
                  ? null
                  : () async {
                      await sync.syncAll();
                      if (context.mounted) {
                        context.read<TaskController>().refresh();
                      }
                    },
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Local Device Info Card
          _buildLocalDeviceCard(context, sync),
          const SizedBox(height: 16),

          // Status Banner if any
          if (sync.statusMessage != null)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 20,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      sync.statusMessage!,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),

          // Discovered on Wi-Fi Section
          if (sync.discoveredPeers.isNotEmpty) ...[
            Text(
              'Discovered on Local Wi-Fi',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
            const SizedBox(height: 8),
            ...sync.discoveredPeers.map(
              (peer) => _buildDiscoveredPeerTile(context, sync, peer),
            ),
            const SizedBox(height: 16),
          ],

          // Paired Devices Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Paired Devices (${sync.devices.length})',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (Platform.isAndroid || Platform.isIOS)
                    FilledButton.tonalIcon(
                      icon: const Icon(Icons.qr_code_scanner, size: 18),
                      label: const Text('Scan QR'),
                      onPressed: () => _openQrScanner(context, sync),
                    ),
                  const SizedBox(width: 6),
                  TextButton.icon(
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Pair Manually'),
                    onPressed: () => _showPairDialog(context, sync),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),

          if (sync.devices.isEmpty)
            Card(
              elevation: 0,
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              child: const Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(Icons.devices, size: 48, color: Colors.grey),
                    SizedBox(height: 12),
                    Text(
                      'No Paired Devices',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Connect another phone or PC on the same Wi-Fi network to enable direct peer-to-peer sync.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            )
          else
            ...sync.devices.map(
              (device) => _buildDeviceTile(context, sync, device),
            ),
        ],
      ),
    );
  }

  Widget _buildLocalDeviceCard(BuildContext context, SyncController sync) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.35),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  child: const Icon(Icons.laptop_chromebook, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sync.localDeviceName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Device ID: ${sync.localDeviceId.substring(0, 8)}...',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit, size: 20),
                  tooltip: 'Rename Device',
                  onPressed: () => _showRenameDialog(context, sync),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.wifi, size: 18, color: Colors.green),
                    SizedBox(width: 6),
                    Text(
                      'Local Wi-Fi Sync Active',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                FilledButton.tonal(
                  onPressed: () => _showPairingCodeModal(context, sync),
                  child: const Text('Show Pairing Code'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiscoveredPeerTile(
    BuildContext context,
    SyncController sync,
    DiscoveredPeer peer,
  ) {
    final isAlreadyPaired = sync.devices.any((d) => d.id == peer.id);

    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: ListTile(
        leading: const Icon(Icons.wifi_tethering, color: Colors.blue),
        title: Text(peer.name),
        subtitle: Text('${peer.ipAddress}:${peer.port}'),
        trailing: isAlreadyPaired
            ? const Chip(
                label: Text('Paired', style: TextStyle(fontSize: 11)),
                padding: EdgeInsets.zero,
              )
            : FilledButton.tonal(
                onPressed: () => _showPairDialog(
                  context,
                  sync,
                  presetIp: peer.ipAddress,
                  presetPort: peer.port,
                ),
                child: const Text('Pair'),
              ),
      ),
    );
  }

  Widget _buildDeviceTile(
    BuildContext context,
    SyncController sync,
    Device device,
  ) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outlineVariant,
          width: 0.8,
        ),
      ),
      child: ListTile(
        leading: Icon(
          device.name.toLowerCase().contains('phone') ||
                  device.name.toLowerCase().contains('android')
              ? Icons.phone_android
              : Icons.computer,
          color: device.trusted ? Theme.of(context).colorScheme.primary : Colors.grey,
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                device.name,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  decoration: device.trusted ? null : TextDecoration.lineThrough,
                ),
              ),
            ),
            if (!device.trusted)
              const Chip(
                label: Text('Revoked', style: TextStyle(fontSize: 10, color: Colors.red)),
                padding: EdgeInsets.zero,
                backgroundColor: Color(0xFFFFEBEE),
              ),
          ],
        ),
        subtitle: Text(
          device.ipAddress != null
              ? '${device.ipAddress}:${device.port}'
              : 'Address unknown (will discover on LAN)',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (device.trusted && device.ipAddress != null)
              IconButton(
                icon: const Icon(Icons.sync),
                tooltip: 'Sync with ${device.name}',
                onPressed: () async {
                  await sync.syncDevice(device);
                  if (context.mounted) {
                    context.read<TaskController>().refresh();
                  }
                },
              ),
            PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'toggle_trust') {
                  await sync.setDeviceTrust(device.id, !device.trusted);
                } else if (value == 'delete') {
                  await sync.removeDevice(device.id);
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'toggle_trust',
                  child: Text(device.trusted ? 'Revoke Trust' : 'Enable Trust'),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('Remove Device', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static List<String>? _cachedIps;

  static Future<List<String>> _getLocalIps() async {
    if (_cachedIps != null && _cachedIps!.isNotEmpty) {
      return _cachedIps!;
    }
    final validIps = <String>[];
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );
      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          final ip = addr.address;
          if (addr.isLoopback || ip.startsWith('127.') || ip.startsWith('169.254.')) {
            continue;
          }
          if (!validIps.contains(ip)) {
            validIps.add(ip);
          }
        }
      }
    } catch (_) {}

    // Sort to prioritize common Wi-Fi / LAN subnets:
    // 192.168.x.x -> highest priority (home/office Wi-Fi)
    // 10.x.x.x -> next priority
    // 172.16-31.x.x -> next
    validIps.sort((a, b) {
      int score(String ip) {
        if (ip.startsWith('192.168.')) return 0;
        if (ip.startsWith('10.')) return 1;
        if (ip.startsWith('172.')) {
          final parts = ip.split('.');
          if (parts.length > 1) {
            final second = int.tryParse(parts[1]) ?? 0;
            if (second >= 16 && second <= 31) return 2;
          }
          return 3;
        }
        return 4;
      }
      return score(a).compareTo(score(b));
    });

    _cachedIps = validIps;
    return validIps;
  }

  Future<void> _openQrScanner(BuildContext context, SyncController sync) async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => const QRScanPage()),
    );

    if (result != null && context.mounted) {
      final ip = result['ip'] as String;
      final port = result['port'] is int ? result['port'] as int : int.tryParse(result['port'].toString()) ?? 43884;
      final pin = result['pin'] as String;
      final name = result['name'] as String? ?? ip;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text('Pairing with $name ($ip:$port)...')),
            ],
          ),
          duration: const Duration(seconds: 12),
        ),
      );

      final res = await sync.pairWithPeer(
        host: ip,
        port: port,
        pin: pin,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        if (res.success) {
          context.read<TaskController>().refresh();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Successfully paired with $name!'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Pairing failed: ${res.error ?? "Make sure both devices are on the same Wi-Fi and port $port is open."}'),
              backgroundColor: Colors.redAccent,
              duration: const Duration(seconds: 6),
            ),
          );
        }
      }
    }
  }

  void _showPairingCodeModal(BuildContext context, SyncController sync) {
    final pin = sync.startPairingMode();
    final port = sync.engine.actualPort ?? 43884;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pairing Confirmation Code'),
        content: SizedBox(
          width: 290,
          child: SingleChildScrollView(
            child: FutureBuilder<List<String>>(
              future: _getLocalIps(),
              initialData: _cachedIps,
              builder: (context, snapshot) {
                final ips = snapshot.data ?? [];
                if (snapshot.connectionState == ConnectionState.waiting && ips.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 36),
                    child: Center(
                      child: Text(
                        'Detecting local Wi-Fi address...',
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                    ),
                  );
                }

                if (ips.isEmpty) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.wifi_off, size: 48, color: Colors.orange),
                      const SizedBox(height: 12),
                      const Text(
                        'No Wi-Fi Network Detected',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Please connect this device to your local Wi-Fi network to enable direct sync with your other devices.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          pin,
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 6,
                          ),
                        ),
                      ),
                    ],
                  );
                }

                return _PairingCodeContent(
                  ips: ips,
                  port: port,
                  pin: pin,
                  deviceName: sync.localDeviceName,
                  deviceId: sync.localDeviceId,
                );
              },
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              sync.cancelPairingMode();
              Navigator.pop(ctx);
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Future<void> _showPairDialog(
    BuildContext context,
    SyncController sync, {
    String? presetIp,
    int? presetPort,
  }) async {
    String defaultIp = presetIp ?? '';
    if (defaultIp.isEmpty) {
      final ips = await _getLocalIps();
      if (ips.isNotEmpty) {
        final parts = ips.first.split('.');
        if (parts.length == 4) {
          defaultIp = '${parts[0]}.${parts[1]}.${parts[2]}.';
        }
      }
    }
    if (!context.mounted) return;

    final ipController = TextEditingController(text: defaultIp);
    final portController = TextEditingController(text: (presetPort ?? (sync.engine.actualPort ?? 43884)).toString());
    final pinController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pair New Device'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (Platform.isAndroid || Platform.isIOS) ...[
                FilledButton.icon(
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Scan QR Code with Camera'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(42),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _openQrScanner(context, sync);
                  },
                ),
                const SizedBox(height: 12),
                const Row(
                  children: [
                    Expanded(child: Divider()),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text('OR ENTER MANUALLY', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    ),
                    Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: ipController,
                decoration: const InputDecoration(
                  labelText: 'Peer IP Address',
                  hintText: 'e.g. 192.168.1.100',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: portController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Port',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: pinController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(
                  labelText: '6-digit Pairing Code',
                  hintText: 'Code shown on other device',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final ip = ipController.text.trim();
              final port = int.tryParse(portController.text.trim()) ?? 43884;
              final pin = pinController.text.trim();

              if (ip.isEmpty || pin.length != 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter valid IP and 6-digit PIN')),
                );
                return;
              }

              Navigator.pop(ctx);

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text('Connecting to $ip:$port...')),
                    ],
                  ),
                  duration: const Duration(seconds: 12),
                ),
              );

              final res = await sync.pairWithPeer(
                host: ip,
                port: port,
                pin: pin,
              );

              if (context.mounted) {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                if (res.success) {
                  context.read<TaskController>().refresh();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Successfully paired with ${res.device?.name}!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Pairing failed: ${res.error ?? "Make sure both devices are on the same Wi-Fi."}'),
                      backgroundColor: Colors.redAccent,
                      duration: const Duration(seconds: 6),
                    ),
                  );
                }
              }
            },
            child: const Text('Connect & Pair'),
          ),
        ],
      ),
    );
  }

  void _showRenameDialog(BuildContext context, SyncController sync) {
    final controller = TextEditingController(text: sync.localDeviceName);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Local Device'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Device Name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              sync.updateLocalDeviceName(controller.text);
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class _PairingCodeContent extends StatefulWidget {
  final List<String> ips;
  final int port;
  final String pin;
  final String deviceName;
  final String deviceId;

  const _PairingCodeContent({
    required this.ips,
    required this.port,
    required this.pin,
    required this.deviceName,
    required this.deviceId,
  });

  @override
  State<_PairingCodeContent> createState() => _PairingCodeContentState();
}

class _PairingCodeContentState extends State<_PairingCodeContent> {
  late String _selectedIp;

  @override
  void initState() {
    super.initState();
    _selectedIp = widget.ips.first;
  }

  @override
  Widget build(BuildContext context) {
    final qrPayload = jsonEncode({
      'type': 'synctask_pair',
      'ip': _selectedIp,
      'port': widget.port,
      'pin': widget.pin,
      'name': widget.deviceName,
      'id': widget.deviceId,
    });

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Scan with SyncTask on mobile to pair instantly:',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: SizedBox(
            width: 170,
            height: 170,
            child: QrImageView(
              data: qrPayload,
              version: QrVersions.auto,
              padding: EdgeInsets.zero,
            ),
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'Or enter this 6-digit PIN manually:',
          style: TextStyle(fontSize: 12, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            widget.pin,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              letterSpacing: 6,
            ),
          ),
        ),
        const SizedBox(height: 10),
        if (widget.ips.length > 1) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: DropdownButton<String>(
              isDense: true,
              value: _selectedIp,
              items: widget.ips.map((ip) {
                return DropdownMenuItem(
                  value: ip,
                  child: Text(
                    'IP: $ip',
                    style: const TextStyle(fontSize: 12),
                  ),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _selectedIp = val);
                }
              },
            ),
          ),
        ] else
          Text(
            'Device IP: $_selectedIp : ${widget.port}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        const SizedBox(height: 4),
        const Text(
          'Code valid for 5 min • Both devices must be on same Wi-Fi',
          style: TextStyle(fontSize: 11, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
