import 'package:flutter/services.dart';

import '../models/vpn_configuration.dart';
import '../models/vpn_status.dart';

abstract interface class VpnService {
  Future<VpnStatus> connect(VpnConfiguration configuration);

  Future<VpnStatus> disconnect();

  Future<VpnStatus> getStatus();
}

class MethodChannelVpnService implements VpnService {
  const MethodChannelVpnService();

  static const MethodChannel _channel = MethodChannel('local_vpn/vpn');

  @override
  Future<VpnStatus> connect(VpnConfiguration configuration) async {
    try {
      final result = await _channel.invokeMethod<String>(
        'connect',
        configuration.toPlatformArguments(),
      );
      return VpnStatus.fromPlatformValue(result);
    } on MissingPluginException {
      throw const VpnServiceException(
        'Android VPN integration is not available yet. Implement Phase 4 before connecting.',
      );
    } on PlatformException catch (error) {
      throw VpnServiceException(
        error.message ?? 'Android could not start the VPN connection.',
      );
    }
  }

  @override
  Future<VpnStatus> disconnect() async {
    try {
      final result = await _channel.invokeMethod<String>('disconnect');
      return VpnStatus.fromPlatformValue(result);
    } on MissingPluginException {
      throw const VpnServiceException(
        'Android VPN integration is not available yet.',
      );
    } on PlatformException catch (error) {
      throw VpnServiceException(
        error.message ?? 'Android could not stop the VPN connection.',
      );
    }
  }

  @override
  Future<VpnStatus> getStatus() async {
    try {
      final result = await _channel.invokeMethod<String>('getStatus');
      return VpnStatus.fromPlatformValue(result);
    } on MissingPluginException {
      return VpnStatus.disconnected;
    } on PlatformException catch (error) {
      throw VpnServiceException(
        error.message ?? 'Android could not report the VPN status.',
      );
    }
  }
}

class VpnServiceException implements Exception {
  const VpnServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}
