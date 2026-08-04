/// JSON body for camera `PUT /System/showtime` (lws-ui `CameraShowTimeRequest`).
///
/// When [create] fills the clock (`fillNow: true`), fields use the device
/// **local** wall clock so OSD DateTimeOverlay matches HMI timezone (CST etc.).
/// lws-ui historically filled UTC here; that made the burned-in clock look wrong.
final class CameraShowTimeRequest {
  const CameraShowTimeRequest({
    required this.enable,
    required this.positionx,
    required this.positiony,
    required this.year,
    required this.month,
    required this.day,
    required this.hour,
    required this.minute,
    required this.sec,
  });

  final int enable;
  final int positionx;
  final int positiony;
  final int year;

  /// Camera API field `mon`.
  final int month;
  final int day;
  final int hour;

  /// Camera API field `min`.
  final int minute;
  final int sec;

  factory CameraShowTimeRequest.create({
    required int enable,
    required int positionX,
    required int positionY,
    required bool fillNow,
    DateTime? now,
  }) {
    final base = CameraShowTimeRequest(
      enable: enable,
      positionx: positionX,
      positiony: positionY,
      year: 0,
      month: 0,
      day: 0,
      hour: 0,
      minute: 0,
      sec: 0,
    );
    if (!fillNow) {
      return base;
    }
    final t = now ?? DateTime.now();
    return CameraShowTimeRequest(
      enable: enable,
      positionx: positionX,
      positiony: positionY,
      year: t.year,
      month: t.month,
      day: t.day,
      hour: t.hour,
      minute: t.minute,
      sec: t.second,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'enable': enable,
        'positionx': positionx,
        'positiony': positiony,
        'year': year,
        'mon': month,
        'day': day,
        'hour': hour,
        'min': minute,
        'sec': sec,
      };
}
