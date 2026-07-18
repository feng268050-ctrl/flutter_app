import 'dart:io' show Platform;

/// Linux device backends vs in-memory stubs (P3.2 emulator / host tests).
enum HalBackendKind {
  linux,
  stub,
}

/// Resolves backend kind from `HAL_BACKEND` and/or [boardId].
///
/// - Env `HAL_BACKEND=stub` or `sim` → [HalBackendKind.stub]
/// - [boardId] `sim` → [HalBackendKind.stub]
/// - otherwise → [HalBackendKind.linux]
HalBackendKind resolveHalBackend({String? boardId, String? env}) {
  final raw = (env ?? Platform.environment['HAL_BACKEND'] ?? '')
      .trim()
      .toLowerCase();
  if (raw == 'stub' || raw == 'sim') {
    return HalBackendKind.stub;
  }
  if (boardId == 'sim') {
    return HalBackendKind.stub;
  }
  return HalBackendKind.linux;
}
