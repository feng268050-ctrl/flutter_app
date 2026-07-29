import 'dart:convert';

/// LAN JSON envelope (`ApiResult`) for `:5580`.
final class ApiResult {
  const ApiResult({
    required this.success,
    required this.code,
    required this.message,
    this.data,
  });

  final bool success;
  final int code;
  final String message;
  final Object? data;

  static ApiResult ok({Object? data, String message = 'ok'}) =>
      ApiResult(success: true, code: 0, message: message, data: data);

  static ApiResult fail(
    String message, {
    int code = 1,
    Object? data,
  }) =>
      ApiResult(success: false, code: code, message: message, data: data);

  Map<String, Object?> toJson() => {
        'success': success,
        'code': code,
        'message': message,
        'data': data,
      };

  String encode() => jsonEncode(toJson());
}
