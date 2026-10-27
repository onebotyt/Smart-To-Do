import 'dart:async';
import 'dart:convert';
import 'dart:io';

class DiscoveredPeer {
  final String id;
  final String name;
  final String ipAddress;
  final int port;
  final DateTime lastSeen;
  final String? platform;
  final bool hasGpu;

  const DiscoveredPeer({
    required this.id,
    required this.name,
    required this.ipAddress,
    required this.port,
    required this.lastSeen,
    this.platform,
    this.hasGpu = false,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiscoveredPeer &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          ipAddress == other.ipAddress &&
          port == other.port;

  @override
  int get hashCode => id.hashCode ^ ipAddress.hashCode ^ port.hashCode;
}

/// Discovers other SyncTask devices on the same local Wi-Fi / subnet using UDP broadcast.
class LanDiscovery {
  static const int defaultDiscoveryPort = 43884;
  static const String protocolTag = 'synctask_discovery_v1';

  final int port;
  RawDatagramSocket? _socket;
  Timer? _beaconTimer;
  Timer? _pruneTimer;

  String? _localDeviceId;
  String? _localDeviceName;
  int _localTcpPort = 43884;

  final Map<String, DiscoveredPeer> _peers = {};
  final StreamController<List<DiscoveredPeer>> _peersController =
      StreamController<List<DiscoveredPeer>>.broadcast();

  LanDiscovery({this.port = defaultDiscoveryPort});

  Stream<List<DiscoveredPeer>> get peersStream => _peersController.stream;
  List<DiscoveredPeer> get activePeers => _peers.values.toList();

  /// Start broadcasting presence and listening for peers.
  Future<void> start({
    required String localDeviceId,
    required String localDeviceName,
    int localTcpPort = 43884,
  }) async {
    _localDeviceId = localDeviceId;
    _localDeviceName = localDeviceName;
    _localTcpPort = localTcpPort;

    try {
      _socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        port,
        reuseAddress: true,
        reusePort: false,
      );
      _socket?.broadcastEnabled = true;
      _socket?.listen(_handleDatagram, onError: (e) {
        // Log without sensitive data
      });

      // Broadcast immediately, then every 5 seconds
      broadcastBeacon();
      _beaconTimer?.cancel();
      _beaconTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        broadcastBeacon();
      });

      // Prune inactive peers older than 20 seconds every 5 seconds
      _pruneTimer?.cancel();
      _pruneTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        _pruneOldPeers();
      });
    } catch (_) {
      // If UDP bind fails (e.g. port already used by another instance on desktop),
      // we gracefully handle discovery failure while allowing direct TCP sync.
    }
  }

  /// Broadcast presence beacon to local network.
  void broadcastBeacon() {
    if (_socket == null || _localDeviceId == null) return;

    try {
      final payload = jsonEncode({
        'proto': protocolTag,
        'id': _localDeviceId,
        'name': _localDeviceName,
        'tcp_port': _localTcpPort,
        'ts': DateTime.now().millisecondsSinceEpoch,
        'platform': Platform.operatingSystem,
        'has_gpu': Platform.isWindows,
      });

      final bytes = utf8.encode(payload);
      _socket?.send(bytes, InternetAddress('255.255.255.255'), port);
    } catch (_) {
      // Ignore broadcast send errors (e.g. network disconnected)
    }
  }

  void _handleDatagram(RawSocketEvent event) {
    if (event != RawSocketEvent.read || _socket == null) return;

    final datagram = _socket!.receive();
    if (datagram == null) return;

    try {
      final jsonStr = utf8.decode(datagram.data);
      final map = jsonDecode(jsonStr);

      if (map is Map<String, dynamic> && map['proto'] == protocolTag) {
        final peerId = map['id'] as String?;
        final peerName = map['name'] as String? ?? 'SyncTask Device';
        final peerPort = (map['tcp_port'] as int?) ?? 43884;
        final peerPlatform = map['platform'] as String?;
        final peerHasGpu = (map['has_gpu'] as bool?) ?? (peerPlatform == 'windows');

        // Ignore our own beacon
        if (peerId == null || peerId == _localDeviceId) return;

        final peer = DiscoveredPeer(
          id: peerId,
          name: peerName,
          ipAddress: datagram.address.address,
          port: peerPort,
          lastSeen: DateTime.now(),
          platform: peerPlatform,
          hasGpu: peerHasGpu,
        );

        _peers[peerId] = peer;
        _peersController.add(_peers.values.toList());
      }
    } catch (_) {
      // Discard malformed packets
    }
  }

  void _pruneOldPeers() {
    final now = DateTime.now();
    final expired = <String>[];

    for (final entry in _peers.entries) {
      if (now.difference(entry.value.lastSeen).inSeconds > 20) {
        expired.add(entry.key);
      }
    }

    if (expired.isNotEmpty) {
      for (final id in expired) {
        _peers.remove(id);
      }
      _peersController.add(_peers.values.toList());
    }
  }

  /// Stop listening and broadcasting.
  Future<void> stop() async {
    _beaconTimer?.cancel();
    _beaconTimer = null;
    _pruneTimer?.cancel();
    _pruneTimer = null;
    _socket?.close();
    _socket = null;
    _peers.clear();
  }

  void dispose() {
    stop();
    _peersController.close();
  }
}
