import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:synctask/data/models/device.dart';
import 'package:synctask/data/repositories/device_repository.dart';
import 'package:synctask/data/repositories/task_repository.dart';
import 'package:synctask/features/sync/discovery/lan_discovery.dart';
import 'package:synctask/features/sync/transport/sync_engine.dart';

class SyncController extends ChangeNotifier {
  final DeviceRepository _deviceRepo;
  final SyncEngine _engine;
  final LanDiscovery _discovery;

  List<Device> _devices = [];
  List<DiscoveredPeer> _discoveredPeers = [];
  bool _isSyncing = false;
  String? _statusMessage;
  String? _activePairingPin;
  String _localDeviceId = '';
  String _localDeviceName = '';

  StreamSubscription? _discoverySub;

  SyncController({
    required TaskRepository taskRepo,
    required DeviceRepository deviceRepo,
    SyncEngine? engine,
    LanDiscovery? discovery,
  })  : _deviceRepo = deviceRepo,
        _engine = engine ??
            SyncEngine(
              taskRepo: taskRepo,
              deviceRepo: deviceRepo,
            ),
        _discovery = discovery ?? LanDiscovery();

  List<Device> get devices => _devices;
  List<DiscoveredPeer> get discoveredPeers => _discoveredPeers;
  bool get isSyncing => _isSyncing;
  String? get statusMessage => _statusMessage;
  String? get activePairingPin => _activePairingPin;
  String get localDeviceId => _localDeviceId;
  String get localDeviceName => _localDeviceName;
  SyncEngine get engine => _engine;

  Future<void> init() async {
    _localDeviceId = await _deviceRepo.getLocalDeviceId();
    _localDeviceName = await _deviceRepo.getLocalDeviceName();

    await _engine.start();
    await _discovery.start(
      localDeviceId: _localDeviceId,
      localDeviceName: _localDeviceName,
      localTcpPort: _engine.actualPort ?? 43884,
    );

    _discoverySub = _discovery.peersStream.listen((peers) {
      _discoveredPeers = peers;
      notifyListeners();
    });

    await refreshDevices();
  }

  Future<void> refreshDevices() async {
    _devices = await _deviceRepo.getAll();
    notifyListeners();
  }

  String startPairingMode() {
    _activePairingPin = _engine.generatePairingPin();
    notifyListeners();
    return _activePairingPin!;
  }

  void cancelPairingMode() {
    _engine.cancelPairingPin();
    _activePairingPin = null;
    notifyListeners();
  }

  Future<PairResult> pairWithPeer({
    required String host,
    required int port,
    required String pin,
  }) async {
    _isSyncing = true;
    _statusMessage = 'Pairing with $host...';
    notifyListeners();

    try {
      final res = await _engine.pairWithPeer(
        host: host,
        port: port,
        pin: pin,
      );

      if (res.success) {
        _statusMessage = 'Paired with ${res.device?.name ?? "peer"}!';
        await refreshDevices();
        // Immediately sync after pairing
        if (res.device != null) {
          await syncDevice(res.device!);
        }
      } else {
        _statusMessage = 'Pairing failed: ${res.error}';
      }
      return res;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<SyncResult> syncDevice(Device device) async {
    _isSyncing = true;
    _statusMessage = 'Syncing with ${device.name}...';
    notifyListeners();

    try {
      final res = await _engine.syncWithDevice(device);
      if (res.success) {
        _statusMessage =
            'Synced with ${device.name}: sent ${res.changesSent}, received ${res.changesReceived}';
      } else {
        _statusMessage = 'Sync error with ${device.name}: ${res.error}';
      }
      await refreshDevices();
      return res;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<void> syncAll() async {
    final trusted = _devices.where((d) => d.trusted && d.ipAddress != null).toList();
    if (trusted.isEmpty) {
      _statusMessage = 'No trusted devices with known IP to sync';
      notifyListeners();
      return;
    }

    _isSyncing = true;
    notifyListeners();

    int totalSent = 0;
    int totalReceived = 0;
    int successCount = 0;

    for (final dev in trusted) {
      final res = await _engine.syncWithDevice(dev);
      if (res.success) {
        successCount++;
        totalSent += res.changesSent;
        totalReceived += res.changesReceived;
      }
    }

    _statusMessage =
        'Sync completed ($successCount/${trusted.length} peers): $totalSent sent, $totalReceived received';
    _isSyncing = false;
    await refreshDevices();
  }

  Future<void> setDeviceTrust(String deviceId, bool trusted) async {
    await _deviceRepo.setTrust(deviceId, trusted);
    await refreshDevices();
  }

  Future<void> removeDevice(String deviceId) async {
    await _deviceRepo.delete(deviceId);
    await refreshDevices();
  }

  Future<void> updateLocalDeviceName(String name) async {
    if (name.trim().isEmpty) return;
    await _deviceRepo.setLocalDeviceName(name.trim());
    _localDeviceName = name.trim();
    _discovery.broadcastBeacon();
    notifyListeners();
  }

  @override
  void dispose() {
    _discoverySub?.cancel();
    _discovery.dispose();
    _engine.dispose();
    super.dispose();
  }
}
