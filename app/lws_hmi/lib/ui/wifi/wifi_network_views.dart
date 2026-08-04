import 'package:cyber_hal/network.dart';
import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/app/theme/app_typography.dart';

/// Reusable “current network” panel for Demo / Settings.
class WifiConnectedPanel extends StatelessWidget {
  const WifiConnectedPanel({
    super.key,
    required this.connection,
    this.onDisconnect,
    this.onForget,
  });

  final WifiConnectionState connection;
  final VoidCallback? onDisconnect;
  final VoidCallback? onForget;

  @override
  Widget build(BuildContext context) {
    final muted = TextStyle(color: Colors.white.withOpacity(0.65), fontSize: AppTypography.captionSize);
    final title = connection.ssid?.isNotEmpty == true
        ? connection.ssid!
        : '(associating…)';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: AppTypography.bodySize,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text('Phase: ${connection.phase.name}', style: muted),
        if (connection.ipv4 != null && connection.ipv4!.isNotEmpty)
          Text(
            'IPv4: ${connection.ipv4}'
            '${connection.prefixLength != null ? '/${connection.prefixLength}' : ''}',
            style: muted,
          ),
        if (connection.gateway != null && connection.gateway!.isNotEmpty)
          Text('Gateway: ${connection.gateway}', style: muted),
        if (connection.dns != null && connection.dns!.isNotEmpty)
          Text('DNS: ${connection.dns}', style: muted),
        if (connection.bssid != null && connection.bssid!.isNotEmpty)
          Text('BSSID: ${connection.bssid}', style: muted),
        if (connection.frequencyMhz != null)
          Text('Frequency: ${connection.frequencyMhz} MHz', style: muted),
        if (connection.signalDbm != null)
          Text('Signal: ${connection.signalDbm} dBm', style: muted),
        if (connection.phase == WifiConnectionPhase.failed &&
            connection.message != null &&
            connection.message!.isNotEmpty)
          Text(
            connection.message!,
            style: const TextStyle(color: Colors.redAccent, fontSize: AppTypography.captionSize),
          )
        else if (connection.message != null &&
            connection.message!.isNotEmpty &&
            connection.phase == WifiConnectionPhase.associating)
          Text(connection.message!, style: muted),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            if (onDisconnect != null)
              FilledButton(
                onPressed: () {
                  CyberClickSoundRegistry.playClick();
                  onDisconnect!();
                },
                child: const Text('Disconnect'),
              ),
            if (onForget != null &&
                connection.ssid != null &&
                connection.ssid!.isNotEmpty)
              TextButton(
                onPressed: () {
                  CyberClickSoundRegistry.playClick();
                  onForget!();
                },
                child: Text('Forget ${connection.ssid}'),
              ),
          ],
        ),
      ],
    );
  }
}

/// Available (not currently connected) APs — reuse in Settings.
class WifiAvailableList extends StatelessWidget {
  const WifiAvailableList({
    super.key,
    required this.accessPoints,
    this.onConnect,
    this.emptyLabel = '(no networks — Scan)',
  });

  final List<WifiAccessPoint> accessPoints;
  final void Function(WifiAccessPoint ap)? onConnect;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    if (accessPoints.isEmpty) {
      return Text(
        emptyLabel,
        style: TextStyle(color: Colors.white.withOpacity(0.5)),
      );
    }
    return Column(
      children: accessPoints
          .map(
            (ap) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(
                ap.ssid,
                style: const TextStyle(color: Colors.white),
              ),
              subtitle: Text(
                '${ap.signalDbm ?? '?'} dBm ${ap.flags}',
                style: TextStyle(color: Colors.white.withOpacity(0.6)),
              ),
              trailing: onConnect == null
                  ? null
                  : TextButton(
                      onPressed: () {
                        CyberClickSoundRegistry.playClick();
                        onConnect!(ap);
                      },
                      child: const Text('Connect'),
                    ),
            ),
          )
          .toList(),
    );
  }
}
