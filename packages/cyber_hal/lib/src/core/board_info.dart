/// Static board identity from the active profile (not Modbus / peripheral).
final class BoardInfo {
  const BoardInfo({
    required this.boardId,
    this.displayName,
    this.modelHint,
  });

  final String boardId;
  final String? displayName;
  final String? modelHint;
}
