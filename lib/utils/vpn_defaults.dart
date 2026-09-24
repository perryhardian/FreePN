abstract final class VpnDefaults {
  static const serverEndpoint = String.fromEnvironment('VPN_ENDPOINT');
  static const clientAddress = '10.10.0.2/24';
}
