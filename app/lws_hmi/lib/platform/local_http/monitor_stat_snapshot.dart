/// Monitor SSE / LiveCache snapshot (lws-ui `MonitorStatSnapshot` field shape).
///
/// Missing halves are JSON `null` (not `{}`).
final class MonitorStatSnapshot {
  const MonitorStatSnapshot({
    this.deviceStatus,
    this.deviceData,
    this.processParameters,
  });

  final Map<String, Object?>? deviceStatus;
  final Map<String, Object?>? deviceData;
  final Map<String, Object?>? processParameters;

  static const empty = MonitorStatSnapshot();

  Map<String, Object?> toJson() => {
        'deviceStatus': deviceStatus,
        'deviceData': deviceData,
        'processParameters': processParameters,
      };

  MonitorStatSnapshot copy() => MonitorStatSnapshot(
        deviceStatus:
            deviceStatus == null ? null : Map<String, Object?>.from(deviceStatus!),
        deviceData:
            deviceData == null ? null : Map<String, Object?>.from(deviceData!),
        processParameters: processParameters == null
            ? null
            : Map<String, Object?>.from(processParameters!),
      );

  bool changedSince(MonitorStatSnapshot? previous) {
    if (previous == null) {
      return deviceStatus != null ||
          deviceData != null ||
          processParameters != null;
    }
    return !_mapEquals(deviceStatus, previous.deviceStatus) ||
        !_mapEquals(deviceData, previous.deviceData) ||
        !_mapEquals(processParameters, previous.processParameters);
  }

  static bool _mapEquals(Map<String, Object?>? a, Map<String, Object?>? b) {
    if (identical(a, b)) {
      return true;
    }
    if (a == null || b == null) {
      return a == b;
    }
    if (a.length != b.length) {
      return false;
    }
    for (final e in a.entries) {
      if (!b.containsKey(e.key) || b[e.key] != e.value) {
        return false;
      }
    }
    return true;
  }
}
