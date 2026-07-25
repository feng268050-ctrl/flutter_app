import 'dart:async';

import 'package:cyber_ime/cyber_ime.dart';
import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/features/process_library/application/process_library_controller.dart';
import 'package:lws_hmi/features/process_library/application/process_library_scope.dart';
import 'package:lws_hmi/features/process_library/domain/process_library_models.dart';
import 'package:lws_hmi/features/process_mode/application/device_control_controller.dart';
import 'package:lws_hmi/features/process_mode/domain/engineer_mode_draft.dart';
import 'package:lws_hmi/features/process_mode/domain/process_mode_tokens.dart';
import 'package:lws_hmi/features/process_mode/presentation/engineer_device_panel.dart';
import 'package:lws_hmi/features/process_mode/presentation/engineer_frost_panel.dart';
import 'package:lws_hmi/features/process_mode/presentation/engineer_parameter_form.dart';
import 'package:lws_hmi/features/process_mode/presentation/engineer_preset_picker_sheet.dart';
import 'package:lws_hmi/features/process_mode/presentation/engineer_process_tab_bar.dart';
import 'package:lws_hmi/features/work_mode/presentation/work_mode_status_bar.dart';
import 'package:lws_hmi/ui/cyber/cyber_ime_input_dialog.dart';

/// Engineer Mode: five tabs + left device panel + right parameter card.
final class EngineerModePage extends StatefulWidget {
  const EngineerModePage({
    super.key,
    this.initialProcessType,
    this.initialPresetUuid,
  });

  final ProcessType? initialProcessType;
  final String? initialPresetUuid;

  @override
  State<EngineerModePage> createState() => _EngineerModePageState();
}

final class _EngineerModePageState extends State<EngineerModePage> {
  late ProcessType _processType;
  EngineerModeDraft? _draft;
  String? _statusMessage;
  bool _bootstrapped = false;
  DeviceControlController? _deviceControl;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialProcessType;
    _processType =
        initial != null && EngineerProcessTabs.types.contains(initial)
            ? initial
            : ProcessType.continuousWelding;
    scheduleEnsureModbusLive(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final services = AppScope.maybeOf(context);
      if (services != null && _deviceControl == null) {
        _deviceControl = DeviceControlController(services);
        unawaited(_deviceControl!.start());
        setState(() {});
      }
      unawaited(_bootstrap());
    });
  }

  @override
  void dispose() {
    _deviceControl?.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final controller = ProcessLibraryScope.of(context);
    await controller.initialize();
    if (!mounted || _bootstrapped) {
      return;
    }
    _bootstrapped = true;
    final handoffUuid = widget.initialPresetUuid;
    if (handoffUuid != null) {
      ProcessPreset? source;
      for (final preset in controller.presets) {
        if (preset.uuid == handoffUuid) {
          source = preset;
          break;
        }
      }
      if (source != null) {
        setState(() {
          _processType = EngineerProcessTabs.types.contains(source!.processType)
              ? source.processType
              : _processType;
          _draft = EngineerModeDraft.fromQuickSource(source);
        });
        return;
      }
    }
    _selectDefaultForType(controller);
  }

  void _selectDefaultForType(ProcessLibraryController controller) {
    final presets =
        controller.engineerPresets(processType: _processType).toList();
    setState(() {
      _draft =
          presets.isEmpty ? null : EngineerModeDraft.fromLibrary(presets.first);
      _statusMessage = null;
    });
  }

  Future<void> _onProcessTypeChanged(ProcessType type) async {
    if (type == _processType) {
      return;
    }
    if (_draft?.isDirty == true) {
      final discard = await _confirmDiscard();
      if (discard != true || !mounted) {
        return;
      }
    }
    setState(() => _processType = type);
    _selectDefaultForType(ProcessLibraryScope.of(context));
  }

  Future<bool?> _confirmDiscard() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('Unsaved edits will be lost.'),
        actions: [
          TextButton(
            onPressed: () {
              CyberClickSoundRegistry.playClick();
              Navigator.pop(context, false);
            },
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              CyberClickSoundRegistry.playClick();
              Navigator.pop(context, true);
            },
            child: const Text('Discard'),
          ),
        ],
      ),
    );
  }

  Future<void> _openFavorites() async {
    final controller = ProcessLibraryScope.of(context);
    final presets =
        controller.engineerPresets(processType: _processType).toList();
    if (_draft?.isDirty == true) {
      final discard = await _confirmDiscard();
      if (discard != true || !mounted) {
        return;
      }
    }
    final selected = await showEngineerPresetPickerSheet(
      context: context,
      presets: presets,
      selectedUuid: _draft?.unsaved == true ? null : _draft?.preset.uuid,
    );
    if (selected == null || !mounted) {
      return;
    }
    setState(() {
      _draft = EngineerModeDraft.fromLibrary(selected);
      _statusMessage = null;
    });
  }

  void _onDraftChanged(ProcessPreset preset) {
    final draft = _draft;
    if (draft == null || draft.isReadOnly) {
      return;
    }
    setState(() {
      _draft = draft.copyWith(preset: preset, unsaved: true);
    });
  }

  /// Unlock built-in for editing as an in-memory user draft (no DB write yet).
  Future<ProcessPreset?> _beginEditFromBuiltin() async {
    final draft = _draft;
    if (draft == null) {
      return null;
    }
    if (!draft.isReadOnly) {
      return draft.preset;
    }
    final next = EngineerModeDraft.fromQuickSource(draft.preset);
    setState(() {
      _draft = next;
      _statusMessage = 'Editing copy — Save to keep';
    });
    return next.preset;
  }

  Future<void> _save() async {
    final draft = _draft;
    if (draft == null || draft.isReadOnly) {
      return;
    }
    final controller = ProcessLibraryScope.of(context);
    try {
      ProcessParameterValidator.validate(draft.preset);
      final ProcessPreset saved;
      if (draft.fromQuickHandoff || draft.preset.uuid.startsWith('draft-')) {
        saved = await controller.copyAsUser(
          draft.preset,
          name: draft.preset.name,
        );
      } else {
        saved = await controller.saveUser(draft.preset);
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _draft = EngineerModeDraft.fromLibrary(saved);
        _statusMessage = 'Saved';
      });
    } catch (error) {
      if (mounted) {
        setState(() => _statusMessage = 'Save failed: $error');
      }
    }
  }

  void _resetToDefault() {
    final controller = ProcessLibraryScope.of(context);
    final defaults = controller
        .engineerPresets(processType: _processType)
        .where((preset) => preset.isBuiltin)
        .toList();
    final defaultPreset = defaults.isEmpty ? null : defaults.first;
    if (defaultPreset == null) {
      setState(() => _statusMessage = 'No default process available');
      return;
    }
    setState(() {
      _draft = EngineerModeDraft.fromLibrary(defaultPreset);
      _statusMessage = 'Reset to default';
    });
  }

  Future<void> _saveAsFavorite() async {
    final draft = _draft;
    if (draft == null) {
      return;
    }
    final controller = ProcessLibraryScope.of(context);
    try {
      ProcessParameterValidator.validate(draft.preset);
      final saved = await controller.copyAsUser(
        draft.preset,
        name: draft.preset.name,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _draft = EngineerModeDraft.fromLibrary(saved);
        _statusMessage = 'Saved as favorite';
      });
    } catch (error) {
      if (mounted) {
        setState(() => _statusMessage = 'Save failed: $error');
      }
    }
  }

  Future<void> _delete() async {
    final draft = _draft;
    if (draft == null || !draft.canDelete) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete process?'),
        content: Text('Delete “${draft.preset.name}”?'),
        actions: [
          TextButton(
            onPressed: () {
              CyberClickSoundRegistry.playClick();
              Navigator.pop(context, false);
            },
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              CyberClickSoundRegistry.playClick();
              Navigator.pop(context, true);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    final controller = ProcessLibraryScope.of(context);
    await controller.deleteUser(draft.preset);
    if (!mounted) {
      return;
    }
    _selectDefaultForType(controller);
    setState(() => _statusMessage = 'Deleted');
  }

  Future<void> _editName() async {
    final draft = _draft;
    if (draft == null) {
      return;
    }
    ProcessPreset working = draft.preset;
    if (draft.isReadOnly) {
      final unlocked = await _beginEditFromBuiltin();
      if (unlocked == null || !mounted) {
        return;
      }
      working = unlocked;
    }
    final name = await showCyberImeInputDialog(
      context: context,
      title: 'Process name',
      fieldType: CyberImeFieldType.text,
      initial: working.name,
      requireNonEmpty: true,
    );
    if (name == null) {
      return;
    }
    _onDraftChanged(working.copyWith(name: name.trim()));
  }

  @override
  Widget build(BuildContext context) {
    final controller = ProcessLibraryScope.of(context);
    final draft = _draft;
    final accent = ProcessModeTokens.tabActiveColor(_processType);

    return Scaffold(
      backgroundColor: ProcessModeTokens.background,
      appBar: WorkModeStatusBar(
        mode: WorkMode.engineer,
        processType: _processType,
      ),
      body: CyberBlurBackdropScope(
        child: Stack(
          fit: StackFit.expand,
          children: [
            const CyberBlurBackdropTarget(
              child: ColoredBox(color: ProcessModeTokens.background),
            ),
            Column(
              children: [
                EngineerProcessTabBar(
                  processType: _processType,
                  onChanged: (type) => unawaited(_onProcessTypeChanged(type)),
                ),
                if (controller.loading && !controller.initialized)
                  const Expanded(
                      child: Center(child: CircularProgressIndicator()))
                else if (draft == null)
                  const Expanded(
                    child: Center(
                      child: Text(
                        'No engineer processes for this type',
                        key: ValueKey('engineer-mode-empty'),
                        style:
                            TextStyle(color: Color(0xB3FFFFFF), fontSize: 16),
                      ),
                    ),
                  ),
                if (draft != null)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            flex: 1,
                            child: SizedBox(
                              key: const ValueKey(
                                  'engineer-device-panel-container'),
                              child: _deviceControl == null
                                  ? const SizedBox.shrink()
                                  : EngineerDevicePanel(
                                      controller: _deviceControl!,
                                      processType: _processType,
                                    ),
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            flex: 2,
                            child: EngineerFrostPanel(
                              key: const ValueKey('engineer-parameters-panel'),
                              edge: EngineerFrostEdge.bottomLeftTopRight,
                              child: Column(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                        24, 16, 16, 8),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: InkWell(
                                            key: const ValueKey(
                                                'engineer-mode-name'),
                                            onTap: () {
                                              CyberClickSoundRegistry
                                                  .playClick();
                                              _editName();
                                            },
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  draft.preset.name,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  'Current Process Parameter',
                                                  key: ValueKey(
                                                    draft.fromQuickHandoff
                                                        ? 'engineer-mode-draft-uuid'
                                                        : 'engineer-mode-source-label',
                                                  ),
                                                  style: TextStyle(
                                                    color:
                                                        accent.withOpacity(0.9),
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        InkWell(
                                          key: const ValueKey(
                                              'engineer-more-favorites'),
                                          onTap: () {
                                            CyberClickSoundRegistry.playClick();
                                            _openFavorites();
                                          },
                                          child: const Padding(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 12,
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  'More Common Specs',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                                SizedBox(width: 8),
                                                Icon(
                                                  Icons.chevron_right,
                                                  color: Colors.white,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Divider(
                                    key: const ValueKey(
                                        'engineer-parameters-header-divider'),
                                    height: 2,
                                    thickness: 1,
                                    color: const Color(0x33FFFFFF),
                                    indent: 24,
                                    endIndent: 24,
                                  ),
                                  Expanded(
                                    child: EngineerParameterForm(
                                      preset: draft.preset,
                                      readOnly: draft.isReadOnly,
                                      onChanged: _onDraftChanged,
                                      onBeginEdit: _beginEditFromBuiltin,
                                    ),
                                  ),
                                  Divider(
                                    key: const ValueKey(
                                        'engineer-parameters-actions-divider'),
                                    height: 2,
                                    thickness: 1,
                                    color: const Color(0x33FFFFFF),
                                    indent: 24,
                                    endIndent: 24,
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                        16, 0, 16, 16),
                                    child: Wrap(
                                      spacing: 10,
                                      runSpacing: 8,
                                      alignment: WrapAlignment.center,
                                      children: [
                                        OutlinedButton.icon(
                                          key: const ValueKey(
                                              'engineer-action-reset-default'),
                                          onPressed: () {
                                            CyberClickSoundRegistry.playClick();
                                            _resetToDefault();
                                          },
                                          icon: const Icon(Icons.restart_alt),
                                          label: const Text('Reset to Default'),
                                        ),
                                        OutlinedButton.icon(
                                          key: const ValueKey(
                                              'engineer-action-save-favorite'),
                                          onPressed: controller.applying
                                              ? null
                                              : () {
                                                  CyberClickSoundRegistry
                                                      .playClick();
                                                  _saveAsFavorite();
                                                },
                                          icon: const Icon(Icons.bookmark_add),
                                          label: const Text('Save as Favorite'),
                                        ),
                                        if (!draft.isReadOnly)
                                          FilledButton(
                                            key: const ValueKey(
                                                'engineer-action-save'),
                                            onPressed: controller.applying
                                                ? null
                                                : () {
                                                    CyberClickSoundRegistry
                                                        .playClick();
                                                    _save();
                                                  },
                                            child: const Text('Save'),
                                          ),
                                        if (draft.canDelete)
                                          OutlinedButton(
                                            key: const ValueKey(
                                                'engineer-action-delete'),
                                            onPressed: () {
                                              CyberClickSoundRegistry
                                                  .playClick();
                                              _delete();
                                            },
                                            child: const Text('Delete'),
                                          ),
                                      ],
                                    ),
                                  ),
                                  if (_statusMessage != null)
                                    Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 12),
                                      child: Text(
                                        _statusMessage!,
                                        key: const ValueKey(
                                            'engineer-status-message'),
                                        style: const TextStyle(
                                          color: Color(0xB3FFFFFF),
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
