class VpnConfiguration {
  const VpnConfiguration({
    required this.endpoint,
    this.clientAddress = '10.10.0.2/24',
  });

  final String endpoint;
  final String clientAddress;

  Map<String, Object> toPlatformArguments() => <String, Object>{
    'endpoint': endpoint,
    'clientAddress': clientAddress,
  };
}
