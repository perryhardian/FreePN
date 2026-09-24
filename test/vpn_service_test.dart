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
