/// Shared outbound headers for Worker HTTP / WebSocket.
abstract final class CloudHeaders {
  static const deviceType = 'Linux';
  static const headerAppVersion = 'App-Version';
  static const headerDeviceType = 'Device-Type';
  static const headerAuthorization = 'Authorization';

  /// Base app headers, optionally with device `access_token` Bearer.
  static Map<String, String> forRequest({
    required String appVersion,
    String? accessToken,
  }) {
    final headers = <String, String>{
      headerAppVersion: appVersion,
      headerDeviceType: deviceType,
    };
    final token = accessToken?.trim();
    if (token != null && token.isNotEmpty) {
      headers[headerAuthorization] = bearerValue(token);
    }
    return headers;
  }

  /// `Authorization: Bearer <access_token>` only.
  static Map<String, String> deviceBearer(String accessToken) => {
        headerAuthorization: bearerValue(accessToken),
      };

  static String bearerValue(String accessToken) =>
      'Bearer ${accessToken.trim()}';

  /// Activate / token mint must not carry a prior device Bearer.
  static bool isDeviceAuthBootstrapPath(Uri url) {
    final segments = url.pathSegments;
    if (segments.isEmpty) {
      return false;
    }
    final last = segments.last;
    return last == 'activate' || last == 'token';
  }
}
