import 'dart:convert';
import 'dart:io';

class VpnConfiguration {
  factory VpnConfiguration.local({
    required String endpoint,
    required String privateKey,
    required String serverPublicKey,
  }) {
    final server = endpoint.trim();
    if (!RegExp(r'^[A-Za-z0-9.-]+:[0-9]+$').hasMatch(server)) {
      throw const FormatException(
        'Enter a server IP or hostname and port, such as 192.168.1.10:51820.',
      );
    }
    final port = int.tryParse(server.split(':').last);
    final host = server.split(':').first;
    final numericHost = RegExp(r'^[0-9.]+$').hasMatch(host);
    if ((numericHost && InternetAddress.tryParse(host) == null) ||
        host.length > 253 ||
        host
            .split('.')
            .any(
              (label) => !RegExp(
                r'^[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?$',
              ).hasMatch(label),
            )) {
      throw const FormatException(
        'Enter a valid server IPv4 address or hostname.',
      );
    }
    if (port == null || port < 1 || port > 65535) {
      throw const FormatException('The port must be between 1 and 65535.');
    }
    final clientKey = _validateKey(privateKey, 'client private key');
    final peerKey = _validateKey(serverPublicKey, 'server public key');
    return VpnConfiguration(
      endpoint: server,
      configText:
          '[Interface]\n'
          'PrivateKey = $clientKey\n'
          'Address = 10.10.0.2/24\n'
          'DNS = 1.1.1.1\n\n'
          '[Peer]\n'
          'PublicKey = $peerKey\n'
          'Endpoint = $server\n'
          'AllowedIPs = 10.10.0.0/24\n'
          'PersistentKeepalive = 25\n',
    );
  }

  static String _validateKey(String value, String label) {
    final key = value.trim();
    if (key.isEmpty) throw FormatException('Enter the $label.');
    if (RegExp(r'^[A-Za-z0-9+/]{43}=$').hasMatch(key)) {
      final bytes = base64Decode(key);
      if (bytes.length == 32 &&
          bytes.any((byte) => byte != 0) &&
          base64Encode(bytes) == key) {
        return key;
      }
    }
    throw FormatException('The $label must be a valid 32-byte WireGuard key.');
  }

  const VpnConfiguration({
    required this.endpoint,
    this.clientAddress = '10.10.0.2/24',
    this.configText,
  });

  final String endpoint;
  final String clientAddress;
  final String? configText;

  Map<String, Object> toPlatformArguments() {
    final arguments = <String, Object>{
      'endpoint': endpoint,
      'clientAddress': clientAddress,
    };
    final wireGuardConfig = configText?.trim();
    if (wireGuardConfig != null && wireGuardConfig.isNotEmpty) {
      arguments['configText'] = wireGuardConfig;
    }
    return arguments;
  }
}
