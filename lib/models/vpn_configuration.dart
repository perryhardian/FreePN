class VpnConfiguration {
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
