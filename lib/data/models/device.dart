class Device {
  final String id;
  final String name;
  final String fingerprint;
  final String? ipAddress;
  final int port;
  final DateTime pairedAt;
  final DateTime? lastSeen;
  final bool trusted;

  const Device({
    required this.id,
    required this.name,
    required this.fingerprint,
    this.ipAddress,
    this.port = 43884,
    required this.pairedAt,
    this.lastSeen,
    this.trusted = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'fingerprint': fingerprint,
      'ip_address': ipAddress,
      'port': port,
      'paired_at': pairedAt.millisecondsSinceEpoch,
      'last_seen': lastSeen?.millisecondsSinceEpoch,
      'trusted': trusted ? 1 : 0,
    };
  }

  factory Device.fromMap(Map<String, dynamic> map) {
    return Device(
      id: map['id'] as String,
      name: map['name'] as String,
      fingerprint: map['fingerprint'] as String,
      ipAddress: map['ip_address'] as String?,
      port: (map['port'] as int?) ?? 43884,
      pairedAt: DateTime.fromMillisecondsSinceEpoch(map['paired_at'] as int),
      lastSeen: map['last_seen'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['last_seen'] as int)
          : null,
      trusted: (map['trusted'] as int? ?? 1) == 1,
    );
  }

  Device copyWith({
    String? id,
    String? name,
    String? fingerprint,
    String? ipAddress,
    int? port,
    DateTime? pairedAt,
    DateTime? lastSeen,
    bool? trusted,
  }) {
    return Device(
      id: id ?? this.id,
      name: name ?? this.name,
      fingerprint: fingerprint ?? this.fingerprint,
      ipAddress: ipAddress ?? this.ipAddress,
      port: port ?? this.port,
      pairedAt: pairedAt ?? this.pairedAt,
      lastSeen: lastSeen ?? this.lastSeen,
      trusted: trusted ?? this.trusted,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Device &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          fingerprint == other.fingerprint &&
          ipAddress == other.ipAddress &&
          port == other.port &&
          pairedAt == other.pairedAt &&
          lastSeen == other.lastSeen &&
          trusted == other.trusted;

  @override
  int get hashCode =>
      id.hashCode ^
      name.hashCode ^
      fingerprint.hashCode ^
      ipAddress.hashCode ^
      port.hashCode ^
      pairedAt.hashCode ^
      lastSeen.hashCode ^
      trusted.hashCode;
}
