import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:synctask/data/models/device.dart';
import 'package:synctask/features/sync/discovery/lan_discovery.dart';
import 'package:synctask/features/sync/qr_scan_page.dart';
import 'package:synctask/features/sync/sync_controller.dart';
import 'package:synctask/features/sync/transport/sync_engine.dart';
import 'package:synctask/features/tasks/task_controller.dart';

enum ConnectionMethodType {
  qrScan,
  wifi,
  mobileHotspot,
  bluetoothPan,
  manualIp,
}

class NetworkInterfaceInfo {
  final String ip;
  final String name;
  final ConnectionMethodType type;
  final String label;
  final String description;
  final IconData icon;

  const NetworkInterfaceInfo({
    required this.ip,
    required this.name,
    required this.type,
    required this.label,
    required this.description,
    required this.icon,
  });
}

class DevicesPage extends StatefulWidget {
  const DevicesPage({super.key});

  @override
  State<DevicesPage> createState() => _DevicesPageState();
}

class _DevicesPageState extends State<DevicesPage> {
  List<NetworkInterfaceInfo> _detectedInterfaces = [];

  @override
  void initState() {
    super.initState();
    _refreshNetworkInterfaces();
  }

  Future<void> _refreshNetworkInterfaces() async {
    final interfaces = await _getDetailedNetworkInterfaces();
    if (mounted) {
      setState(() {
        _detectedInterfaces = interfaces;
      });
    }
  }

  static Future<List<NetworkInterfaceInfo>> _getDetailedNetworkInterfaces() async {
    final list = <NetworkInterfaceInfo>[];
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          final ip = addr.address;
          if (addr.isLoopback || ip.startsWith('127.') || ip.startsWith('169.254.')) {
            continue;
          }
          final nameLower = iface.name.toLowerCase();
          ConnectionMethodType type;
          String label;
          String desc;
          IconData icon;

          if (ip.startsWith('192.168.43.') ||
              nameLower.contains('ap0') ||
              nameLower.contains('softap') ||
              nameLower.contains('hotspot')) {
            type = ConnectionMethodType.mobileHotspot;
            label = 'Android Hotspot';
            desc = 'Direct peer-to-peer connection';
            icon = Icons.wifi_tethering;
          } else if (ip.startsWith('192.168.137.') ||
              nameLower.contains('local area connection*')) {
            type = ConnectionMethodType.mobileHotspot;
            label = 'Windows Hotspot';
            desc = 'Direct peer-to-peer connection';
            icon = Icons.wifi_tethering;
          } else if (ip.startsWith('192.168.44.') ||
              nameLower.contains('bt') ||
              nameLower.contains('bluetooth') ||
              nameLower.contains('pan')) {
            type = ConnectionMethodType.bluetoothPan;
            label = 'Bluetooth Link / PAN';
            desc = 'Direct Bluetooth tethering';
            icon = Icons.bluetooth;
          } else if (nameLower.contains('eth')) {
            type = ConnectionMethodType.wifi;
            label = 'Ethernet LAN';
            desc = 'Wired local network';
            icon = Icons.cable;
          } else {
            type = ConnectionMethodType.wifi;
            label = 'Local Wi-Fi';
            desc = 'Home / Office Wi-Fi router';
            icon = Icons.wifi;
          }

          list.add(NetworkInterfaceInfo(
            ip: ip,
            name: iface.name,
            type: type,
            label: label,
            description: desc,
            icon: icon,
          ));
        }
      }
    } catch (_) {}

    // Sort: Mobile Hotspot, Windows Hotspot, Local Wi-Fi, Bluetooth, others
    list.sort((a, b) {
      int score(NetworkInterfaceInfo item) {
        if (item.ip.startsWith('192.168.43.')) return 0;
        if (item.ip.startsWith('192.168.137.')) return 1;
        if (item.ip.startsWith('192.168.44.')) return 2;
        if (item.ip.startsWith('192.168.')) return 3;
        if (item.ip.startsWith('10.')) return 4;
        return 5;
      }
      return score(a).compareTo(score(b));
    });

    return list;
  }

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<SyncController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Devices & Sync'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Networks & Discovery',
            onPressed: () {
              _refreshNetworkInterfaces();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Scanning for nearby devices & networks...'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
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
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 840),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        children: [
          // 1. Local Device Info Card
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



          // 3. Discovered on Wi-Fi Section
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

          // 4. Paired Devices Header
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
                    onPressed: () => _showConnectionHubDialog(
                      context,
                      sync,
                      initialMethod: ConnectionMethodType.manualIp,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),

          if (sync.devices.isEmpty)
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 26),
                child: Column(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.devices,
                        size: 26,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'No Paired Devices',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Connect another phone or PC via Wi-Fi, Mobile Hotspot, or Bluetooth to enable instant direct peer-to-peer sync.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      icon: const Icon(Icons.add_link, size: 18),
                      label: const Text('Pair a Device Now'),
                      onPressed: () => _showConnectionHubDialog(
                        context,
                        sync,
                        initialMethod: ConnectionMethodType.wifi,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ...sync.devices.map(
              (device) => _buildDeviceTile(context, sync, device),
            ),
          const SizedBox(height: 16),

          // Connection Methods Hub (All Different Methods)
          _buildConnectionMethodsSection(context, sync),
        ],
      ),
    ),
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
                        'Device ID: ${sync.localDeviceId.length > 8 ? sync.localDeviceId.substring(0, 8) : sync.localDeviceId}...',
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
            if (_detectedInterfaces.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: _detectedInterfaces.map((iface) {
                  return Chip(
                    avatar: Icon(iface.icon, size: 14),
                    label: Text('${iface.label}: ${iface.ip}', style: const TextStyle(fontSize: 11)),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionMethodsSection(BuildContext context, SyncController sync) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Connection Methods',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Choose how to connect',
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
          ],
        ),
        const SizedBox(height: 10),
        GridView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 420,
            mainAxisExtent: 74,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
          ),
          children: [
            _buildMethodCard(
              context: context,
              icon: Icons.qr_code_scanner,
              iconColor: Colors.deepPurple,
              title: 'Scan QR Code',
              subtitle: 'Multi-network instant auto-pair',
              onTap: () {
                if (Platform.isAndroid || Platform.isIOS) {
                  _openQrScanner(context, sync);
                } else {
                  _showConnectionHubDialog(
                    context,
                    sync,
                    initialMethod: ConnectionMethodType.qrScan,
                  );
                }
              },
            ),
            _buildMethodCard(
              context: context,
              icon: Icons.wifi,
              iconColor: Colors.blue,
              title: 'Local Wi-Fi',
              subtitle: 'Same router auto-discovery',
              onTap: () => _showConnectionHubDialog(
                context,
                sync,
                initialMethod: ConnectionMethodType.wifi,
              ),
            ),
            _buildMethodCard(
              context: context,
              icon: Icons.wifi_tethering,
              iconColor: Colors.teal,
              title: 'Mobile Hotspot',
              subtitle: 'Direct Phone ⇄ PC (No router)',
              onTap: () => _showConnectionHubDialog(
                context,
                sync,
                initialMethod: ConnectionMethodType.mobileHotspot,
              ),
            ),
            _buildMethodCard(
              context: context,
              icon: Icons.bluetooth,
              iconColor: Colors.indigo,
              title: 'Bluetooth Link',
              subtitle: 'Direct Bluetooth PAN sync',
              onTap: () => _showConnectionHubDialog(
                context,
                sync,
                initialMethod: ConnectionMethodType.bluetoothPan,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMethodCard({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 13,
                color: theme.colorScheme.outline.withValues(alpha: 0.5),
              ),
            ],
          ),
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
                onPressed: () => _showConnectionHubDialog(
                  context,
                  sync,
                  initialMethod: ConnectionMethodType.wifi,
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

  Future<void> _openQrScanner(BuildContext context, SyncController sync) async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => const QRScanPage()),
    );

    if (result != null && context.mounted) {
      final primaryIp = result['ip'] as String;
      final port = result['port'] is int
          ? result['port'] as int
          : int.tryParse(result['port'].toString()) ?? 43884;
      final pin = result['pin'] as String;
      final name = result['name'] as String? ?? primaryIp;

      // Candidate IPs: primary IP, followed by multi-network candidate IPs, and Hotspot/Bluetooth gateways
      final candidateIps = <String>[primaryIp];
      if (result['ips'] is List) {
        for (final candidate in result['ips'] as List) {
          final s = candidate.toString();
          if (!candidateIps.contains(s)) {
            candidateIps.add(s);
          }
        }
      }
      if (!candidateIps.contains('192.168.43.1')) candidateIps.add('192.168.43.1');
      if (!candidateIps.contains('192.168.137.1')) candidateIps.add('192.168.137.1');
      if (!candidateIps.contains('192.168.44.1')) candidateIps.add('192.168.44.1');

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
              Expanded(child: Text('Pairing with $name (testing networks)...')),
            ],
          ),
          duration: const Duration(seconds: 15),
        ),
      );

      PairResult? finalRes;
      String? connectedHost;

      for (final host in candidateIps) {
        final res = await sync.pairWithPeer(
          host: host,
          port: port,
          pin: pin,
          timeout: const Duration(milliseconds: 3200),
        );
        if (res.success) {
          finalRes = res;
          connectedHost = host;
          break;
        }
        finalRes = res;
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        if (finalRes != null && finalRes.success) {
          context.read<TaskController>().refresh();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Successfully paired with $name via $connectedHost!'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Pairing failed: ${finalRes?.error ?? "Make sure both devices are on the same Wi-Fi, Mobile Hotspot, or Bluetooth."}'),
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
          width: 310,
          child: SingleChildScrollView(
            child: FutureBuilder<List<NetworkInterfaceInfo>>(
              future: _getDetailedNetworkInterfaces(),
              builder: (context, snapshot) {
                final interfaces = snapshot.data ?? [];
                if (snapshot.connectionState == ConnectionState.waiting && interfaces.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 36),
                    child: Center(
                      child: Text(
                        'Detecting local network interfaces...',
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                    ),
                  );
                }

                if (interfaces.isEmpty) {
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
                        'Please connect this device to your local Wi-Fi network or enable Mobile Hotspot to sync with your other devices.',
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
                  interfaces: interfaces,
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

  void _showConnectionHubDialog(
    BuildContext context,
    SyncController sync, {
    ConnectionMethodType initialMethod = ConnectionMethodType.wifi,
    String? presetIp,
    int? presetPort,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => _ConnectionHubDialog(
        sync: sync,
        initialMethod: initialMethod,
        presetIp: presetIp,
        presetPort: presetPort,
        onScanQrPressed: () {
          Navigator.pop(ctx);
          _openQrScanner(context, sync);
        },
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

class _ConnectionHubDialog extends StatefulWidget {
  final SyncController sync;
  final ConnectionMethodType initialMethod;
  final String? presetIp;
  final int? presetPort;
  final VoidCallback onScanQrPressed;

  const _ConnectionHubDialog({
    required this.sync,
    required this.initialMethod,
    this.presetIp,
    this.presetPort,
    required this.onScanQrPressed,
  });

  @override
  State<_ConnectionHubDialog> createState() => _ConnectionHubDialogState();
}

class _ConnectionHubDialogState extends State<_ConnectionHubDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _ipController = TextEditingController();
  final TextEditingController _portController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();

  @override
  void initState() {
    super.initState();
    int initialIndex = 0;
    switch (widget.initialMethod) {
      case ConnectionMethodType.qrScan:
        initialIndex = 0;
        break;
      case ConnectionMethodType.wifi:
        initialIndex = 1;
        break;
      case ConnectionMethodType.mobileHotspot:
        initialIndex = 2;
        break;
      case ConnectionMethodType.bluetoothPan:
        initialIndex = 3;
        break;
      case ConnectionMethodType.manualIp:
        initialIndex = 4;
        break;
    }

    _tabController = TabController(length: 5, vsync: this, initialIndex: initialIndex);
    _ipController.text = widget.presetIp ?? '';
    _portController.text = (widget.presetPort ?? (widget.sync.engine.actualPort ?? 43884)).toString();

    if (_ipController.text.isEmpty && widget.initialMethod == ConnectionMethodType.mobileHotspot) {
      _ipController.text = '192.168.43.1';
    } else if (_ipController.text.isEmpty && widget.initialMethod == ConnectionMethodType.bluetoothPan) {
      _ipController.text = '192.168.44.1';
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _ipController.dispose();
    _portController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _attemptConnect() async {
    final ip = _ipController.text.trim();
    final port = int.tryParse(_portController.text.trim()) ?? 43884;
    final pin = _pinController.text.trim();

    if (ip.isEmpty || pin.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid IP address and 6-digit confirmation code')),
      );
      return;
    }

    Navigator.pop(context);

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

    final res = await widget.sync.pairWithPeer(
      host: ip,
      port: port,
      pin: pin,
    );

    if (mounted) {
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
            content: Text('Pairing failed: ${res.error ?? "Make sure both devices are on the same network or hotspot."}'),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Pair & Connect Device'),
      contentPadding: const EdgeInsets.only(top: 16, left: 16, right: 16),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelPadding: const EdgeInsets.symmetric(horizontal: 10),
              tabs: const [
                Tab(icon: Icon(Icons.qr_code_scanner, size: 18), text: 'QR Scan'),
                Tab(icon: Icon(Icons.wifi, size: 18), text: 'Local Wi-Fi'),
                Tab(icon: Icon(Icons.wifi_tethering, size: 18), text: 'Hotspot'),
                Tab(icon: Icon(Icons.bluetooth, size: 18), text: 'Bluetooth'),
                Tab(icon: Icon(Icons.settings_ethernet, size: 18), text: 'Manual IP'),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 320,
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: QR Scan
                  _buildQrScanTab(),
                  // Tab 2: Local Wi-Fi
                  _buildWifiTab(),
                  // Tab 3: Mobile Hotspot
                  _buildHotspotTab(),
                  // Tab 4: Bluetooth
                  _buildBluetoothTab(),
                  // Tab 5: Manual IP
                  _buildManualIpTab(),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _attemptConnect,
          child: const Text('Connect & Pair'),
        ),
      ],
    );
  }

  Widget _buildQrScanTab() {
    return SingleChildScrollView(
      child: Column(
        children: [
          const Icon(Icons.qr_code_scanner, size: 48, color: Colors.deepPurple),
          const SizedBox(height: 12),
          const Text(
            'Instant Multi-Network Pairing',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 8),
          const Text(
            'Point camera at the QR code displayed on the other device screen. SyncTask automatically tests all Wi-Fi, Hotspot, and Bluetooth connections.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 18),
          if (Platform.isAndroid || Platform.isIOS)
            FilledButton.icon(
              icon: const Icon(Icons.camera_alt),
              label: const Text('Open QR Scanner Camera'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(42),
              ),
              onPressed: widget.onScanQrPressed,
            )
          else
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Desktop Camera tip: Open SyncTask on your Android phone, tap "Scan QR" and point at the QR code on this PC screen (click "Show Pairing Code" on main screen).',
                style: TextStyle(fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWifiTab() {
    final peers = widget.sync.discoveredPeers;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Connect via Local Wi-Fi Router',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 4),
          const Text(
            'Both devices must be connected to the same Wi-Fi router or office LAN.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          if (peers.isNotEmpty) ...[
            const Text(
              'Discovered Nearby Devices:',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue),
            ),
            const SizedBox(height: 6),
            ...peers.map((p) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.wifi_tethering, color: Colors.blue),
                  title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${p.ipAddress}:${p.port}'),
                  trailing: TextButton(
                    onPressed: () {
                      _ipController.text = p.ipAddress;
                      _portController.text = p.port.toString();
                    },
                    child: const Text('Use IP'),
                  ),
                )),
          ],
          const SizedBox(height: 8),
          _buildInputFields(),
        ],
      ),
    );
  }

  Widget _buildHotspotTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Mobile Hotspot (No Wi-Fi Router Needed)',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 4),
          const Text(
            'Connect directly device-to-device. Turn on Hotspot on one device and connect the other device to it.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 10),
          const Text('Quick Presets:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              ActionChip(
                avatar: const Icon(Icons.phone_android, size: 14),
                label: const Text('Android Hotspot (192.168.43.1)', style: TextStyle(fontSize: 11)),
                onPressed: () => _ipController.text = '192.168.43.1',
              ),
              ActionChip(
                avatar: const Icon(Icons.laptop, size: 14),
                label: const Text('Windows Hotspot (192.168.137.1)', style: TextStyle(fontSize: 11)),
                onPressed: () => _ipController.text = '192.168.137.1',
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildInputFields(),
        ],
      ),
    );
  }

  Widget _buildBluetoothTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Bluetooth Tethering (PAN)',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 4),
          const Text(
            'Sync directly over Bluetooth even when Wi-Fi is disconnected or blocked by router isolation.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              '1. Pair Android & PC via Bluetooth Settings.\n'
              '2. Android: Enable "Bluetooth tethering" in Hotspot settings.\n'
              '3. Windows: Join Personal Area Network (PAN) -> Connect as Access point.\n'
              '4. Default Bluetooth gateway is usually 192.168.44.1.',
              style: TextStyle(fontSize: 11),
            ),
          ),
          const SizedBox(height: 8),
          ActionChip(
            avatar: const Icon(Icons.bluetooth, size: 14),
            label: const Text('Bluetooth Link Gateway (192.168.44.1)', style: TextStyle(fontSize: 11)),
            onPressed: () => _ipController.text = '192.168.44.1',
          ),
          const SizedBox(height: 8),
          _buildInputFields(),
        ],
      ),
    );
  }

  Widget _buildManualIpTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Direct Manual IP & Port',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 4),
          const Text(
            'Enter target IP address for custom LAN subnets, static IPs, or VPNs (Tailscale, WireGuard).',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          _buildInputFields(),
        ],
      ),
    );
  }

  Widget _buildInputFields() {
    return Column(
      children: [
        TextField(
          controller: _ipController,
          decoration: const InputDecoration(
            labelText: 'Target IP Address',
            hintText: 'e.g. 192.168.1.100',
            isDense: true,
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: TextField(
                controller: _portController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Port',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 3,
              child: TextField(
                controller: _pinController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(
                  labelText: '6-digit PIN',
                  hintText: 'PIN from peer',
                  isDense: true,
                  counterText: '',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PairingCodeContent extends StatefulWidget {
  final List<NetworkInterfaceInfo> interfaces;
  final int port;
  final String pin;
  final String deviceName;
  final String deviceId;

  const _PairingCodeContent({
    required this.interfaces,
    required this.port,
    required this.pin,
    required this.deviceName,
    required this.deviceId,
  });

  @override
  State<_PairingCodeContent> createState() => _PairingCodeContentState();
}

class _PairingCodeContentState extends State<_PairingCodeContent> {
  late NetworkInterfaceInfo _selectedInterface;

  @override
  void initState() {
    super.initState();
    _selectedInterface = widget.interfaces.first;
  }

  @override
  Widget build(BuildContext context) {
    final allIps = widget.interfaces.map((i) => i.ip).toList();

    final qrPayload = jsonEncode({
      'type': 'synctask_pair',
      'ip': _selectedInterface.ip,
      'ips': allIps,
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
        const SizedBox(height: 12),
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
        const SizedBox(height: 12),
        const Text(
          'Or enter this 6-digit PIN manually:',
          style: TextStyle(fontSize: 12, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                widget.pin,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 6,
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.copy, size: 20),
              tooltip: 'Copy PIN',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: widget.pin));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('PIN copied to clipboard'), duration: Duration(seconds: 2)),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (widget.interfaces.length > 1) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: DropdownButton<NetworkInterfaceInfo>(
              isDense: true,
              value: _selectedInterface,
              items: widget.interfaces.map((iface) {
                return DropdownMenuItem(
                  value: iface,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(iface.icon, size: 14),
                      const SizedBox(width: 6),
                      Text('${iface.label}: ${iface.ip}', style: const TextStyle(fontSize: 11)),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _selectedInterface = val);
                }
              },
            ),
          ),
        ] else
          Text(
            'Device IP: ${_selectedInterface.ip} : ${widget.port}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        const SizedBox(height: 4),
        const Text(
          'Code valid for 5 min • Works over Wi-Fi, Hotspot & Bluetooth',
          style: TextStyle(fontSize: 11, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
