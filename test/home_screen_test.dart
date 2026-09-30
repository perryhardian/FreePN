import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_vpn/models/vpn_configuration.dart';
import 'package:local_vpn/models/vpn_peer_health.dart';
import 'package:local_vpn/models/vpn_status.dart';
import 'package:local_vpn/screens/home_screen.dart';
import 'package:local_vpn/services/vpn_service.dart';

void main() {
  for (final throwsException in [true, false]) {
    testWidgets(
      'disconnect recovery after ${throwsException ? 'exception' : 'error status'}',
      (tester) async {
        final service = DisconnectRecoveryService(
          throwsException: throwsException,
        );
        await tester.pumpWidget(
          MaterialApp(home: HomeScreen(vpnService: service)),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 3));
        expect(find.text('00:00:03'), findsOneWidget);

        final disconnect = find.widgetWithText(OutlinedButton, 'Disconnect');
        await tester.ensureVisible(disconnect);
        await tester.tap(disconnect);
        await tester.pump();

        expect(find.text('Error'), findsOneWidget);
        expect(
          find.textContaining('The VPN may still be active. Retry Disconnect.'),
          findsOneWidget,
        );
        expect(tester.widget<OutlinedButton>(disconnect).onPressed, isNotNull);
        expect(
          tester
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Connect'),
              )
              .onPressed,
          isNull,
        );
        expect(
          tester.widget<TextField>(find.byType(TextField)).enabled,
          isFalse,
        );
        expect(
          tester
              .widget<TextButton>(
                find.widgetWithText(TextButton, 'Configure WireGuard keys'),
              )
              .onPressed,
          isNull,
        );
        await tester.pump(const Duration(seconds: 2));
        expect(find.text('00:00:03'), findsOneWidget);

        // A second failure must also leave recovery available.
        await tester.ensureVisible(disconnect);
        await tester.tap(disconnect);
        await tester.pump();
        expect(service.disconnectCalls, 2);
        expect(tester.widget<OutlinedButton>(disconnect).onPressed, isNotNull);

        service.shouldFail = false;
        await tester.ensureVisible(disconnect);
        await tester.tap(disconnect);
        await tester.pump();
        expect(service.disconnectCalls, 3);
        expect(find.text('Disconnected'), findsOneWidget);
        expect(find.text('00:00:00'), findsOneWidget);
        expect(
          find.textContaining('The VPN may still be active.'),
          findsNothing,
        );
        expect(tester.widget<OutlinedButton>(disconnect).onPressed, isNull);
        expect(
          tester
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Connect'),
              )
              .onPressed,
          isNotNull,
        );
        expect(
          tester.widget<TextField>(find.byType(TextField)).enabled,
          isTrue,
        );
        expect(
          tester
              .widget<TextButton>(
                find.widgetWithText(TextButton, 'Configure WireGuard keys'),
              )
              .onPressed,
          isNotNull,
        );
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets('disconnect cannot be submitted again while pending', (
    tester,
  ) async {
    final service = DisconnectRecoveryService(throwsException: true);
    service.pending = Completer<VpnStatus>();
    await tester.pumpWidget(MaterialApp(home: HomeScreen(vpnService: service)));
    await tester.pump();
    final disconnect = find.widgetWithText(OutlinedButton, 'Disconnect');
    await tester.ensureVisible(disconnect);
    await tester.tap(disconnect);
    await tester.pump();
    expect(service.disconnectCalls, 1);
    expect(tester.widget<OutlinedButton>(disconnect).onPressed, isNull);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Connect'))
          .onPressed,
      isNull,
    );
    service.pending!.complete(VpnStatus.disconnected);
    await tester.pump();
    expect(find.text('Disconnected'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('shows the required connection information', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: HomeScreen(vpnService: FakeVpnService())),
    );
    await tester.pump();

    expect(find.text('Local VPN'), findsOneWidget);
    expect(find.text('Disconnected'), findsOneWidget);
    expect(find.text('Server endpoint'), findsOneWidget);
    expect(find.text('VPN IP'), findsOneWidget);
    expect(find.text('Connect'), findsOneWidget);
    expect(find.text('Disconnect'), findsOneWidget);
    expect(find.text('00:00:00'), findsOneWidget);
  });

  testWidgets('connects through the service abstraction', (tester) async {
    final service = FakeVpnService();
    await tester.pumpWidget(MaterialApp(home: HomeScreen(vpnService: service)));
    await tester.pump();

    await tester.enterText(find.byType(TextField), '192.168.1.10:51820');
    await tester.tap(find.text('Configure WireGuard keys'));
    await tester.pumpAndSettle();
    final fields = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );
    expect(tester.widget<TextField>(fields.at(0)).obscureText, isTrue);
    await tester.enterText(fields.at(0), base64Encode(List.filled(32, 1)));
    await tester.enterText(fields.at(1), base64Encode(List.filled(32, 2)));
    await tester.tap(find.text('Use keys'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Connect'));
    await tester.tap(find.widgetWithText(FilledButton, 'Connect'));
    await tester.pump();

    expect(service.connectCalls, 1);
    expect(
      service.configuration!.configText,
      contains('AllowedIPs = 10.10.0.0/24'),
    );
    expect(
      service.configuration!.configText,
      contains('Endpoint = 192.168.1.10:51820'),
    );
    expect(find.text('Connected'), findsOneWidget);

    await tester.ensureVisible(
      find.widgetWithText(OutlinedButton, 'Disconnect'),
    );
    await tester.tap(find.widgetWithText(OutlinedButton, 'Disconnect'));
    await tester.pump();
    expect(find.text('Disconnected'), findsOneWidget);
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Connect'));
    await tester.tap(find.widgetWithText(FilledButton, 'Connect'));
    await tester.pump();
    expect(service.connectCalls, 2);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('missing keys never reach the VPN service', (tester) async {
    final service = FakeVpnService();
    await tester.pumpWidget(MaterialApp(home: HomeScreen(vpnService: service)));
    await tester.pump();
    await tester.enterText(find.byType(TextField), '192.168.1.10:51820');
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Connect'));
    await tester.tap(find.widgetWithText(FilledButton, 'Connect'));
    await tester.pump();
    expect(service.connectCalls, 0);
    expect(find.text('Enter the client private key.'), findsOneWidget);
  });
}

class FakeVpnService implements VpnService {
  int connectCalls = 0;
  VpnConfiguration? configuration;

  @override
  Future<VpnPeerHealth> getPeerHealth() async => const VpnPeerHealth(
    status: VpnStatus.connected,
    latestHandshakeEpochMillis: 0,
    localNetworkAvailable: true,
  );

  @override
  Future<VpnStatus> connect(VpnConfiguration configuration) async {
    connectCalls += 1;
    this.configuration = configuration;
    return VpnStatus.connected;
  }

  @override
  Future<VpnStatus> disconnect() async => VpnStatus.disconnected;

  @override
  Future<VpnStatus> getStatus() async => VpnStatus.disconnected;
}

class DisconnectRecoveryService implements VpnService {
  DisconnectRecoveryService({required this.throwsException});

  final bool throwsException;
  bool shouldFail = true;
  int disconnectCalls = 0;
  Completer<VpnStatus>? pending;

  @override
  Future<VpnPeerHealth> getPeerHealth() async => const VpnPeerHealth(
    status: VpnStatus.connected,
    latestHandshakeEpochMillis: 0,
    localNetworkAvailable: true,
  );

  @override
  Future<VpnStatus> getStatus() async => VpnStatus.connected;

  @override
  Future<VpnStatus> connect(VpnConfiguration configuration) async =>
      VpnStatus.connected;

  @override
  Future<VpnStatus> disconnect() async {
    disconnectCalls++;
    if (pending != null) return pending!.future;
    if (!shouldFail) return VpnStatus.disconnected;
    if (throwsException) {
      throw const VpnServiceException(
        'Could not stop the tunnel.',
        code: 'TUNNEL_STOP_FAILED',
      );
    }
    return VpnStatus.error;
  }
}
