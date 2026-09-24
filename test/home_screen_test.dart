import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_vpn/models/vpn_configuration.dart';
import 'package:local_vpn/models/vpn_status.dart';
import 'package:local_vpn/screens/home_screen.dart';
import 'package:local_vpn/services/vpn_service.dart';

void main() {
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

    await tester.enterText(
      find.byType(TextField),
      '192.168.1.10:51820',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Connect'));
    await tester.pump();

    expect(service.connectCalls, 1);
    expect(find.text('Connected'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });
}

class FakeVpnService implements VpnService {
  int connectCalls = 0;

  @override
  Future<VpnStatus> connect(VpnConfiguration configuration) async {
    connectCalls += 1;
    return VpnStatus.connected;
  }

  @override
  Future<VpnStatus> disconnect() async => VpnStatus.disconnected;

  @override
  Future<VpnStatus> getStatus() async => VpnStatus.disconnected;
}
