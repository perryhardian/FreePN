import 'package:flutter/material.dart';

class WireGuardKeysDialog extends StatefulWidget {
  const WireGuardKeysDialog({
    required this.privateKey,
    required this.publicKey,
    super.key,
  });

  final String privateKey;
  final String publicKey;

  @override
  State<WireGuardKeysDialog> createState() => _WireGuardKeysDialogState();
}

class _WireGuardKeysDialogState extends State<WireGuardKeysDialog> {
  late final _privateController = TextEditingController(
    text: widget.privateKey,
  );
  late final _publicController = TextEditingController(text: widget.publicKey);

  @override
  void dispose() {
    _privateController.dispose();
    _publicController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('WireGuard keys'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Keys stay in memory for this session. Enter them again after restarting the app.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _privateController,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            enableIMEPersonalizedLearning: false,
            decoration: const InputDecoration(labelText: 'Client private key'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _publicController,
            autocorrect: false,
            enableSuggestions: false,
            decoration: const InputDecoration(labelText: 'Server public key'),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      TextButton(
        onPressed: () => Navigator.pop(context, (
          _privateController.text.trim(),
          _publicController.text.trim(),
        )),
        child: const Text('Use keys'),
      ),
    ],
  );
}
