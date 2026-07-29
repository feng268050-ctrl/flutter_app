import 'package:lws_hmi/features/process_library/domain/process_library_models.dart';
import 'package:lws_hmi/features/process_mode/domain/process_mode_tokens.dart';
import 'package:lws_hmi/features/process_video/domain/process_video_models.dart';

/// Display helpers for Monitor process-video list/detail (lws-ui column labels).
abstract final class ProcessVideoFormat {
  static String workMode(ProcessType type) => ProcessModeLabels.wheelLabel(type);

  static String material(ProcessVideoRecord record) {
    final snap = record.snapshot;
    final name = snap?.materialName?.trim();
    if (name != null && name.isNotEmpty) {
      return name;
    }
    final material = record.materialType ?? snap?.materialType;
    if (material == null) {
      return '—';
    }
    return material.englishName;
  }

  static String recordingTime(ProcessVideoRecord record) {
    final t = record.createTime;
    String two(int n) => n.toString().padLeft(2, '0');
    return '${t.year}-${two(t.month)}-${two(t.day)} '
        '${two(t.hour)}:${two(t.minute)}';
  }

  static String duration(int durationMs) {
    final totalSec = (durationMs / 1000).floor().clamp(0, 99 * 3600);
    final m = totalSec ~/ 60;
    final s = totalSec % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  static String parameterLabel(String key) {
    final spec = ProcessParameterCatalog.byKey[key];
    if (spec != null) {
      return spec.unit.isEmpty ? spec.label : '${spec.label} (${spec.unit})';
    }
    return key;
  }

  static String parameterValue(num value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(2);
  }
}
