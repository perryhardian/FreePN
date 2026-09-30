import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_vpn/models/vpn_configuration.dart';
import 'package:local_vpn/models/vpn_status.dart';
import 'package:local_vpn/services/vpn_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('local_vpn/vpn');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test(
    'missing native status integration does not imply disconnection',
    () async {
      messenger.setMockMethodCallHandler(
        channel,
        (_) async => throw MissingPluginException(),
      );
      await expectLater(
        const MethodChannelVpnService().getStatus(),
        throwsA(
          isA<VpnServiceException>().having(
            (error) => error.code,
            'code',
            'VPN_STATUS_UNAVAILABLE',
          ),
        ),
      );
    },
  );

  test('unrecognized native status stays uncertain', () async {
    messenger.setMockMethodCallHandler(channel, (_) async => 'unknown');
    expect(await const MethodChannelVpnService().getStatus(), VpnStatus.error);
  });

  for (final reply in <String?>[
    null,
    '',
    'unexpected',
    'error',
    'connected',
    'disconnecting',
  ]) {
    test('disconnect requires explicit confirmation: $reply', () async {
      messenger.setMockMethodCallHandler(channel, (_) async => reply);
      await expectLater(
        const MethodChannelVpnService().disconnect(),
        throwsA(
          isA<VpnServiceException>().having(
            (error) => error.code,
            'code',
            'TUNNEL_STOP_UNCONFIRMED',
          ),
        ),
      );
    });
  }

  test('disconnect accepts a confirmed stopped tunnel', () async {
    messenger.setMockMethodCallHandler(channel, (_) async => 'disconnected');
    expect(
      await const MethodChannelVpnService().disconnect(),
      VpnStatus.disconnected,
    );
  });

  test(
    'delivers complete runtime config to the existing Android channel',
    () async {
      MethodCall? received;
      messenger.setMockMethodCallHandler(channel, (call) async {
        received = call;
        return 'connected';
      });
      final config = VpnConfiguration.local(
        endpoint: '192.168.1.10:51820',
        privateKey: base64Encode(List.filled(32, 1)),
        serverPublicKey: base64Encode(List.filled(32, 2)),
      );
      expect(
        await const MethodChannelVpnService().connect(config),
        VpnStatus.connected,
      );
      expect(received!.method, 'connect');
      expect(received!.arguments, config.toPlatformArguments());
    },
  );
}
