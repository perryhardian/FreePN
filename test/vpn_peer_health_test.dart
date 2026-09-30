import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_vpn/models/vpn_configuration.dart';
import 'package:local_vpn/models/vpn_peer_health.dart';
import 'package:local_vpn/models/vpn_status.dart';
import 'package:local_vpn/screens/home_screen.dart';
import 'package:local_vpn/services/vpn_service.dart';

void main() {
  testWidgets('active tunnel without a handshake warns after 30 seconds', (
    tester,
  ) async {
    final service = HealthService();
    await tester.pumpWidget(MaterialApp(home: HomeScreen(vpnService: service)));
    await tester.pump();
    expect(find.text('Waiting for the server handshake...'), findsOneWidget);
    await tester.pump(const Duration(seconds: 31));
    await tester.pump();
    expect(find.textContaining('No server handshake yet.'), findsOneWidget);
    expect(find.text('Connected'), findsOneWidget);
    expect(service.healthCalls, greaterThan(1));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('loss of the local network is reported while tunnel is up', (
    tester,
  ) async {
    final service = HealthService()..localNetworkAvailable = false;
    await tester.pumpWidget(MaterialApp(home: HomeScreen(vpnService: service)));
    await tester.pump();
    expect(
      find.textContaining('No Wi-Fi or Ethernet network is available.'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('peer health detects an externally stopped tunnel', (
    tester,
  ) async {
    final service = HealthService();
    await tester.pumpWidget(MaterialApp(home: HomeScreen(vpnService: service)));
    await tester.pump();
    service.healthStatus = VpnStatus.disconnected;
    await tester.pump(const Duration(seconds: 5));
    await tester.pump();
    expect(find.text('Disconnected'), findsOneWidget);
    expect(find.textContaining('The VPN tunnel stopped.'), findsOneWidget);
    expect(find.text('00:00:00'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('fresh handshake clears the waiting warning', (tester) async {
    final service = HealthService();
    await tester.pumpWidget(MaterialApp(home: HomeScreen(vpnService: service)));
    await tester.pump();
    service.latestHandshakeEpochMillis = DateTime.now().millisecondsSinceEpoch;
    await tester.pump(const Duration(seconds: 5));
    await tester.pump();
    expect(find.text('Server handshake verified.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}

class HealthService implements VpnService {
  VpnStatus healthStatus = VpnStatus.connected;
  bool localNetworkAvailable = true;
  int latestHandshakeEpochMillis = 0;
  int healthCalls = 0;

  @override
  Future<VpnStatus> getStatus() async => VpnStatus.connected;

  @override
  Future<VpnPeerHealth> getPeerHealth() async {
    healthCalls++;
    return VpnPeerHealth(
      status: healthStatus,
      latestHandshakeEpochMillis: latestHandshakeEpochMillis,
      localNetworkAvailable: localNetworkAvailable,
    );
  }

  @override
  Future<VpnStatus> connect(VpnConfiguration configuration) async =>
      VpnStatus.connected;

  @override
  Future<VpnStatus> disconnect() async => VpnStatus.disconnected;
}
