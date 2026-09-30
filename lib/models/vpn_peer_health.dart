import 'vpn_status.dart';

class VpnPeerHealth {
  const VpnPeerHealth({
    required this.status,
    required this.latestHandshakeEpochMillis,
    required this.localNetworkAvailable,
  });

  final VpnStatus status;
  final int latestHandshakeEpochMillis;
  final bool localNetworkAvailable;

  factory VpnPeerHealth.fromPlatformValue(Map<Object?, Object?> value) {
    final status = VpnStatus.fromPlatformValue(value['status'] as String?);
    final handshake = value['latestHandshakeEpochMillis'];
    final network = value['localNetworkAvailable'];
    if (status == VpnStatus.error || handshake is! int || network is! bool) {
      throw const FormatException('Android returned invalid VPN health data.');
    }
    return VpnPeerHealth(
      status: status,
      latestHandshakeEpochMillis: handshake,
      localNetworkAvailable: network,
    );
  }
}
