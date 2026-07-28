import 'dart:io' show Platform;

/// Linux device backends vs in-memory stubs (host tests / emergency).
enum HalBackendKind {
  linux,
  stub,
}

/// Resolves backend kind from `HAL_BACKEND`.
///
/// - Env `HAL_BACKEND=stub` → [HalBackendKind.stub]
/// - otherwise → [HalBackendKind.linux]
///
/// P3.2 UTM guests use `board_id=sim` with **Linux** backends. [boardId] is
/// retained for call-site compatibility and is not used for selection.
HalBackendKind resolveHalBackend({String? boardId, String? env}) {
  final raw = (env ?? Platform.environment['HAL_BACKEND'] ?? '')
      .trim()
      .toLowerCase();
  if (raw == 'stub') {
    return HalBackendKind.stub;
  }
  return HalBackendKind.linux;
}
