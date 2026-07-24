import 'package:flutter/material.dart' hide MaterialType;
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/features/process_library/application/process_library_controller.dart';
import 'package:lws_hmi/features/process_library/application/process_library_scope.dart';
import 'package:lws_hmi/features/process_library/application/process_parameter_applier.dart';
import 'package:lws_hmi/features/process_library/domain/process_library_models.dart';
import 'package:lws_hmi/features/status_bar/product_page_status_bar.dart';

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
    final controller = ProcessLibraryScope.of(context);
    final isQuick = widget.mode == ProcessLibraryPageMode.quick;
    return Scaffold(
      appBar: ProductPageStatusBar(
        title: isQuick ? 'Quick Mode' : 'Engineer Mode',
        onBack: () => Navigator.of(context).maybePop(),
      ),
      body: controller.loading && !controller.initialized
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (controller.lastError != null)
                  MaterialBanner(
                    content: Text(
                      'Process library update failed. '
                      'The last installed library is still in use.\n'
                      '${controller.lastError}',
                    ),
                    actions: [
                      TextButton(
                        onPressed: controller.initialize,
                        child: const Text('Retry'),
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
                  label: 'Process type',
                  value: _processType,
                  values: ProcessType.values,
                  text: (value) => value.label,
                  onChanged: (value) => setState(() {
                    _processType = value;
                    _material = null;
                    _thickness = null;
                    _gear = null;
                    _selected = null;
                  }),
                ),
                _enumDropdown<MaterialType>(
                  label: 'Material',
                  value: materials.contains(_material) ? _material : null,
                  values: materials,
                  text: (value) => value.label,
                  onChanged: (value) => setState(() {
                    _material = value;
                    _thickness = null;
                    _gear = null;
                    _selected = null;
                  }),
                ),
                _enumDropdown<double>(
                  label: useSwingWidth ? 'Swing width' : 'Thickness',
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
                  label: 'Gear',
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
                    label: 'Preset',
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
                  ? 'No compatible quick-mode process library is installed.'
                  : 'Complete the selection to preview parameters.',
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
                  label: 'Process type',
                  value: _processType,
                  values: ProcessType.values,
                  text: (value) => value.label,
                  onChanged: (value) => setState(() {
                    _processType = value;
                    _selected = null;
                  }),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.icon(
                    onPressed: () => _editUser(controller),
                    icon: const Icon(Icons.add),
                    label: const Text('New user process'),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: presets.isEmpty
                      ? const Center(child: Text('No processes'))
                      : ListView.builder(
                          itemCount: presets.length,
                          itemBuilder: (context, index) {
                            final preset = presets[index];
                            return ListTile(
                              selected: preset.uuid == selected?.uuid,
                              title: Text(preset.name),
                              subtitle: Text(
                                preset.isBuiltin ? 'Built-in' : 'User',
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
              emptyMessage: 'Select a process to view its parameters.',
              onApply: selectedPreset == null || controller.applying
                  ? null
                  : () => _apply(controller, selectedPreset),
              actions: selectedPreset == null
                  ? const []
                  : [
                      OutlinedButton.icon(
                        onPressed: () async {
                          final copy =
                              await controller.copyAsUser(selectedPreset);
                          if (mounted) {
                            setState(() => _selected = copy);
                          }
                        },
                        icon: const Icon(Icons.copy),
                        label: const Text('Copy as user process'),
                      ),
                      if (!selectedPreset.isBuiltin) ...[
                        OutlinedButton.icon(
                          onPressed: () => _editUser(
                            controller,
                            existing: selectedPreset,
                          ),
                          icon: const Icon(Icons.edit),
                          label: const Text('Edit'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () =>
                              _deleteUser(controller, selectedPreset),
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Delete'),
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
        value: value,
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
    ProcessApplyResult result;
    try {
      result = await controller.apply(preset);
    } catch (error) {
      if (mounted) {
        _message('Apply failed: $error');
      }
      return;
    }
    if (!mounted) {
      return;
    }
    _message(
      result.isSuccess
          ? 'Process applied and verified.'
          : 'Process was not applied: ${result.failure!.name}',
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
    final edited = await showDialog<ProcessPreset>(
      context: context,
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
        _message('Save failed: $error');
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
          '${value.processType.label} · '
          '${value.materialName ?? value.materialType?.label ?? 'Any material'}',
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView(
            children: [
              for (final spec in ProcessParameterCatalog.specs)
                if (value.parameters.values[spec.key] case final number?)
                  ListTile(
                    dense: true,
                    title: Text(spec.label),
                    trailing: Text('$number ${spec.unit}'),
                  ),
            ],
          ),
        ),
        Wrap(spacing: 12, runSpacing: 8, children: actions),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: onApply,
          icon: const Icon(Icons.send),
          label: const Text('Apply to device'),
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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
          widget.initial.name.isEmpty ? 'New user process' : 'Edit process'),
      content: SizedBox(
        width: 720,
        height: 540,
        child: ListView(
          children: [
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<ProcessType>(
              value: _processType,
              decoration: const InputDecoration(labelText: 'Process type'),
              items: [
                for (final value in ProcessType.values)
                  DropdownMenuItem(value: value, child: Text(value.label)),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _processType = value);
                }
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<MaterialType>(
              value: _materialType,
              decoration: const InputDecoration(labelText: 'Material'),
              items: [
                for (final value in MaterialType.values)
                  DropdownMenuItem(value: value, child: Text(value.label)),
              ],
              onChanged: (value) => setState(() => _materialType = value),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _materialName,
              decoration: const InputDecoration(
                labelText: 'Custom material name',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _thickness,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration:
                        const InputDecoration(labelText: 'Thickness (mm)'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _gear,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Gear'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (final spec in ProcessParameterCatalog.specs)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: TextField(
                  controller: _values[spec.key],
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: '${spec.label} (${spec.unit})',
                    helperText: '${spec.min} – ${spec.max}',
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
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
