/// Cloud link phases for [CyberCloudStatusIcon] (HAL-agnostic).
///
/// Covers the full product cloud path (API origin probe → device WebSocket),
/// not only the socket handshake.
enum CyberCloudLinkStatus {
  connecting,
  connected,
  failed,
}
