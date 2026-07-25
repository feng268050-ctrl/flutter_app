import 'dart:async';

import 'package:cyber_ime/cyber_ime.dart';
import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/features/process_library/application/process_library_controller.dart';
import 'package:lws_hmi/features/process_library/application/process_library_scope.dart';
import 'package:lws_hmi/features/process_library/application/process_parameter_applier.dart';
import 'package:lws_hmi/features/process_library/domain/process_library_models.dart';
import 'package:lws_hmi/features/process_mode/application/device_control_controller.dart';
import 'package:lws_hmi/features/process_mode/domain/engineer_mode_draft.dart';
import 'package:lws_hmi/features/process_mode/domain/laser_enable_reminder_copy.dart';
import 'package:lws_hmi/features/process_mode/domain/process_mode_tokens.dart';
import 'package:lws_hmi/features/process_mode/presentation/engineer_device_panel.dart';
import 'package:lws_hmi/features/process_mode/presentation/engineer_favorites_popup.dart';
import 'package:lws_hmi/features/process_mode/presentation/engineer_frost_panel.dart';
import 'package:lws_hmi/features/process_mode/presentation/engineer_parameter_form.dart';
import 'package:lws_hmi/features/process_mode/presentation/engineer_process_tab_bar.dart';
import 'package:lws_hmi/features/process_mode/presentation/laser_enable_reminder_dialog.dart';
import 'package:lws_hmi/features/process_mode/presentation/process_mode_toast.dart';
import 'package:lws_hmi/features/settings/application/advanced_settings_scope.dart';
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

/// Brighter TL→BR rim for Reset / Save pills (default dark HL is 0x77).
const _engineerActionPillBorder = <Color>[
  Color(0xCCFFFFFF),
  Color(0xAA86868C),
  Color(0x66000000),
];

final class _EngineerModePageState extends State<EngineerModePage> {
  late ProcessType _processType;
  EngineerModeDraft? _draft;

  /// Per-process-type edit sessions (lws-ui `engineer_data_cache:{type}`).
  /// Survives tab switches within Engineer Mode; cleared when leaving the page.
  final Map<ProcessType, EngineerModeDraft> _sessions = {};

  final GlobalKey _moreFavoritesKey = GlobalKey();
  bool _favoritesOpen = false;

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
          _setActiveDraft(EngineerModeDraft.fromQuickSource(source));
        });
        return;
      }
    }
    _selectDefaultForType(controller);
  }

  /// Assign [_draft] and mirror into [_sessions] for the active process type.
  void _setActiveDraft(EngineerModeDraft? draft) {
    _draft = draft;
    if (draft == null) {
      _sessions.remove(_processType);
    } else {
      _sessions[_processType] = draft;
    }
  }

  void _selectDefaultForType(ProcessLibraryController controller) {
    final presets =
        controller.engineerPresets(processType: _processType).toList();
    setState(() {
      _setActiveDraft(
        presets.isEmpty ? null : EngineerModeDraft.fromLibrary(presets.first),
      );
    });
  }

  /// Switch process tab: keep each type's in-memory session (lws-ui behavior).
  Future<void> _onProcessTypeChanged(ProcessType type) async {
    if (type == _processType) {
      return;
    }
    final controller = ProcessLibraryScope.of(context);
    setState(() {
      if (_draft != null) {
        _sessions[_processType] = _draft!;
      }
      _processType = type;
      final cached = _sessions[type];
      if (cached != null) {
        _draft = cached;
        return;
      }
      final presets = controller.engineerPresets(processType: type).toList();
      _setActiveDraft(
        presets.isEmpty ? null : EngineerModeDraft.fromLibrary(presets.first),
      );
    });
  }

  Future<void> _openFavorites() async {
    final controller = ProcessLibraryScope.of(context);
    final presets =
        controller.engineerPresets(processType: _processType).toList();
    if (presets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No more favorites')),
      );
      return;
    }

    final box =
        _moreFavoritesKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) {
      return;
    }
    final origin = box.localToGlobal(Offset.zero);
    setState(() => _favoritesOpen = true);
    final selected = await showEngineerFavoritesPopup(
      context: context,
      anchor: origin & box.size,
      presets: presets,
      selectedUuid: _draft?.unsaved == true ? null : _draft?.preset.uuid,
      selectedName: _draft?.preset.name,
      processType: _processType,
    );
    if (!mounted) {
      return;
    }
    setState(() => _favoritesOpen = false);
    if (selected == null) {
      return;
    }
    setState(() {
      _setActiveDraft(EngineerModeDraft.fromLibrary(selected));
    });
  }

  void _onDraftChanged(ProcessPreset preset) {
    final draft = _draft;
    if (draft == null || draft.isReadOnly) {
      return;
    }
    setState(() {
      _setActiveDraft(draft.copyWith(preset: preset, unsaved: true));
    });
  }

  /// Safety dialog + re-apply current draft (Quick enable order parity).
  Future<bool> _beforeEnableLaser() async {
    final draft = _draft;
    if (draft == null) {
      return false;
    }
    final focusScaleRef = await _focusScaleRef();
    if (!mounted) {
      return false;
    }
    final confirmed = await showLaserEnableReminderDialog(
      context: context,
      processType: _processType,
      session: LaserEnableReminderSession.engineer,
      focusScaleRef: focusScaleRef,
    );
    if (confirmed == null || !mounted) {
      return false;
    }
    if (confirmed.dontShowAgain) {
      LaserEnableReminderGate.suppress(LaserEnableReminderSession.engineer);
    }

    final library = ProcessLibraryScope.of(context);
    final result = await library.apply(draft.preset);
    if (!mounted) {
      return false;
    }
    if (result.failure != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_applyFailureMessage(result.failure)),
          duration: const Duration(seconds: 2),
        ),
      );
      return false;
    }
    final thresholds = AdvancedSettingsScope.maybeThresholdsOf(context);
    if (thresholds != null) {
      await thresholds.commit(thresholds.values);
    }
    return true;
  }

  Future<int> _focusScaleRef() async {
    final services = AppScope.maybeOf(context);
    if (services == null) {
      return 0;
    }
    try {
      final product = await services.ensureProductInfo();
      return LaserEnableReminderCopy.parseFocusScaleRef(
        product.focusScaleRef(),
      );
    } catch (_) {
      return 0;
    }
  }

  String _applyFailureMessage(ProcessApplyFailure? failure) {
    return switch (failure) {
      ProcessApplyFailure.busy => 'Apply busy',
      ProcessApplyFailure.unsafeMachineState => 'Laser work in progress',
      ProcessApplyFailure.baselineReadFailed => 'Baseline read failed',
      ProcessApplyFailure.processWriteFailed => 'Write failed',
      ProcessApplyFailure.processReadbackFailed => 'Readback mismatch',
      ProcessApplyFailure.processTypeWriteFailed => 'Process type write failed',
      ProcessApplyFailure.processTypeReadbackFailed =>
        'Process type readback mismatch',
      ProcessApplyFailure.partialApply => 'Partial apply',
      null => 'Apply failed',
    };
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
    setState(() => _setActiveDraft(next));
    return next.preset;
  }

  Future<void> _resetToDefault() async {
    final draft = _draft;
    if (draft == null) {
      return;
    }
    // lws-ui: restore session baseline (not “first builtin in library”).
    setState(() {
      _setActiveDraft(draft.resetToBaseline());
    });
    if (!mounted) {
      return;
    }
    // lws-ui `ToastUtils.showShort(R.string.reset_data_successfully)`.
    ProcessModeToast.show(context, 'Reset complete');
  }

  Future<void> _saveAsFavorite() async {
    final draft = _draft;
    if (draft == null) {
      return;
    }
    final name = await showCyberImeInputDialog(
      context: context,
      title: 'Process Parameter Name',
      fieldType: CyberImeFieldType.text,
      initial: draft.preset.name,
      requireNonEmpty: true,
    );
    if (name == null || !mounted) {
      return;
    }
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return;
    }
    if (trimmed.length > 32) {
      ProcessModeToast.show(
        context,
        'Name must be 32 characters or fewer',
      );
      return;
    }
    final controller = ProcessLibraryScope.of(context);
    try {
      ProcessParameterValidator.validate(draft.preset);
      final named = draft.preset.copyWith(name: trimmed);
      final saved = await controller.saveAsFavorite(named, name: trimmed);
      if (!mounted) {
        return;
      }
      setState(() {
        _setActiveDraft(EngineerModeDraft.fromLibrary(saved));
      });
      // lws-ui `ToastUtils.showShort(R.string.saved_successfully)`.
      ProcessModeToast.show(context, 'Saved');
    } catch (_) {
      // Keep session draft; Save as Favorite is the only persist path.
    }
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
      body: ProcessModeToastLayer(
        child: CyberBlurBackdropScope(
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
                                      preset: draft.preset,
                                      onBeforeEnableLaser: _beforeEnableLaser,
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
                                                  'Current Process Name',
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
                                        KeyedSubtree(
                                          key: const ValueKey(
                                            'engineer-more-favorites',
                                          ),
                                          child: InkWell(
                                            key: _moreFavoritesKey,
                                            onTap: () {
                                              CyberClickSoundRegistry
                                                  .playClick();
                                              if (_favoritesOpen) {
                                                return;
                                              }
                                              _openFavorites();
                                            },
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 12,
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Text(
                                                    'More Favorites',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 2),
                                                  Icon(
                                                    _favoritesOpen
                                                        ? Icons
                                                            .keyboard_arrow_down
                                                        : Icons.chevron_right,
                                                    color: Colors.white,
                                                    size: 30,
                                                  ),
                                                ],
                                              ),
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
                                      footer: Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                          16,
                                          8,
                                          0,
                                          12,
                                        ),
                                        child: Row(
                                          children: [
                                            // lws-ui FrostButton DEFAULT
                                            // (`engineer_pine_base_btn_style`).
                                            Expanded(
                                              child: CyberButton(
                                                key: const ValueKey(
                                                  'engineer-action-reset-default',
                                                ),
                                                stretch: true,
                                                height: 56,
                                                // lws-ui FrostButtonShape.ROUNDED
                                                // (stadium) + TL→BR rim light.
                                                shape:
                                                    CyberButtonShape.rounded,
                                                borderGradientCenter:
                                                    CyberBorderGradientCenter
                                                        .topLeftBottomRight,
                                                borderGradientColors:
                                                    _engineerActionPillBorder,
                                                strokeWidth: 1.5,
                                                onPressed: _resetToDefault,
                                                child: const Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      Icons.restart_alt,
                                                      size: 20,
                                                    ),
                                                    SizedBox(width: 8),
                                                    Flexible(
                                                      child: Text(
                                                        'Reset to Default',
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 22),
                                            Expanded(
                                              child: CyberButton(
                                                key: const ValueKey(
                                                  'engineer-action-save-favorite',
                                                ),
                                                stretch: true,
                                                height: 56,
                                                shape:
                                                    CyberButtonShape.rounded,
                                                borderGradientCenter:
                                                    CyberBorderGradientCenter
                                                        .topLeftBottomRight,
                                                borderGradientColors:
                                                    _engineerActionPillBorder,
                                                strokeWidth: 1.5,
                                                onPressed: controller.applying
                                                    ? null
                                                    : _saveAsFavorite,
                                                child: const Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      Icons.bookmark_add,
                                                      size: 20,
                                                    ),
                                                    SizedBox(width: 8),
                                                    Flexible(
                                                      child: Text(
                                                        'Save as Favorite',
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
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
      ),
    );
  }
}
