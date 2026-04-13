class ServerConfig {
  final String host;
  final int port;
  final bool isConnected;
  final DateTime? lastChecked;

  const ServerConfig({
    this.host = '10.20.34.38',
    this.port = 8000,
    this.isConnected = false,
    this.lastChecked,
  });

  String get baseUrl => 'http://$host:$port';

  ServerConfig copyWith({
    String? host,
    int? port,
    bool? isConnected,
    DateTime? lastChecked,
  }) {
    return ServerConfig(
      host: host ?? this.host,
      port: port ?? this.port,
      isConnected: isConnected ?? this.isConnected,
      lastChecked: lastChecked ?? this.lastChecked,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'host': host,
      'port': port,
    };
  }

  factory ServerConfig.fromMap(Map<String, dynamic> map) {
    return ServerConfig(
      host: map['host'] as String? ?? '192.168.1.100',
      port: map['port'] as int? ?? 8000,
    );
  }
}
