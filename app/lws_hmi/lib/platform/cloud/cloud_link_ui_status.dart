/// Product UI phases for Home status cloud icon (origin probe + WS).
///
/// Not the same as [DeviceWsState]: connecting includes API origin probe and
/// post–Wi‑Fi retries before any WebSocket handshake starts.
library;

enum CloudLinkUiPhase { disabled, connecting, connected, failed }

final class CloudLinkUiStatus {
  const CloudLinkUiStatus({required this.phase});

  final CloudLinkUiPhase phase;

  static const disabled = CloudLinkUiStatus(phase: CloudLinkUiPhase.disabled);
  static const connecting =
      CloudLinkUiStatus(phase: CloudLinkUiPhase.connecting);
  static const connected = CloudLinkUiStatus(phase: CloudLinkUiPhase.connected);
  static const failed = CloudLinkUiStatus(phase: CloudLinkUiPhase.failed);

  @override
  bool operator ==(Object other) {
    return other is CloudLinkUiStatus && other.phase == phase;
  }

  @override
  int get hashCode => phase.hashCode;
}
