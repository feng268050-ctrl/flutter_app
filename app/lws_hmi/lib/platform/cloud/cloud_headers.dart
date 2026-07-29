/// Shared outbound headers for Worker HTTP / WebSocket.
abstract final class CloudHeaders {
  static const deviceType = 'Linux';
  static const headerAppVersion = 'App-Version';
  static const headerDeviceType = 'Device-Type';

  static Map<String, String> forRequest({required String appVersion}) => {
        headerAppVersion: appVersion,
        headerDeviceType: deviceType,
      };
}
