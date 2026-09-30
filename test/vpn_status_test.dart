import 'package:flutter_test/flutter_test.dart';
import 'package:local_vpn/models/vpn_status.dart';

void main() {
  test('parses platform VPN states', () {
    expect(VpnStatus.fromPlatformValue('connected'), VpnStatus.connected);
    expect(VpnStatus.fromPlatformValue('CONNECTING'), VpnStatus.connecting);
    expect(
      VpnStatus.fromPlatformValue(' disconnected '),
      VpnStatus.disconnected,
    );
    expect(VpnStatus.fromPlatformValue(null), VpnStatus.error);
    expect(VpnStatus.fromPlatformValue('unknown'), VpnStatus.error);
  });
}
