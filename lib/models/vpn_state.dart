enum VpnStatus {
  disconnected,
  connecting,
  connected,
  disconnecting,
  error;

  String get label => switch (this) {
    VpnStatus.disconnected  => 'Отключено',
    VpnStatus.connecting    => 'Подключение...',
    VpnStatus.connected     => 'Подключено',
    VpnStatus.disconnecting => 'Отключение...',
    VpnStatus.error         => 'Ошибка',
  };

  static VpnStatus fromString(String s) => switch (s) {
    'connected'     => VpnStatus.connected,
    'connecting'    => VpnStatus.connecting,
    'disconnecting' => VpnStatus.disconnecting,
    _               => VpnStatus.disconnected,
  };
}

class TrafficStats {
  final int rxBytes;
  final int txBytes;

  const TrafficStats({required this.rxBytes, required this.txBytes});
  static const zero = TrafficStats(rxBytes: 0, txBytes: 0);

  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
  }

  String get rxFormatted => formatBytes(rxBytes);
  String get txFormatted => formatBytes(txBytes);
}
