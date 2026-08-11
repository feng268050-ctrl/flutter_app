import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:os_settings/chrome/settings_chrome.dart';

/// Shared **IPv4 Address** + **DNS** sections (Wi‑Fi Details / Ethernet).
///
/// Automatic: read-only value rows. Manual: nav rows that open IME editors +
/// optional DNS add button.
class SettingsIpv4DnsGroups extends StatelessWidget {
  const SettingsIpv4DnsGroups({
    super.key,
    required this.busy,
    required this.manualIp,
    required this.manualDns,
    required this.ipv4SectionTitle,
    required this.configureIpTitle,
    required this.configureDnsTitle,
    required this.dnsSectionTitle,
    required this.automaticLabel,
    required this.manualLabel,
    required this.ipAddressTitle,
    required this.subnetMaskTitle,
    required this.gatewayTitle,
    required this.dnsServersTitle,
    required this.dnsServerTitle,
    required this.addDnsTooltip,
    required this.unavailable,
    required this.ipAddress,
    required this.subnetMask,
    required this.gateway,
    required this.automaticDnsDisplay,
    required this.manualDnsServers,
    required this.onIpModeChanged,
    required this.onDnsModeChanged,
    required this.onEditIpAddress,
    required this.onEditSubnetMask,
    required this.onEditGateway,
    required this.onAddDnsServer,
    required this.onEditDnsServer,
    this.maxDnsServers = 3,
  });

  final bool busy;
  final bool manualIp;
  final bool manualDns;

  final String ipv4SectionTitle;
  final String configureIpTitle;
  final String configureDnsTitle;
  final String dnsSectionTitle;
  final String automaticLabel;
  final String manualLabel;
  final String ipAddressTitle;
  final String subnetMaskTitle;
  final String gatewayTitle;
  final String dnsServersTitle;
  final String dnsServerTitle;
  final String addDnsTooltip;
  final String unavailable;

  final String ipAddress;
  final String subnetMask;
  final String gateway;
  final String automaticDnsDisplay;
  final List<String> manualDnsServers;

  /// `true` = Automatic (DHCP), `false` = Manual.
  final ValueChanged<bool> onIpModeChanged;

  /// `true` = Automatic DNS, `false` = Manual.
  final ValueChanged<bool> onDnsModeChanged;

  final VoidCallback onEditIpAddress;
  final VoidCallback onEditSubnetMask;
  final VoidCallback onEditGateway;
  final VoidCallback onAddDnsServer;
  final ValueChanged<int> onEditDnsServer;

  final int maxDnsServers;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsSectionHeader(ipv4SectionTitle),
        SettingsGroup(
          borderGradientCenter: CyberBorderGradientCenter.bottomLeftTopRight,
          children: [
            SettingsControlRow(
              title: configureIpTitle,
              control: CyberSegmentedControl<bool>(
                segments: [
                  ButtonSegment(
                    value: true,
                    label: Text(automaticLabel),
                  ),
                  ButtonSegment(
                    value: false,
                    label: Text(manualLabel),
                  ),
                ],
                selected: {!manualIp},
                onSelectionChanged: busy
                    ? (_) {}
                    : (s) {
                        if (s.isEmpty) return;
                        onIpModeChanged(s.first);
                      },
              ),
            ),
            if (manualIp) ...[
              SettingsNavRow(
                title: ipAddressTitle,
                value: ipAddress,
                onTap: busy ? null : onEditIpAddress,
              ),
              SettingsNavRow(
                title: subnetMaskTitle,
                value: subnetMask,
                onTap: busy ? null : onEditSubnetMask,
              ),
              SettingsNavRow(
                title: gatewayTitle,
                value: gateway,
                onTap: busy ? null : onEditGateway,
              ),
            ] else ...[
              SettingsValueRow(title: ipAddressTitle, value: ipAddress),
              SettingsValueRow(title: subnetMaskTitle, value: subnetMask),
              SettingsValueRow(title: gatewayTitle, value: gateway),
            ],
          ],
        ),
        SettingsSectionHeader(dnsSectionTitle),
        SettingsGroup(
          borderGradientCenter: CyberBorderGradientCenter.topLeftBottomRight,
          children: [
            SettingsControlRow(
              title: configureDnsTitle,
              control: CyberSegmentedControl<bool>(
                segments: [
                  ButtonSegment(
                    value: true,
                    label: Text(automaticLabel),
                  ),
                  ButtonSegment(
                    value: false,
                    label: Text(manualLabel),
                  ),
                ],
                selected: {!manualDns},
                onSelectionChanged: busy
                    ? (_) {}
                    : (s) {
                        if (s.isEmpty) return;
                        onDnsModeChanged(s.first);
                      },
              ),
            ),
            if (manualDns) ...[
              if (manualDnsServers.isEmpty)
                SettingsValueRow(
                  title: dnsServersTitle,
                  value: unavailable,
                )
              else
                for (var i = 0; i < manualDnsServers.length; i++)
                  SettingsNavRow(
                    title: '$dnsServerTitle ${i + 1}',
                    value: manualDnsServers[i],
                    onTap: busy ? null : () => onEditDnsServer(i),
                  ),
              if (manualDnsServers.length < maxDnsServers)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Align(
                    alignment: Alignment.center,
                    child: IconButton(
                      tooltip: addDnsTooltip,
                      onPressed: busy ? null : onAddDnsServer,
                      icon: const Icon(
                        Icons.add_circle_outline,
                        color: CyberColors.buttonPrimaryAccent,
                        size: 28,
                      ),
                    ),
                  ),
                ),
            ] else
              SettingsValueRow(
                title: dnsServersTitle,
                value: automaticDnsDisplay,
              ),
          ],
        ),
      ],
    );
  }
}

/// Parse dotted IPv4 subnet mask or integer prefix (0–32) → prefix length.
int? parseIpv4PrefixLength(String raw) {
  final t = raw.trim();
  final asInt = int.tryParse(t);
  if (asInt != null && asInt >= 0 && asInt <= 32) return asInt;
  final parts = t.split('.');
  if (parts.length != 4) return null;
  final octets = <int>[];
  for (final p in parts) {
    final o = int.tryParse(p);
    if (o == null || o < 0 || o > 255) return null;
    octets.add(o);
  }
  var mask = 0;
  for (final o in octets) {
    mask = (mask << 8) | o;
  }
  mask &= 0xFFFFFFFF;
  var prefix = 0;
  var bit = 0x80000000;
  while (prefix < 32 && (mask & bit) != 0) {
    prefix++;
    bit >>= 1;
  }
  final expected = prefix == 0
      ? 0
      : prefix == 32
          ? 0xFFFFFFFF
          : (0xFFFFFFFF << (32 - prefix)) & 0xFFFFFFFF;
  if (mask != expected) return null;
  return prefix;
}
