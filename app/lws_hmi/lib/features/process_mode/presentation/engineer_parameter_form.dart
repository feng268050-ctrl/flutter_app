import 'package:cyber_ime/cyber_ime.dart';
import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart' hide MaterialType;
import 'package:lws_hmi/features/process_library/domain/process_library_l10n.dart';
import 'package:lws_hmi/features/process_library/domain/process_library_models.dart';
import 'package:lws_hmi/features/process_mode/domain/engineer_parameter_presentation.dart';
import 'package:lws_hmi/features/process_mode/domain/engineer_parameter_visibility.dart';
import 'package:lws_hmi/features/process_mode/domain/process_mode_assets.dart';
import 'package:lws_hmi/features/process_mode/presentation/engineer_material_popup.dart';
import 'package:lws_hmi/ui/cyber/cyber_ime_input_dialog.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';
import 'package:lws_hmi/app/theme/hmi_typography.dart';

/// Catalog-driven engineer parameter form (row label + tappable value pill).
///
/// Optional [footer] (e.g. Reset / Save) scrolls with the parameter list and
/// is reached only after scrolling to the end of the form.
final class EngineerParameterForm extends StatelessWidget {
  const EngineerParameterForm({
    super.key,
    required this.preset,
    required this.readOnly,
    required this.onChanged,
    this.onBeginEdit,
    this.footer,
  });

  final ProcessPreset preset;
  final bool readOnly;
  final ValueChanged<ProcessPreset> onChanged;

  /// Unlocks a built-in row into an editable working preset (no DB write yet).
  final Future<ProcessPreset?> Function()? onBeginEdit;

  /// Trailing actions inside the scroll view (e.g. Reset / Save as Favorite).
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final keys =
        EngineerParameterVisibility.parameterKeysFor(preset.processType);
    final rows = <Widget>[
      if (EngineerParameterVisibility.showsMaterial(preset.processType))
        _MaterialRow(
          material: preset.materialType,
          label: preset.displayMaterialLabel(l10n),
          onTap: () => _guarded(context, (w) => _editMaterial(context, w)),
        ),
      if (EngineerParameterVisibility.showsThickness(preset.processType))
        _ValueRow(
          presentation: EngineerParameterPresentation(
            label: l10n.materialThickness,
          ),
          value: preset.thickness == null
              ? '—'
              : '${_formatNumber(preset.thickness!)} mm',
          onTap: () => _guarded(context, (w) => _editThickness(context, w)),
        ),
      for (final key in keys)
        if (ProcessParameterCatalog.byKey[key] case final spec?)
          _ValueRow(
            key: ValueKey('engineer-param-${spec.key}'),
            presentation: EngineerParameterPresentation.forKey(
              key,
              preset.processType,
              l10n,
            ),
            value: preset.parameters.values[key] == null
                ? '—'
                : '${_formatNumber(preset.parameters.values[key]!)} ${spec.unit}',
            onTap: () => _guarded(
              context,
              (working) => _editParameter(context, working, spec),
            ),
          ),
    ];
    final footer = this.footer;
    final children = <Widget>[];
    for (var i = 0; i < rows.length; i++) {
      if (i > 0) {
        children.add(
          const Padding(
            padding: EdgeInsets.only(left: 24),
            child: Divider(
              height: 2,
              thickness: 2,
              color: Color(0x33FFFFFF),
            ),
          ),
        );
      }
      children.add(rows[i]);
    }
    if (footer != null) {
      children
        ..add(
          const Divider(
            key: ValueKey('engineer-parameters-actions-divider'),
            height: 2,
            thickness: 1,
            color: Color(0x33FFFFFF),
            indent: 24,
            endIndent: 8,
          ),
        )
        ..add(footer);
    }

    // Scrollable column (not lazy ListView) so footer actions stay mounted
    // off-screen — user scrolls the right panel to reach Reset / Save.
    // Footer supplies its own bottom inset when present.
    return SingleChildScrollView(
      key: const ValueKey('engineer-parameter-form'),
      padding: EdgeInsets.only(
        right: 16,
        bottom: footer == null ? 20 : 0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
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
    final pill =
        _materialPillKey.currentContext?.findRenderObject() as RenderBox?;
    if (pill == null || !pill.hasSize) {
      return;
    }
    final origin = pill.localToGlobal(Offset.zero);
    final selected = await showEngineerMaterialPopup(
      context: context,
      anchor: origin & pill.size,
      selected: working.materialType,
      processType: working.processType,
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
    final l10n = AppLocalizations.of(context)!;
    final text = await showCyberImeInputDialog(
      context: context,
      title: l10n.thicknessLabel,
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
    final l10n = AppLocalizations.of(context)!;
    final presentation = EngineerParameterPresentation.forKey(
      spec.key,
      working.processType,
      l10n,
    );
    final current = working.parameters.values[spec.key];
    final text = await showCyberImeInputDialog(
      context: context,
      title: presentation.label,
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

/// Shared with [_MaterialRow] so the popup anchors to the value pill.
final GlobalKey _materialPillKey = GlobalKey();

final class _MaterialRow extends StatelessWidget {
  const _MaterialRow({
    required this.material,
    required this.label,
    required this.onTap,
  });

  final MaterialType? material;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 86,
      child: Padding(
        padding: const EdgeInsets.only(left: 24),
        child: Row(
          children: [
            Expanded(
              child: Text(
                AppLocalizations.of(context)?.materialTypeLabel ??
                    'Material Type',
                style: context.hmiTypography.settingsRowTitle.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            SizedBox(
              key: _materialPillKey,
              width: 300,
              height: 72,
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(36),
                clipBehavior: Clip.antiAlias,
                child: Ink.image(
                  image: const AssetImage(
                    ProcessModeAssets.engineerDataValueBackground,
                  ),
                  fit: BoxFit.fill,
                  child: InkWell(
                    onTap: () {
                      CyberClickSoundRegistry.playClick();
                      onTap();
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          if (material != null)
                            Image.asset(
                              ProcessModeAssets.materialIcon(material!),
                              width: 40,
                              height: 20,
                              fit: BoxFit.contain,
                            )
                          else
                            const SizedBox(width: 40, height: 20),
                          Expanded(
                            child: Text(
                              label,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.hmiTypography.sectionTitle.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Image.asset(
                            ProcessModeAssets.selectDownWhiteArrow,
                            width: 18,
                            height: 10,
                            fit: BoxFit.contain,
                          ),
                        ],
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

final class _ValueRow extends StatelessWidget {
  const _ValueRow({
    super.key,
    required this.presentation,
    required this.value,
    required this.onTap,
  });

  final EngineerParameterPresentation presentation;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final suffix = presentation.suffix;
    return SizedBox(
      height: 86,
      child: Padding(
        padding: const EdgeInsets.only(left: 24),
        child: Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      presentation.label,
                      style: context.hmiTypography.settingsRowTitle.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                  if (suffix != null) ...[
                    const SizedBox(width: 6),
                    Text(
                      suffix,
                      style: context.hmiTypography.settingsRowTitle.copyWith(
                        color: presentation.suffixColor ?? Colors.white,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ],
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
                    ProcessModeAssets.engineerDataValueBackground,
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
                        style: context.hmiTypography.settingsRowTitle.copyWith(
                          color: Colors.white,
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
