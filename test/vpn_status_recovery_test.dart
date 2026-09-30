import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_vpn/models/vpn_configuration.dart';
import 'package:local_vpn/models/vpn_status.dart';
import 'package:local_vpn/screens/home_screen.dart';
import 'package:local_vpn/services/vpn_service.dart';

void main() {
  final connect = find.widgetWithText(FilledButton, 'Connect');
  final disconnect = find.widgetWithText(OutlinedButton, 'Disconnect');
  final refresh = find.byWidgetPredicate(
    (widget) => widget is IconButton && widget.tooltip == 'Refresh status',
  );

  for (final throwsError in [false, true]) {
    testWidgets('startup uncertainty allows cleanup: exception=$throwsError', (
      tester,
    ) async {
      final service = StatusService()
        ..status = VpnStatus.error
        ..failStatus = throwsError;
      await tester.pumpWidget(
        MaterialApp(home: HomeScreen(vpnService: service)),
      );
      await tester.pump();
      expect(find.text('Error'), findsOneWidget);
      expect(tester.widget<FilledButton>(connect).onPressed, isNull);
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
      expect(tester.widget<OutlinedButton>(disconnect).onPressed, isNotNull);
      await tester.ensureVisible(disconnect);
      await tester.tap(disconnect);
      await tester.pump();
      expect(service.disconnectCalls, 1);
      expect(find.text('Disconnected'), findsOneWidget);
      expect(tester.widget<FilledButton>(connect).onPressed, isNotNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('initial status query blocks edits and overlapping queries', (
    tester,
  ) async {
    final pending = Completer<VpnStatus>();
    final service = StatusService()..pendingStatus = pending;
    await tester.pumpWidget(MaterialApp(home: HomeScreen(vpnService: service)));
    expect(find.text('Checking VPN status...'), findsOneWidget);
    expect(tester.widget<FilledButton>(connect).onPressed, isNull);
    expect(tester.widget<IconButton>(refresh).onPressed, isNull);
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    expect(service.statusCalls, 1);
    pending.complete(VpnStatus.connected);
    await tester.pump();
    expect(find.text('Connected'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('resume detects external disconnect and stops the timer', (
    tester,
  ) async {
    final service = StatusService()..status = VpnStatus.connected;
    await tester.pumpWidget(MaterialApp(home: HomeScreen(vpnService: service)));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('00:00:02'), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    service.status = VpnStatus.disconnected;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(service.statusCalls, 2);
    expect(find.text('Disconnected'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('00:00:00'), findsOneWidget);
    expect(tester.widget<FilledButton>(connect).onPressed, isNotNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'timed out status can recover without a late reply overwriting it',
    (tester) async {
      final pending = Completer<VpnStatus>();
      final service = StatusService()..pendingStatus = pending;
      await tester.pumpWidget(
        MaterialApp(home: HomeScreen(vpnService: service)),
      );
      await tester.pump(const Duration(seconds: 5));
      expect(
        find.textContaining('Checking the VPN status timed out.'),
        findsOneWidget,
      );
      expect(tester.widget<OutlinedButton>(disconnect).onPressed, isNotNull);
      service.pendingStatus = null;
      await tester.tap(refresh);
      await tester.pump();
      expect(find.text('Disconnected'), findsOneWidget);
      expect(find.textContaining('timed out'), findsNothing);
      pending.complete(VpnStatus.connected);
      await tester.pump();
      expect(find.text('Disconnected'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('resume cannot overwrite a pending disconnect', (tester) async {
    final pending = Completer<VpnStatus>();
    final service = StatusService()
      ..status = VpnStatus.connected
      ..pendingDisconnect = pending;
    await tester.pumpWidget(MaterialApp(home: HomeScreen(vpnService: service)));
    await tester.pump();
    await tester.ensureVisible(disconnect);
    await tester.tap(disconnect);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    expect(service.statusCalls, 1);
    expect(tester.widget<IconButton>(refresh).onPressed, isNull);
    pending.complete(VpnStatus.disconnected);
    await tester.pump();
    expect(find.text('Disconnected'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('refresh remains available for a native transitional state', (
    tester,
  ) async {
    final service = StatusService()..status = VpnStatus.disconnecting;
    await tester.pumpWidget(MaterialApp(home: HomeScreen(vpnService: service)));
    await tester.pump();
    expect(tester.widget<FilledButton>(connect).onPressed, isNull);
    expect(tester.widget<IconButton>(refresh).onPressed, isNotNull);
    service.status = VpnStatus.disconnected;
    await tester.tap(refresh);
    await tester.pump();
    expect(find.text('Disconnected'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}

class StatusService implements VpnService {
  VpnStatus status = VpnStatus.disconnected;
  bool failStatus = false;
  int statusCalls = 0;
  int disconnectCalls = 0;
  Completer<VpnStatus>? pendingStatus;
  Completer<VpnStatus>? pendingDisconnect;

  @override
  Future<VpnStatus> getStatus() async {
    statusCalls++;
    if (pendingStatus != null) return pendingStatus!.future;
    if (failStatus) throw const VpnServiceException('Status unavailable.');
    return status;
  }

  @override
  Future<VpnStatus> connect(VpnConfiguration configuration) async =>
      VpnStatus.connected;

  @override
  Future<VpnStatus> disconnect() async {
    disconnectCalls++;
    if (pendingDisconnect != null) return pendingDisconnect!.future;
    return VpnStatus.disconnected;
  }
}
