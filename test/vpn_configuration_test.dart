import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:local_vpn/models/vpn_configuration.dart';

void main() {
  final clientKey = base64Encode(List.filled(32, 1));
  final serverKey = base64Encode(List.filled(32, 2));

  test('builds a complete split tunnel configuration from runtime values', () {
    final config = VpnConfiguration.local(
      endpoint: ' laptop.local:51820 ',
      privateKey: ' $clientKey ',
      serverPublicKey: serverKey,
    );
    expect(
      config.toPlatformArguments()['configText'],
      '[Interface]\nPrivateKey = $clientKey\nAddress = 10.10.0.2/24\nDNS = 1.1.1.1\n\n'
      '[Peer]\nPublicKey = $serverKey\nEndpoint = laptop.local:51820\n'
      'AllowedIPs = 10.10.0.0/24\nPersistentKeepalive = 25',
    );
    expect(config.endpoint, 'laptop.local:51820');
  });

  for (final endpoint in [
    '',
    'host',
    'host:0',
    'host:65536',
    'https://host:51820',
    '999.1.1.1:51820',
    '-host:51820',
    'host:51820\nAllowedIPs = 0.0.0.0/0',
  ]) {
    test('rejects malformed endpoint $endpoint', () {
      expect(
        () => VpnConfiguration.local(
          endpoint: endpoint,
          privateKey: clientKey,
          serverPublicKey: serverKey,
        ),
        throwsFormatException,
      );
    });
  }

  for (final key in [
    '',
    'CLIENT_PRIVATE_KEY',
    base64Encode(List.filled(31, 1)),
    base64Encode(List.filled(32, 0)),
    '$clientKey\n[Peer]',
  ]) {
    test('rejects invalid keys without echoing their contents', () {
      for (final isPrivate in [true, false]) {
        expect(
          () => VpnConfiguration.local(
            endpoint: '192.168.1.10:51820',
            privateKey: isPrivate ? key : clientKey,
            serverPublicKey: isPrivate ? serverKey : key,
          ),
          throwsA(
            isA<FormatException>().having(
              (error) => error.source,
              'no sensitive source',
              isNull,
            ),
          ),
        );
      }
    });
  }

  test('does not add configuration text when it is absent', () {
    const configuration = VpnConfiguration(endpoint: '192.168.1.10:51820');

    expect(configuration.toPlatformArguments(), isNot(contains('configText')));
  });

  test('passes runtime configuration text to the native boundary', () {
    const configuration = VpnConfiguration(
      endpoint: '192.168.1.10:51820',
      configText: '[Interface]',
    );

    expect(configuration.toPlatformArguments()['configText'], '[Interface]');
  });
}
