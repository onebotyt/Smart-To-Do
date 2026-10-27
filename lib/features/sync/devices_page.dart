import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:synctask/data/models/device.dart';
import 'package:synctask/features/settings/widgets/diagnostic_log_sheet.dart';
import 'package:synctask/features/sync/discovery/lan_discovery.dart';
import 'package:synctask/features/sync/qr_scan_page.dart';
import 'package:synctask/features/sync/sync_controller.dart';
import 'package:synctask/features/media_transfer/media_transfer_controller.dart';
import 'package:synctask/features/media_transfer/widgets/media_transfer_widget.dart';
import 'package:synctask/features/sync/transport/sync_engine.dart';
import 'package:synctask/features/tasks/task_controller.dart';
import 'package:synctask/platform/native_network_service.dart';

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
            icon: const Icon(Icons.receipt_long_outlined),
            tooltip: 'Action Logs & GitHub Report',
            onPressed: () => showDiagnosticLogsModal(context),
          ),
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
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
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
                    onPressed: () => _showManualPairDialog(
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
                      onPressed: () => _showPairingCodeModal(
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

          // Direct P2P Media & File Share Section
          const MediaTransferSection(),
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
            Wrap(
              spacing: 8,
              runSpacing: 10,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Row(
                  mainAxisSize: MainAxisSize.min,
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
              subtitle: 'Point camera to pair instantly',
              onTap: () {
                if (Platform.isAndroid || Platform.isIOS) {
                  _openQrScanner(context, sync);
                } else {
                  _showPairingCodeModal(
                    context,
                    sync,
                    initialMethod: ConnectionMethodType.wifi,
                  );
                }
              },
            ),
            _buildMethodCard(
              context: context,
              icon: Icons.wifi,
              iconColor: Colors.blue,
              title: 'Local Wi-Fi',
              subtitle: 'Generate QR for Wi-Fi router sync',
              onTap: () => _showPairingCodeModal(
                context,
                sync,
                initialMethod: ConnectionMethodType.wifi,
              ),
              onSettingsTap: () => NativeNetworkService.openWifiSettings(),
            ),
            _buildMethodCard(
              context: context,
              icon: Icons.wifi_tethering,
              iconColor: Colors.teal,
              title: 'Mobile Hotspot',
              subtitle: 'Generate QR for Hotspot (No router)',
              onTap: () => _showPairingCodeModal(
                context,
                sync,
                initialMethod: ConnectionMethodType.mobileHotspot,
              ),
              onSettingsTap: () => NativeNetworkService.openHotspotSettings(),
            ),
            _buildMethodCard(
              context: context,
              icon: Icons.bluetooth,
              iconColor: Colors.indigo,
              title: 'Bluetooth Link',
              subtitle: 'Generate QR for Bluetooth tethering',
              onTap: () => _showPairingCodeModal(
                context,
                sync,
                initialMethod: ConnectionMethodType.bluetoothPan,
              ),
              onSettingsTap: () => NativeNetworkService.openBluetoothSettings(),
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
    VoidCallback? onSettingsTap,
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
              if (onSettingsTap != null)
                IconButton(
                  icon: const Icon(Icons.settings_outlined, size: 18),
                  tooltip: 'Open System Settings',
                  visualDensity: VisualDensity.compact,
                  onPressed: onSettingsTap,
                )
              else
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
                onPressed: () => _showManualPairDialog(
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
            if (device.trusted && device.ipAddress != null) ...[
              IconButton(
                icon: const Icon(Icons.upload_file),
                tooltip: 'Send File / Media to ${device.name}',
                onPressed: () async {
                  final media = context.read<MediaTransferController>();
                  final count = await media.pickAndSendFiles(device);
                  if (count > 0 && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Sending $count file(s) to ${device.name}...')),
                    );
                  }
                },
              ),
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
            ],
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

  void _showPairingCodeModal(
    BuildContext context,
    SyncController sync, {
    ConnectionMethodType initialMethod = ConnectionMethodType.wifi,
  }) {
    final pin = sync.startPairingMode();
    final port = sync.engine.actualPort ?? 43884;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pairing Confirmation Code'),
        content: SizedBox(
          width: 320,
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
                  initialMethod: initialMethod,
                  onScanQr: () {
                    sync.cancelPairingMode();
                    Navigator.pop(ctx);
                    _openQrScanner(context, sync);
                  },
                  onManualPair: () {
                    sync.cancelPairingMode();
                    Navigator.pop(ctx);
                    _showManualPairDialog(context, sync, initialMethod: initialMethod);
                  },
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

  void _showManualPairDialog(
    BuildContext context,
    SyncController sync, {
    ConnectionMethodType initialMethod = ConnectionMethodType.wifi,
    String? presetIp,
    int? presetPort,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => _ManualPairDialog(
        sync: sync,
        initialMethod: initialMethod,
        presetIp: presetIp,
        presetPort: presetPort,
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
  final List<NetworkInterfaceInfo> interfaces;
  final int port;
  final String pin;
  final String deviceName;
  final String deviceId;
  final ConnectionMethodType initialMethod;
  final VoidCallback onScanQr;
  final VoidCallback onManualPair;

  const _PairingCodeContent({
    required this.interfaces,
    required this.port,
    required this.pin,
    required this.deviceName,
    required this.deviceId,
    this.initialMethod = ConnectionMethodType.wifi,
    required this.onScanQr,
    required this.onManualPair,
  });

  @override
  State<_PairingCodeContent> createState() => _PairingCodeContentState();
}

class _PairingCodeContentState extends State<_PairingCodeContent> {
  late ConnectionMethodType _selectedMethod;
  late String _activeIp;

  @override
  void initState() {
    super.initState();
    _selectedMethod = widget.initialMethod == ConnectionMethodType.qrScan
        ? ConnectionMethodType.wifi
        : widget.initialMethod;
    _updateActiveIp();
  }

  void _updateActiveIp() {
    for (final iface in widget.interfaces) {
      if (_selectedMethod == ConnectionMethodType.wifi) {
        if (iface.type == ConnectionMethodType.wifi ||
            (!iface.ip.startsWith('192.168.43.') &&
             !iface.ip.startsWith('192.168.137.') &&
             !iface.ip.startsWith('192.168.44.'))) {
          _activeIp = iface.ip;
          return;
        }
      } else if (_selectedMethod == ConnectionMethodType.mobileHotspot) {
        if (iface.type == ConnectionMethodType.mobileHotspot ||
            iface.ip.startsWith('192.168.43.') ||
            iface.ip.startsWith('192.168.137.')) {
          _activeIp = iface.ip;
          return;
        }
      } else if (_selectedMethod == ConnectionMethodType.bluetoothPan) {
        if (iface.type == ConnectionMethodType.bluetoothPan ||
            iface.ip.startsWith('192.168.44.')) {
          _activeIp = iface.ip;
          return;
        }
      }
    }

    if (_selectedMethod == ConnectionMethodType.mobileHotspot) {
      _activeIp = '192.168.43.1';
    } else if (_selectedMethod == ConnectionMethodType.bluetoothPan) {
      _activeIp = '192.168.44.1';
    } else {
      _activeIp = widget.interfaces.isNotEmpty ? widget.interfaces.first.ip : '127.0.0.1';
    }
  }

  @override
  Widget build(BuildContext context) {
    final allIps = widget.interfaces.map((i) => i.ip).toList();
    if (!allIps.contains(_activeIp) && _activeIp != '127.0.0.1') {
      allIps.insert(0, _activeIp);
    }

    final qrPayload = jsonEncode({
      'type': 'synctask_pair',
      'method': _selectedMethod.name,
      'ip': _activeIp,
      'ips': allIps,
      'port': widget.port,
      'pin': widget.pin,
      'name': widget.deviceName,
      'id': widget.deviceId,
    });

    String methodDesc;
    IconData methodIcon;
    Color methodColor;

    switch (_selectedMethod) {
      case ConnectionMethodType.wifi:
        methodDesc = 'Both devices must be on the same local Wi-Fi router.';
        methodIcon = Icons.wifi;
        methodColor = Colors.blue;
        break;
      case ConnectionMethodType.mobileHotspot:
        methodDesc = 'One device turns on Hotspot, the other connects to it. Direct link.';
        methodIcon = Icons.wifi_tethering;
        methodColor = Colors.teal;
        break;
      case ConnectionMethodType.bluetoothPan:
        methodDesc = 'Devices paired via Bluetooth with PAN / Bluetooth tethering enabled.';
        methodIcon = Icons.bluetooth;
        methodColor = Colors.indigo;
        break;
      default:
        methodDesc = 'Auto-detect all available networks.';
        methodIcon = Icons.sync_alt;
        methodColor = Colors.deepPurple;
        break;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 1. Connection Method Selector Tabs
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              _buildSegment(ConnectionMethodType.wifi, 'Wi-Fi', Icons.wifi),
              _buildSegment(ConnectionMethodType.mobileHotspot, 'Hotspot', Icons.wifi_tethering),
              _buildSegment(ConnectionMethodType.bluetoothPan, 'Bluetooth', Icons.bluetooth),
            ],
          ),
        ),
        const SizedBox(height: 6),

        // Native System Settings Shortcut Button for selected method
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: OutlinedButton.icon(
            icon: Icon(
              _selectedMethod == ConnectionMethodType.bluetoothPan
                  ? Icons.bluetooth
                  : (_selectedMethod == ConnectionMethodType.mobileHotspot
                      ? Icons.wifi_tethering
                      : Icons.wifi),
              size: 15,
            ),
            label: Text(
              _selectedMethod == ConnectionMethodType.bluetoothPan
                  ? (Platform.isWindows ? 'Open Windows Bluetooth Settings' : 'Turn On / Open Bluetooth Settings')
                  : (_selectedMethod == ConnectionMethodType.mobileHotspot
                      ? (Platform.isWindows ? 'Open Windows Hotspot Settings' : 'Open Hotspot / Tethering Settings')
                      : (Platform.isWindows ? 'Open Windows Wi-Fi Settings' : 'Open Wi-Fi Settings')),
              style: const TextStyle(fontSize: 11),
            ),
            style: OutlinedButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            ),
            onPressed: () {
              if (_selectedMethod == ConnectionMethodType.bluetoothPan) {
                NativeNetworkService.openBluetoothSettings();
              } else if (_selectedMethod == ConnectionMethodType.mobileHotspot) {
                NativeNetworkService.openHotspotSettings();
              } else {
                NativeNetworkService.openWifiSettings();
              }
            },
          ),
        ),
        const SizedBox(height: 8),

        // 2. High-contrast QR Code Container
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

        // 3. 6-digit PIN Confirmation Badge
        const Text(
          'Confirmation PIN:',
          style: TextStyle(fontSize: 12, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
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

        // 4. Method Status Details
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: methodColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: methodColor.withValues(alpha: 0.3)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(methodIcon, size: 14, color: methodColor),
                  const SizedBox(width: 6),
                  Text(
                    '$_activeIp : ${widget.port}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: methodColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                methodDesc,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 10.5, color: Colors.grey),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // 5. Actions: Mobile QR Scan Camera & Manual Pair Link
        if (Platform.isAndroid || Platform.isIOS)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: FilledButton.tonalIcon(
              icon: const Icon(Icons.qr_code_scanner, size: 18),
              label: const Text('Scan QR on Other Device'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(38),
              ),
              onPressed: widget.onScanQr,
            ),
          ),
        TextButton.icon(
          icon: const Icon(Icons.keyboard, size: 16),
          label: const Text('Pair Manually (Enter IP / PIN)', style: TextStyle(fontSize: 12)),
          onPressed: widget.onManualPair,
        ),
      ],
    );
  }

  Widget _buildSegment(ConnectionMethodType method, String label, IconData icon) {
    final isSelected = _selectedMethod == method;
    return Expanded(
      child: GestureDetector(
        onTap: () async {
          setState(() {
            _selectedMethod = method;
            _updateActiveIp();
          });
          if (method == ConnectionMethodType.bluetoothPan && Platform.isAndroid) {
            final isEnabled = await NativeNetworkService.isBluetoothEnabled();
            if (!isEnabled && mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Bluetooth is off. Turn on Bluetooth for Bluetooth PAN pairing.'),
                  action: SnackBarAction(
                    label: 'Turn On',
                    onPressed: () => NativeNetworkService.openBluetoothSettings(),
                  ),
                ),
              );
            }
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14,
                color: isSelected
                    ? Colors.white
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected
                      ? Colors.white
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ManualPairDialog extends StatefulWidget {
  final SyncController sync;
  final ConnectionMethodType initialMethod;
  final String? presetIp;
  final int? presetPort;

  const _ManualPairDialog({
    required this.sync,
    required this.initialMethod,
    this.presetIp,
    this.presetPort,
  });

  @override
  State<_ManualPairDialog> createState() => _ManualPairDialogState();
}

class _ManualPairDialogState extends State<_ManualPairDialog> {
  late ConnectionMethodType _method;
  final TextEditingController _ipController = TextEditingController();
  final TextEditingController _portController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();
  bool _isConnecting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _method = widget.initialMethod == ConnectionMethodType.qrScan
        ? ConnectionMethodType.wifi
        : widget.initialMethod;
    _portController.text = (widget.presetPort ?? (widget.sync.engine.actualPort ?? 43884)).toString();
    _ipController.text = widget.presetIp ?? '';
    _applyMethodDefaults();
  }

  void _applyMethodDefaults() {
    if (_ipController.text.isNotEmpty) return;
    if (_method == ConnectionMethodType.mobileHotspot) {
      _ipController.text = '192.168.43.1';
    } else if (_method == ConnectionMethodType.bluetoothPan) {
      _ipController.text = '192.168.44.1';
    }
  }

  @override
  void dispose() {
    _ipController.dispose();
    _portController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _attemptConnect() async {
    final ip = _ipController.text.trim();
    final port = int.tryParse(_portController.text.trim()) ?? 43884;
    final pin = _pinController.text.trim();

    if (ip.isEmpty) {
      setState(() => _errorMessage = 'Please enter the target device IP address.');
      return;
    }
    if (pin.length != 6) {
      setState(() => _errorMessage = 'Please enter the 6-digit confirmation PIN.');
      return;
    }

    setState(() {
      _isConnecting = true;
      _errorMessage = null;
    });

    final res = await widget.sync.pairWithPeer(
      host: ip,
      port: port,
      pin: pin,
      timeout: const Duration(seconds: 5),
    );

    if (!mounted) return;

    if (res.success) {
      Navigator.pop(context);
      context.read<TaskController>().refresh();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully paired with ${res.device?.name ?? ip}!'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      setState(() {
        _isConnecting = false;
        String hint;
        if (_method == ConnectionMethodType.bluetoothPan) {
          hint = 'Make sure Bluetooth is paired and Bluetooth tethering is enabled in Android Hotspot settings.';
        } else if (_method == ConnectionMethodType.mobileHotspot) {
          hint = 'Make sure this device is connected to the other device’s Mobile Hotspot.';
        } else {
          hint = 'Make sure both devices are on the same Wi-Fi router and SyncTask is open.';
        }
        _errorMessage = 'Could not connect to $ip:$port.\n$hint';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final peers = widget.sync.discoveredPeers;

    return AlertDialog(
      title: const Text('Pair Device Manually'),
      content: SizedBox(
        width: 320,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Discovered Peers List if any
              if (peers.isNotEmpty) ...[
                const Text(
                  'Discovered on Local Network:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue),
                ),
                const SizedBox(height: 6),
                ...peers.map((p) => Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.devices, size: 18, color: Colors.blue),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                Text('${p.ipAddress}:${p.port}', style: const TextStyle(fontSize: 10.5, color: Colors.grey)),
                              ],
                            ),
                          ),
                          FilledButton.tonal(
                            style: FilledButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                            ),
                            onPressed: () {
                              _ipController.text = p.ipAddress;
                              _portController.text = p.port.toString();
                            },
                            child: const Text('Use', style: TextStyle(fontSize: 11)),
                          ),
                        ],
                      ),
                    )),
                const Divider(height: 18),
              ],

              // 2. Method Selector
              Row(
                children: [
                  _buildMethodChip(ConnectionMethodType.wifi, 'Wi-Fi'),
                  const SizedBox(width: 6),
                  _buildMethodChip(ConnectionMethodType.mobileHotspot, 'Hotspot'),
                  const SizedBox(width: 6),
                  _buildMethodChip(ConnectionMethodType.bluetoothPan, 'Bluetooth'),
                ],
              ),
              const SizedBox(height: 12),

              // 3. IP and Port Fields
              TextField(
                controller: _ipController,
                decoration: InputDecoration(
                  labelText: 'Target Device IP',
                  hintText: _method == ConnectionMethodType.mobileHotspot
                      ? '192.168.43.1'
                      : (_method == ConnectionMethodType.bluetoothPan ? '192.168.44.1' : 'e.g. 192.168.1.100'),
                  isDense: true,
                  border: const OutlineInputBorder(),
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

              // Error display if any
              if (_errorMessage != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.redAccent, fontSize: 11),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isConnecting ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isConnecting ? null : _attemptConnect,
          child: _isConnecting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Connect & Pair'),
        ),
      ],
    );
  }

  Widget _buildMethodChip(ConnectionMethodType method, String label) {
    final isSelected = _method == method;
    return Expanded(
      child: ChoiceChip(
        label: Text(label, style: const TextStyle(fontSize: 11)),
        selected: isSelected,
        visualDensity: VisualDensity.compact,
        onSelected: (val) {
          if (val) {
            setState(() {
              _method = method;
              if (method == ConnectionMethodType.mobileHotspot) {
                _ipController.text = '192.168.43.1';
              } else if (method == ConnectionMethodType.bluetoothPan) {
                _ipController.text = '192.168.44.1';
              } else {
                _ipController.text = '';
              }
            });
          }
        },
      ),
    );
  }
}
