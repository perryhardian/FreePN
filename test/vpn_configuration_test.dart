import 'package:flutter_test/flutter_test.dart';
import 'package:local_vpn/models/vpn_configuration.dart';

void main() {
  test('does not add configuration text when it is absent', () {
    const configuration = VpnConfiguration(
      endpoint: '192.168.1.10:51820',
    );

    expect(configuration.toPlatformArguments(), isNot(contains('configText')));
  });

  test('passes runtime configuration text to the native boundary', () {
    const configuration = VpnConfiguration(
      endpoint: '192.168.1.10:51820',
      configText: '[Interface]',
    );

    expect(
      configuration.toPlatformArguments()['configText'],
      '[Interface]',
    );
  });
}
