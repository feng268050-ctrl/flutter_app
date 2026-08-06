import 'package:cyber_ime/cyber_ime.dart';
import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart' hide MaterialType;
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/app/theme/hmi_button_metrics.dart';
import 'package:lws_hmi/features/process_library/application/process_library_controller.dart';
import 'package:lws_hmi/features/process_library/application/process_library_scope.dart';
import 'package:lws_hmi/features/process_library/application/process_parameter_applier.dart';
import 'package:lws_hmi/features/process_library/domain/process_library_l10n.dart';
import 'package:lws_hmi/features/process_library/domain/process_library_models.dart';
import 'package:lws_hmi/features/status_bar/product_page_status_bar.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';
import 'package:lws_hmi/ui/hmi/hmi_button.dart';
import 'package:lws_hmi/ui/hmi/hmi_dialog_actions.dart';
import 'package:lws_hmi/ui/tip_dialog_host.dart';

enum ProcessLibraryPageMode { quick, engineer }

final class ProcessLibraryPage extends StatefulWidget {
  const ProcessLibraryPage({
    super.key,
    required this.mode,
  });

  final ProcessLibraryPageMode mode;

  @override
  State<ProcessLibraryPage> createState() => _ProcessLibraryPageState();
}

final class _ProcessLibraryPageState extends State<ProcessLibraryPage> {
  ProcessType _processType = ProcessType.continuousWelding;
  MaterialType? _material;
  double? _thickness;
  int? _gear;
  ProcessPreset? _selected;

  @override
  void initState() {
    super.initState();
    scheduleEnsureModbusLive(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ProcessLibraryScope.of(context).initialize();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final controller = ProcessLibraryScope.of(context);
    final isQuick = widget.mode == ProcessLibraryPageMode.quick;
    return Scaffold(
      appBar: ProductPageStatusBar(
        title: isQuick ? l10n.homeQuickModeLabel : l10n.homeEngineerModeLabel,
        onBack: () => Navigator.of(context).maybePop(),
      ),
      body: controller.loading && !controller.initialized
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (controller.lastError != null)
                  MaterialBanner(
                    content: Text(
                      '${l10n.processLibraryUpdateFailed}\n'
                      '${controller.lastError}',
                    ),
                    actions: [
                      HmiButton(
                        label: l10n.retryText,
                        size: HmiButtonSize.medium,
                        variant: CyberButtonVariant.standard,
                        onPressed: controller.initialize,
                      ),
                    ],
                  ),
                Expanded(
                  child: isQuick
                      ? _buildQuick(controller)
                      : _buildEngineer(controller),
                ),
              ],
            ),
    );
  }

  Widget _buildQuick(ProcessLibraryController controller) {
    final l10n = AppLocalizations.of(context)!;
    final all = controller.quickPresets(processType: _processType).toList();
    final materials = all
        .map((preset) => preset.materialType)
        .whereType<MaterialType>()
        .toSet()
        .toList();
    final byMaterial = all
        .where(
            (preset) => _material == null || preset.materialType == _material)
        .toList();
    final useSwingWidth = _processType.isCleaning;
    final dimensions = byMaterial
        .map((preset) => useSwingWidth
            ? preset.parameters.values['process.swing_width']
            : preset.thickness)
        .whereType<double>()
        .toSet()
        .toList()
      ..sort();
    final byDimension = byMaterial.where((preset) {
      if (_thickness == null) {
        return true;
      }
      final dimension = useSwingWidth
          ? preset.parameters.values['process.swing_width']
          : preset.thickness;
      return dimension == _thickness;
    }).toList();
    final gears = byDimension
        .map((preset) => preset.gear)
        .whereType<int>()
        .toSet()
        .toList()
      ..sort();
    final matches = byDimension
        .where((preset) => _gear == null || preset.gear == _gear)
        .toList();
    final selectionComplete =
        _material != null && _thickness != null && _gear != null;
    ProcessPreset? selected = selectionComplete ? _selected : null;
    if (selected != null &&
        !matches.any((preset) => preset.uuid == selected!.uuid)) {
      selected = null;
    }
    if (selectionComplete) {
      selected ??= matches.length == 1 ? matches.single : null;
    }
    final selectedPreset = selected;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 340,
            child: ListView(
              children: [
                _enumDropdown<ProcessType>(
                  label: l10n.processTypeLabel,
                  value: _processType,
                  values: ProcessType.values,
                  text: (value) => value.localizedLabel(l10n),
                  onChanged: (value) => setState(() {
                    _processType = value;
                    _material = null;
                    _thickness = null;
                    _gear = null;
                    _selected = null;
                  }),
                ),
                _enumDropdown<MaterialType>(
                  label: l10n.materialLabel,
                  value: materials.contains(_material) ? _material : null,
                  values: materials,
                  text: (value) => value.localizedLabel(l10n),
                  onChanged: (value) => setState(() {
                    _material = value;
                    _thickness = null;
                    _gear = null;
                    _selected = null;
                  }),
                ),
                _enumDropdown<double>(
                  label: useSwingWidth ? l10n.swingWidthLabel : l10n.thicknessLabel,
                  value: dimensions.contains(_thickness) ? _thickness : null,
                  values: dimensions,
                  text: (value) => '$value mm',
                  onChanged: (value) => setState(() {
                    _thickness = value;
                    _gear = null;
                    _selected = null;
                  }),
                ),
                _enumDropdown<int>(
                  label: l10n.gearLabel,
                  value: gears.contains(_gear) ? _gear : null,
                  values: gears,
                  text: (value) => '$value',
                  onChanged: (value) => setState(() {
                    _gear = value;
                    _selected = null;
                  }),
                ),
                if (matches.length > 1)
                  _enumDropdown<ProcessPreset>(
                    label: l10n.presetLabel,
                    value: _selected,
                    values: matches,
                    text: (value) => value.name,
                    onChanged: (value) => setState(() => _selected = value),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: _PresetDetails(
              preset: selectedPreset,
              emptyMessage: all.isEmpty
                  ? l10n.processLibraryNotInstalled
                  : l10n.completeSelectionToPreview,
              onApply: selectedPreset == null || controller.applying
                  ? null
                  : () => _apply(controller, selectedPreset),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEngineer(ProcessLibraryController controller) {
    final l10n = AppLocalizations.of(context)!;
    final presets =
        controller.engineerPresets(processType: _processType).toList();
    ProcessPreset? selected;
    if (_selected != null) {
      for (final preset in presets) {
        if (preset.uuid == _selected!.uuid) {
          selected = preset;
          break;
        }
      }
    }
    final selectedPreset = selected;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          SizedBox(
            width: 390,
            child: Column(
              children: [
                _enumDropdown<ProcessType>(
                  label: l10n.processTypeLabel,
                  value: _processType,
                  values: ProcessType.values,
                  text: (value) => value.localizedLabel(l10n),
                  onChanged: (value) => setState(() {
                    _processType = value;
                    _selected = null;
                  }),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: HmiButton(
                    label: l10n.newUserProcess,
                    size: HmiButtonSize.medium,
                    variant: CyberButtonVariant.primary,
                    icon: Icons.add,
                    onPressed: () => _editUser(controller),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: presets.isEmpty
                      ? Center(child: Text(l10n.noProcesses))
                      : ListView.builder(
                          itemCount: presets.length,
                          itemBuilder: (context, index) {
                            final preset = presets[index];
                            return ListTile(
                              selected: preset.uuid == selected?.uuid,
                              title: Text(preset.name),
                              subtitle: Text(
                                preset.isBuiltin ? l10n.builtInLabel : l10n.userPresetLabel,
                              ),
                              trailing: preset.isBuiltin
                                  ? const Icon(Icons.lock_outline)
                                  : null,
                              onTap: () => setState(() => _selected = preset),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
          const VerticalDivider(width: 32),
          Expanded(
            child: _PresetDetails(
              preset: selectedPreset,
              emptyMessage: l10n.selectProcessPrompt,
              onApply: selectedPreset == null || controller.applying
                  ? null
                  : () => _apply(controller, selectedPreset),
              actions: selectedPreset == null
                  ? const []
                  : [
                      HmiButton(
                        label: l10n.copyAsUserProcess,
                        size: HmiButtonSize.medium,
                        variant: CyberButtonVariant.secondary,
                        icon: Icons.copy,
                        onPressed: () async {
                          final copy =
                              await controller.copyAsUser(selectedPreset);
                          if (mounted) {
                            setState(() => _selected = copy);
                          }
                        },
                      ),
                      if (!selectedPreset.isBuiltin) ...[
                        HmiButton(
                          label: l10n.editText,
                          size: HmiButtonSize.medium,
                          variant: CyberButtonVariant.secondary,
                          icon: Icons.edit,
                          onPressed: () => _editUser(
                            controller,
                            existing: selectedPreset,
                          ),
                        ),
                        HmiButton(
                          label: l10n.deleteText,
                          size: HmiButtonSize.medium,
                          variant: CyberButtonVariant.secondary,
                          icon: Icons.delete_outline,
                          onPressed: () =>
                              _deleteUser(controller, selectedPreset),
                        ),
                      ],
                    ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _enumDropdown<T>({
    required String label,
    required T? value,
    required List<T> values,
    required String Function(T value) text,
    required ValueChanged<T> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<T>(
        key: ValueKey(value),
        initialValue: value,
        decoration: InputDecoration(labelText: label),
        items: [
          for (final item in values)
            DropdownMenuItem(value: item, child: Text(text(item))),
        ],
        onChanged: (next) {
          if (next != null) {
            onChanged(next);
          }
        },
      ),
    );
  }

  Future<void> _apply(
    ProcessLibraryController controller,
    ProcessPreset preset,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    ProcessApplyResult result;
    try {
      result = await controller.apply(preset);
    } catch (error) {
      if (mounted) {
        _message(l10n.processApplyFailedGeneric('$error'));
      }
      return;
    }
    if (!mounted) {
      return;
    }
    _message(
      result.isSuccess
          ? l10n.processAppliedVerified
          : l10n.processApplyFailedNamed(result.failure!.name),
    );
  }

  Future<void> _editUser(
    ProcessLibraryController controller, {
    ProcessPreset? existing,
  }) async {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final initial = existing ??
        ProcessPreset(
          uuid: 'new',
          name: '',
          kind: ProcessPresetKind.user,
          source: 'user',
          isBuiltin: false,
          processType: _processType,
          parameters: const ProcessParameters.empty(),
          createdAtMs: now,
          updatedAtMs: now,
        );
    final edited = await TipDialogHost.showDarkPrompt<ProcessPreset>(
      context: context,
      barrierDismissible: true,
      constraints: const BoxConstraints(
        minWidth: 560,
        maxWidth: 720,
        maxHeight: 640,
      ),
      builder: (_) => _ProcessPresetEditor(initial: initial),
    );
    if (edited == null) {
      return;
    }
    try {
      final saved = existing == null
          ? await controller.copyAsUser(edited, name: edited.name)
          : await controller.saveUser(edited);
      if (mounted) {
        setState(() => _selected = saved);
      }
    } catch (error) {
      if (mounted) {
        _message(AppLocalizations.of(context)!.processSaveFailed('$error'));
      }
    }
  }

  Future<void> _deleteUser(
    ProcessLibraryController controller,
    ProcessPreset preset,
  ) async {
    await controller.deleteUser(preset);
    if (mounted) {
      setState(() => _selected = null);
    }
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }
}

final class _PresetDetails extends StatelessWidget {
  const _PresetDetails({
    required this.preset,
    required this.emptyMessage,
    required this.onApply,
    this.actions = const [],
  });

  final ProcessPreset? preset;
  final String emptyMessage;
  final VoidCallback? onApply;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final value = preset;
    if (value == null) {
      return Center(child: Text(emptyMessage));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value.name, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(
          '${value.processType.localizedLabel(l10n)} · '
          '${value.materialName ?? value.materialType?.localizedLabel(l10n) ?? l10n.anyMaterialLabel}',
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView(
            children: [
              for (final spec in ProcessParameterCatalog.specs)
                if (value.parameters.values[spec.key] case final number?)
                  ListTile(
                    dense: true,
                    title: Text(localizedProcessParameterLabel(l10n, spec.key)),
                    trailing: Text('$number ${spec.unit}'),
                  ),
            ],
          ),
        ),
        Wrap(spacing: 12, runSpacing: 8, children: actions),
        const SizedBox(height: 12),
        HmiButton(
          label: l10n.applyToDevice,
          size: HmiButtonSize.medium,
          variant: CyberButtonVariant.primary,
          icon: Icons.send,
          onPressed: onApply,
        ),
      ],
    );
  }
}

final class _ProcessPresetEditor extends StatefulWidget {
  const _ProcessPresetEditor({required this.initial});
  final ProcessPreset initial;

  @override
  State<_ProcessPresetEditor> createState() => _ProcessPresetEditorState();
}

final class _ProcessPresetEditorState extends State<_ProcessPresetEditor> {
  late ProcessType _processType;
  MaterialType? _materialType;
  late final TextEditingController _name;
  late final TextEditingController _materialName;
  late final TextEditingController _thickness;
  late final TextEditingController _gear;
  late final Map<String, TextEditingController> _values;
  final CyberImeSession _ime = CyberImeSession.shared;

  @override
  void initState() {
    super.initState();
    _processType = widget.initial.processType;
    _materialType = widget.initial.materialType;
    _name = TextEditingController(text: widget.initial.name);
    _materialName =
        TextEditingController(text: widget.initial.materialName ?? '');
    _thickness =
        TextEditingController(text: widget.initial.thickness?.toString() ?? '');
    _gear = TextEditingController(text: widget.initial.gear?.toString() ?? '');
    _values = {
      for (final spec in ProcessParameterCatalog.specs)
        spec.key: TextEditingController(
          text: widget.initial.parameters.values[spec.key]?.toString() ?? '',
        ),
    };
  }

  @override
  void dispose() {
    _name.dispose();
    _materialName.dispose();
    _thickness.dispose();
    _gear.dispose();
    for (final controller in _values.values) {
      controller.dispose();
    }
    super.dispose();
  }

  InputDecoration _imeDecoration(String label, {String? helperText}) {
    return InputDecoration(
      labelText: label,
      helperText: helperText,
      labelStyle: const TextStyle(color: CyberColors.textSecondary),
      helperStyle: const TextStyle(color: CyberColors.textSecondary),
      enabledBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: CyberColors.textSecondary),
      ),
      focusedBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: CyberColors.textPrimary),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    const fieldStyle = TextStyle(color: CyberColors.textPrimary);
    return SizedBox(
      width: 720,
      height: 540,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.initial.name.isEmpty
                ? l10n.newUserProcess
                : l10n.editProcess,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: CyberColors.textPrimary,
              fontSize: 37,
              fontWeight: FontWeight.w700,
              height: 1.15,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              children: [
                CyberImeTextField(
                  fieldType: CyberImeFieldType.text,
                  controller: _name,
                  session: _ime,
                  style: fieldStyle,
                  decoration:
                      _imeDecoration(l10n.processNameFieldLabel),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<ProcessType>(
                  initialValue: _processType,
                  decoration: InputDecoration(
                    labelText: l10n.processTypeLabel,
                    labelStyle:
                        const TextStyle(color: CyberColors.textSecondary),
                  ),
                  dropdownColor: CyberColors.fillSolidMid,
                  style: fieldStyle,
                  items: [
                    for (final value in ProcessType.values)
                      DropdownMenuItem(
                        value: value,
                        child: Text(value.localizedLabel(l10n)),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _processType = value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<MaterialType>(
                  initialValue: _materialType,
                  decoration: InputDecoration(
                    labelText: l10n.materialLabel,
                    labelStyle:
                        const TextStyle(color: CyberColors.textSecondary),
                  ),
                  dropdownColor: CyberColors.fillSolidMid,
                  style: fieldStyle,
                  items: [
                    for (final value in MaterialType.values)
                      DropdownMenuItem(
                        value: value,
                        child: Text(value.localizedLabel(l10n)),
                      ),
                  ],
                  onChanged: (value) => setState(() => _materialType = value),
                ),
                const SizedBox(height: 12),
                CyberImeTextField(
                  fieldType: CyberImeFieldType.text,
                  controller: _materialName,
                  session: _ime,
                  style: fieldStyle,
                  decoration: _imeDecoration(l10n.customMaterialName),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: CyberImeTextField(
                        fieldType: CyberImeFieldType.signedDecimal,
                        controller: _thickness,
                        session: _ime,
                        style: fieldStyle,
                        decoration: _imeDecoration(l10n.thicknessMmLabel),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: CyberImeTextField(
                        fieldType: CyberImeFieldType.number,
                        controller: _gear,
                        session: _ime,
                        style: fieldStyle,
                        decoration: _imeDecoration(l10n.gearLabel),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                for (final spec in ProcessParameterCatalog.specs)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: CyberImeTextField(
                      fieldType: CyberImeFieldType.signedDecimal,
                      controller: _values[spec.key]!,
                      session: _ime,
                      style: fieldStyle,
                      decoration: _imeDecoration(
                        '${localizedProcessParameterLabel(l10n, spec.key)} (${spec.unit})',
                        helperText: '${spec.min} – ${spec.max}',
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          HmiDialogActions(
            cancelLabel: l10n.cancelText,
            confirmLabel: l10n.httpProxySave,
            onCancel: () => Navigator.of(context).pop(),
            onConfirm: _save,
          ),
        ],
      ),
    );
  }

  void _save() {
    final thicknessText = _thickness.text.trim();
    final gearText = _gear.text.trim();
    final thickness =
        thicknessText.isEmpty ? null : double.tryParse(thicknessText);
    final gear = gearText.isEmpty ? null : int.tryParse(gearText);
    if ((thicknessText.isNotEmpty && thickness == null) ||
        (gearText.isNotEmpty && gear == null)) {
      return;
    }
    final values = <String, num?>{};
    for (final entry in _values.entries) {
      final text = entry.value.text.trim();
      if (text.isNotEmpty) {
        final number = double.tryParse(text);
        if (number == null) {
          return;
        }
        values[entry.key] = number;
      }
    }
    Navigator.of(context).pop(
      widget.initial.copyWith(
        name: _name.text.trim(),
        processType: _processType,
        materialType: _materialType,
        materialName: _materialName.text.trim(),
        thickness: thickness,
        gear: gear,
        parameters: ProcessParameters(values),
      ),
    );
  }
}
