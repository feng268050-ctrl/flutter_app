import 'package:flutter/material.dart';
import 'package:lws_hmi/features/process_library/domain/process_library_models.dart';

/// Compact read-only parameter preview for the matched quick preset.
final class QuickModeParameterPreview extends StatelessWidget {
  const QuickModeParameterPreview({
    super.key,
    required this.preset,
  });

  final ProcessPreset? preset;

  static const _previewKeys = <String>[
    'process.laser_power',
    'process.laser_frequency',
    'process.laser_duty_cycle',
    'process.swing_frequency',
    'process.swing_width',
    'process.wire_feeding_speed',
  ];

  @override
  Widget build(BuildContext context) {
    final value = preset;
    if (value == null) {
      return const SizedBox(
        key: ValueKey('quick-mode-parameter-preview-empty'),
        width: 280,
        child: Text(
          'No matching process',
          style: TextStyle(color: Color(0x99FFFFFF), fontSize: 14),
        ),
      );
    }

    final rows = <Widget>[
      Text(
        value.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 8),
    ];
    for (final key in _previewKeys) {
      final number = value.parameters.values[key];
      if (number == null) {
        continue;
      }
      final spec = ProcessParameterCatalog.byKey[key];
      if (spec == null) {
        continue;
      }
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  spec.label,
                  style: const TextStyle(
                    color: Color(0xB3FFFFFF),
                    fontSize: 13,
                  ),
                ),
              ),
              Text(
                '$number ${spec.unit}',
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      key: const ValueKey('quick-mode-parameter-preview'),
      width: 280,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: rows,
      ),
    );
  }
}

/// Top-right "More Parameters" entry to Engineer Mode.
final class QuickModeMoreParametersButton extends StatelessWidget {
  const QuickModeMoreParametersButton({
    super.key,
    required this.enabled,
    required this.onPressed,
  });

  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.35,
      child: TextButton.icon(
        key: const ValueKey('quick-mode-more-parameters'),
        onPressed: enabled ? onPressed : null,
        icon: const Icon(Icons.tune, color: Colors.white, size: 20),
        label: const Text(
          'More Parameters',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
        ),
      ),
    );
  }
}
