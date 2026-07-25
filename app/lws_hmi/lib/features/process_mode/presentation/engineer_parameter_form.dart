import 'package:cyber_ime/cyber_ime.dart';
import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart' hide MaterialType;
import 'package:lws_hmi/features/process_library/domain/process_library_models.dart';
import 'package:lws_hmi/features/process_mode/domain/engineer_parameter_visibility.dart';
import 'package:lws_hmi/ui/cyber/cyber_ime_input_dialog.dart';

/// Catalog-driven engineer parameter form (row label + tappable value pill).
final class EngineerParameterForm extends StatelessWidget {
  const EngineerParameterForm({
    super.key,
    required this.preset,
    required this.readOnly,
    required this.onChanged,
    this.onBeginEdit,
  });

  final ProcessPreset preset;
  final bool readOnly;
  final ValueChanged<ProcessPreset> onChanged;

  /// Unlocks a built-in row into an editable working preset (no DB write yet).
  final Future<ProcessPreset?> Function()? onBeginEdit;

  @override
  Widget build(BuildContext context) {
    final keys =
        EngineerParameterVisibility.parameterKeysFor(preset.processType);
    final rows = <Widget>[
      if (EngineerParameterVisibility.showsMaterial(preset.processType))
        _ValueRow(
          label: 'Material Type',
          value: preset.materialName ?? preset.materialType?.englishName ?? '—',
          onTap: () => _guarded(context, (w) => _editMaterial(context, w)),
        ),
      if (EngineerParameterVisibility.showsThickness(preset.processType))
        _ValueRow(
          label: 'Material Thickness',
          value: preset.thickness == null
              ? '—'
              : '${_formatNumber(preset.thickness!)} mm',
          onTap: () => _guarded(context, (w) => _editThickness(context, w)),
        ),
      for (final key in keys)
        if (ProcessParameterCatalog.byKey[key] case final spec?)
          _ValueRow(
            key: ValueKey('engineer-param-${spec.key}'),
            label: spec.label,
            value: preset.parameters.values[key] == null
                ? '—'
                : '${_formatNumber(preset.parameters.values[key]!)} ${spec.unit}',
            onTap: () => _guarded(
              context,
              (working) => _editParameter(context, working, spec),
            ),
          ),
    ];

    return ListView.separated(
      key: const ValueKey('engineer-parameter-form'),
      padding: const EdgeInsets.only(right: 16, bottom: 20),
      itemCount: rows.length,
      separatorBuilder: (_, __) => const Padding(
        padding: EdgeInsets.only(left: 24),
        child: Divider(
          height: 2,
          thickness: 2,
          color: Color(0xFF1A1B32),
        ),
      ),
      itemBuilder: (_, index) => rows[index],
    );
  }

  Future<void> _guarded(
    BuildContext context,
    Future<void> Function(ProcessPreset working) edit,
  ) async {
    var working = preset;
    if (readOnly) {
      final begin = onBeginEdit;
      if (begin == null) {
        return;
      }
      final unlocked = await begin();
      if (unlocked == null || !context.mounted) {
        return;
      }
      working = unlocked;
    }
    await edit(working);
  }

  Future<void> _editMaterial(
    BuildContext context,
    ProcessPreset working,
  ) async {
    final materials =
        MaterialType.values.where((m) => m != MaterialType.custom).toList();
    final selected = await showModalBottomSheet<MaterialType>(
      context: context,
      backgroundColor: const Color(0xFF12142A),
      builder: (context) => ListView(
        shrinkWrap: true,
        children: [
          for (final material in materials)
            ListTile(
              title: Text(
                material.englishName,
                style: const TextStyle(color: Colors.white),
              ),
              selected: material == working.materialType,
              onTap: () {
                CyberClickSoundRegistry.playClick();
                Navigator.pop(context, material);
              },
            ),
        ],
      ),
    );
    if (selected == null) {
      return;
    }
    onChanged(
      working.copyWith(
        materialType: selected,
        materialName: selected.englishName,
      ),
    );
  }

  Future<void> _editThickness(
    BuildContext context,
    ProcessPreset working,
  ) async {
    final text = await showCyberImeInputDialog(
      context: context,
      title: 'Thickness',
      fieldType: CyberImeFieldType.signedDecimal,
      initial: working.thickness?.toString() ?? '',
      label: 'mm',
      requireNonEmpty: true,
    );
    if (text == null) {
      return;
    }
    final value = double.tryParse(text.trim());
    if (value == null || value < 0) {
      return;
    }
    onChanged(working.copyWith(thickness: value));
  }

  Future<void> _editParameter(
    BuildContext context,
    ProcessPreset working,
    ProcessParameterSpec spec,
  ) async {
    final current = working.parameters.values[spec.key];
    final text = await showCyberImeInputDialog(
      context: context,
      title: spec.label,
      fieldType: CyberImeFieldType.signedDecimal,
      initial: current?.toString() ?? '',
      label: '${spec.min}–${spec.max} ${spec.unit}',
      requireNonEmpty: true,
    );
    if (text == null) {
      return;
    }
    final value = double.tryParse(text.trim());
    if (value == null) {
      return;
    }
    final nextValues = Map<String, double>.from(working.parameters.values)
      ..[spec.key] = value;
    onChanged(working.copyWith(parameters: ProcessParameters(nextValues)));
  }

  static String _formatNumber(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(2);
  }
}

final class _ValueRow extends StatelessWidget {
  const _ValueRow({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 100,
      child: Padding(
        padding: const EdgeInsets.only(left: 24),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
            ),
            SizedBox(
              width: 300,
              height: 72,
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(36),
                clipBehavior: Clip.antiAlias,
                child: Ink.image(
                  image: const AssetImage(
                    'assets/process/engineer_data_value_background.webp',
                  ),
                  fit: BoxFit.fill,
                  child: InkWell(
                    onTap: () {
                      CyberClickSoundRegistry.playClick();
                      onTap();
                    },
                    child: Center(
                      child: Text(
                        value,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
