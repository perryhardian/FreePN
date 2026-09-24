import 'dart:async';

import 'package:flutter/material.dart';

import '../models/vpn_configuration.dart';
import '../models/vpn_status.dart';
import '../services/vpn_service.dart';
import '../utils/vpn_defaults.dart';
import '../widgets/vpn_status_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({this.vpnService, super.key});

  final VpnService? vpnService;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final VpnService _vpnService;
  late final TextEditingController _endpointController;
  VpnStatus _status = VpnStatus.disconnected;
  Duration _connectionDuration = Duration.zero;
  Timer? _durationTimer;
  String? _errorMessage;

  bool get _isBusy =>
      _status == VpnStatus.connecting || _status == VpnStatus.disconnecting;

  @override
  void initState() {
    super.initState();
    _vpnService = widget.vpnService ?? const MethodChannelVpnService();
    _endpointController = TextEditingController(
      text: VpnDefaults.serverEndpoint,
    );
    unawaited(_loadStatus());
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _endpointController.dispose();
    super.dispose();
  }

  Future<void> _loadStatus() async {
    try {
      final status = await _vpnService.getStatus();
      if (!mounted) return;
      setState(() => _status = status);
      if (status == VpnStatus.connected) _startDurationTimer();
    } on VpnServiceException catch (error) {
      if (!mounted) return;
      setState(() {
        _status = VpnStatus.error;
        _errorMessage = error.message;
      });
    }
  }

  Future<void> _connect() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final endpointError = _validateEndpoint(_endpointController.text);
    if (endpointError != null) {
      setState(() {
        _status = VpnStatus.error;
        _errorMessage = endpointError;
      });
      return;
    }

    setState(() {
      _status = VpnStatus.connecting;
      _errorMessage = null;
    });

    try {
      final status = await _vpnService.connect(
        VpnConfiguration(
          endpoint: _endpointController.text.trim(),
          clientAddress: VpnDefaults.clientAddress,
        ),
      );
      if (!mounted) return;
      setState(() => _status = status);
      if (status == VpnStatus.connected) _startDurationTimer();
    } on VpnServiceException catch (error) {
      if (!mounted) return;
      setState(() {
        _status = VpnStatus.error;
        _errorMessage = error.message;
      });
    }
  }

  Future<void> _disconnect() async {
    setState(() {
      _status = VpnStatus.disconnecting;
      _errorMessage = null;
    });

    try {
      final status = await _vpnService.disconnect();
      if (!mounted) return;
      _durationTimer?.cancel();
      setState(() {
        _status = status;
        _connectionDuration = Duration.zero;
      });
    } on VpnServiceException catch (error) {
      if (!mounted) return;
      setState(() {
        _status = VpnStatus.error;
        _errorMessage = error.message;
      });
    }
  }

  void _startDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _connectionDuration += const Duration(seconds: 1));
    });
  }

  String? _validateEndpoint(String value) {
    final endpoint = value.trim();
    if (endpoint.isEmpty) {
      return 'Enter your laptop LAN address and WireGuard port.';
    }

    final separatorIndex = endpoint.lastIndexOf(':');
    if (separatorIndex <= 0 || separatorIndex == endpoint.length - 1) {
      return 'Use an endpoint such as 192.168.1.10:51820.';
    }
    final host = endpoint.substring(0, separatorIndex).trim();
    final port = int.tryParse(endpoint.substring(separatorIndex + 1));
    if (host.isEmpty || port == null) {
      return 'Use an endpoint such as 192.168.1.10:51820.';
    }
    if (port < 1 || port > 65535) {
      return 'The port must be between 1 and 65535.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final canConnect = !_isBusy && _status != VpnStatus.connected;
    final canDisconnect = !_isBusy && _status == VpnStatus.connected;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Local VPN'),
        centerTitle: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  VpnStatusCard(
                    status: _status,
                    duration: _connectionDuration,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Connection details',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _endpointController,
                    enabled: !_isBusy && _status != VpnStatus.connected,
                    keyboardType: TextInputType.url,
                    textInputAction: TextInputAction.done,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      labelText: 'Server endpoint',
                      hintText: '192.168.1.10:51820',
                      helperText: 'Your laptop LAN address and WireGuard port',
                      prefixIcon: Icon(Icons.dns_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _ReadOnlyDetail(
                    icon: Icons.smartphone_outlined,
                    label: 'VPN IP',
                    value: VpnDefaults.clientAddress,
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Semantics(
                      liveRegion: true,
                      child: Material(
                        color: Theme.of(context)
                            .colorScheme
                            .errorContainer,
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.error_outline,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onErrorContainer,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: TextStyle(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onErrorContainer,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: canConnect ? _connect : null,
                    icon: _status == VpnStatus.connecting
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.power_settings_new_rounded),
                    label: const Text('Connect'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: canDisconnect ? _disconnect : null,
                    icon: _status == VpnStatus.disconnecting
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.link_off_rounded),
                    label: const Text('Disconnect'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReadOnlyDetail extends StatelessWidget {
  const _ReadOnlyDetail({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: ListTile(
        leading: Icon(icon),
        title: Text(label),
        subtitle: Text(value),
      ),
    );
  }
}
