/// Structured HAL errors. Product Apps SHOULD catch [HalException] rather than
/// raw [UnsupportedError] alone.
sealed class HalException implements Exception {
  const HalException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() =>
      code == null ? 'HalException: $message' : 'HalException($code): $message';
}

/// Capability or module is not present on this board / profile.
final class HalUnsupportedException extends HalException {
  const HalUnsupportedException(super.message, {super.code = 'unsupported'});
}

/// Config or resource id was not found (gpio line, modbus attribute, …).
final class HalNotFoundException extends HalException {
  const HalNotFoundException(super.message, {super.code = 'not_found'});
}

/// Backend / OS helper failed.
final class HalIoException extends HalException {
  const HalIoException(super.message, {super.code = 'io', this.cause});

  final Object? cause;
}
