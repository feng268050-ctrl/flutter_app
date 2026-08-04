import 'package:cyber_hal/network.dart';
import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/app/theme/app_typography.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';

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
    final l10n = AppLocalizations.of(context)!;
    final muted = TextStyle(color: Colors.white.withOpacity(0.65), fontSize: AppTypography.captionSize);
    final title = connection.ssid?.isNotEmpty == true
        ? connection.ssid!
        : l10n.wifiAssociatingPlaceholder;
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
        Text('${l10n.wifiPhase}: ${connection.phase.name}', style: muted),
        if (connection.ipv4 != null && connection.ipv4!.isNotEmpty)
          Text(
            '${l10n.wifiIpv4}: ${connection.ipv4}'
            '${connection.prefixLength != null ? '/${connection.prefixLength}' : ''}',
            style: muted,
          ),
        if (connection.gateway != null && connection.gateway!.isNotEmpty)
          Text('${l10n.wifiGateway}: ${connection.gateway}', style: muted),
        if (connection.dns != null && connection.dns!.isNotEmpty)
          Text('${l10n.wifiDns}: ${connection.dns}', style: muted),
        if (connection.bssid != null && connection.bssid!.isNotEmpty)
          Text('${l10n.wifiBssid}: ${connection.bssid}', style: muted),
        if (connection.frequencyMhz != null)
          Text(
            '${l10n.wifiFrequency}: ${connection.frequencyMhz} MHz',
            style: muted,
          ),
        if (connection.signalDbm != null)
          Text(
            '${l10n.wifiSignal}: ${connection.signalDbm} dBm',
            style: muted,
          ),
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
                child: Text(l10n.wifiDisconnect),
              ),
            if (onForget != null &&
                connection.ssid != null &&
                connection.ssid!.isNotEmpty)
              TextButton(
                onPressed: () {
                  CyberClickSoundRegistry.playClick();
                  onForget!();
                },
                child: Text(l10n.wifiForgetSsid(connection.ssid!)),
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
    this.emptyLabel,
  });

  final List<WifiAccessPoint> accessPoints;
  final void Function(WifiAccessPoint ap)? onConnect;
  final String? emptyLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (accessPoints.isEmpty) {
      return Text(
        emptyLabel ?? l10n.wifiNoNetworksScan,
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
                      child: Text(l10n.wifiDialogConnect),
                    ),
            ),
          )
          .toList(),
    );
  }
}
