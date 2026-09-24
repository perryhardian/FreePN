enum VpnStatus {
  disconnected,
  connecting,
  connected,
  disconnecting,
  error;

  String get label => switch (this) {
    VpnStatus.disconnected => 'Disconnected',
    VpnStatus.connecting => 'Connecting',
    VpnStatus.connected => 'Connected',
    VpnStatus.disconnecting => 'Disconnecting',
    VpnStatus.error => 'Error',
  };

  static VpnStatus fromPlatformValue(String? value) {
    return switch (value?.trim().toLowerCase()) {
      'connecting' => VpnStatus.connecting,
      'connected' => VpnStatus.connected,
      'disconnecting' => VpnStatus.disconnecting,
      'error' => VpnStatus.error,
      _ => VpnStatus.disconnected,
    };
  }
}
