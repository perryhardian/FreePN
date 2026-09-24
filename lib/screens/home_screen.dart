import 'dart:async';

import 'package:flutter/material.dart';

import '../models/vpn_configuration.dart';
import '../models/vpn_status.dart';
import '../services/vpn_service.dart';
import '../utils/vpn_defaults.dart';
import '../widgets/vpn_status_card.dart';
import '../widgets/wireguard_keys_dialog.dart';

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
  String _privateKey = '';
  String _serverPublicKey = '';

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
    late final VpnConfiguration configuration;
    try {
      configuration = VpnConfiguration.local(
        endpoint: _endpointController.text,
        privateKey: _privateKey,
        serverPublicKey: _serverPublicKey,
      );
    } on FormatException catch (error) {
      setState(() {
        _status = VpnStatus.error;
        _errorMessage = error.message;
      });
      return;
    }

    setState(() {
      _status = VpnStatus.connecting;
      _errorMessage = null;
    });

    try {
      final status = await _vpnService.connect(configuration);
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

  Future<void> _editKeys() async {
    final keys = await showDialog<(String, String)>(
      context: context,
      builder: (context) => WireGuardKeysDialog(
        privateKey: _privateKey,
        publicKey: _serverPublicKey,
      ),
    );
    if (!mounted || keys == null) return;
    setState(() {
      _privateKey = keys.$1;
      _serverPublicKey = keys.$2;
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final canConnect = !_isBusy && _status != VpnStatus.connected;
    final canDisconnect = !_isBusy && _status == VpnStatus.connected;

    return Scaffold(
      appBar: AppBar(title: const Text('Local VPN'), centerTitle: false),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  VpnStatusCard(status: _status, duration: _connectionDuration),
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
                  TextButton.icon(
                    onPressed: canConnect ? _editKeys : null,
                    icon: const Icon(Icons.key_outlined),
                    label: Text(
                      _privateKey.isEmpty
                          ? 'Configure WireGuard keys'
                          : 'Edit WireGuard keys',
                    ),
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Semantics(
                      liveRegion: true,
                      child: Material(
                        color: Theme.of(context).colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.error_outline,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onErrorContainer,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onErrorContainer,
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
