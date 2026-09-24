import 'package:flutter/material.dart';

import '../models/vpn_status.dart';

class VpnStatusCard extends StatelessWidget {
  const VpnStatusCard({
    required this.status,
    required this.duration,
    super.key,
  });

  final VpnStatus status;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final statusColor = switch (status) {
      VpnStatus.connected => colors.primary,
      VpnStatus.error => colors.error,
      VpnStatus.connecting || VpnStatus.disconnecting => colors.tertiary,
      VpnStatus.disconnected => colors.outline,
    };
    final statusIcon = switch (status) {
      VpnStatus.connected => Icons.shield_rounded,
      VpnStatus.error => Icons.error_outline_rounded,
      VpnStatus.connecting || VpnStatus.disconnecting => Icons.sync_rounded,
      VpnStatus.disconnected => Icons.shield_outlined,
    };

    return Semantics(
      liveRegion: true,
      label: 'VPN status: ${status.label}',
      child: Card(
        elevation: 0,
        color: statusColor.withValues(alpha: 0.10),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(statusIcon, size: 56, color: statusColor),
              const SizedBox(height: 12),
              Text(
                status.label,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: statusColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _formatDuration(duration),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration value) {
    final hours = value.inHours.toString().padLeft(2, '0');
    final minutes = (value.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (value.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }
}
