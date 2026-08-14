import 'dart:async';

import 'package:cyber_hal/input.dart';
import 'package:cyber_ime/cyber_ime.dart';
import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:os_settings/app/os_settings_app.dart';
import 'package:os_settings/chrome/settings_chrome.dart';
import 'package:os_settings/l10n/app_localizations.dart';
import 'package:os_settings/util/keyboard_profile.dart';

/// Keyboard — soft layout Segment + Apply (os-settings seat only).
class KeyboardPage extends StatefulWidget {
  const KeyboardPage({super.key});

  @override
  State<KeyboardPage> createState() => _KeyboardPageState();
}

class _KeyboardPageState extends State<KeyboardPage> {
  KeyboardProfile _selected = KeyboardProfile.qwerty;
  KeyboardProfile _applied = KeyboardProfile.qwerty;
  String _presence = '…';
  bool _busy = false;
  bool _physicalEnabled = true;
  Timer? _poll;
  final _testCtrl = TextEditingController();
  final _testFocus = FocusNode(debugLabel: 'KeyboardTestField');
  final _testFieldKey = GlobalKey();
  final _scrollCtrl = ScrollController();
  final _ime = CyberImeSession.shared;

  Keyboard get _keyboard => OsSettingsScope.of(context).keyboard();

  PhysicalInputPolicy get _inputPolicy =>
      OsSettingsScope.of(context).physicalInputPolicy();

  void _syncSoftKeyboardLayout(CyberImeRegionalProfile profile) {
    final regional = CyberImeRegionalLayoutRegistry.provider;
    if (regional is CyberImeMutableRegionalLayoutProvider) {
      regional.profile = profile;
    }
  }

  @override
  void initState() {
    super.initState();
    _testFocus.addListener(_ensureTestFieldVisible);
    _ime.keyboardHeightListenable.addListener(_ensureTestFieldVisible);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_load());
      unawaited(_refreshPresence());
    });
    _poll = Timer.periodic(const Duration(seconds: 3), (_) {
      unawaited(_refreshPresence());
    });
  }

  Widget _buildTestInputField(AppLocalizations l10n) {
    return SettingsRowFrame(
      key: _testFieldKey,
      clickSoundEnabled: false,
      child: CyberImeTextField(
        fieldType: CyberImeFieldType.text,
        controller: _testCtrl,
        focusNode: _testFocus,
        style: SettingsTextStyles.title,
        decoration: InputDecoration(
          hintText: l10n.keyboardTestHint,
          hintStyle: SettingsTextStyles.supporting,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }

  Widget _buildTestInputCard(AppLocalizations l10n) {
    final row = _buildTestInputField(l10n);
    final radius =
        BorderRadius.circular(CyberGlassTheme.of(context).cornerRadius);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        SettingsDimens.inset,
        0,
        SettingsDimens.inset,
        SettingsDimens.inset,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          color: const Color(0xFF101012),
          border: Border.all(color: SettingsDimens.cardBorder),
          boxShadow: SettingsPerspectiveChrome.cardShadow,
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: row,
        ),
      ),
    );
  }

  void _ensureTestFieldVisible() {
    if (!_testFocus.hasFocus && _ime.keyboardHeight <= 0) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctx = _testFieldKey.currentContext;
      if (ctx == null) return;
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        alignment: 0.2,
      );
    });
  }

  Future<void> _load() async {
    try {
      final flags = await _inputPolicy.readFlags();
      final layout = await _keyboard.getLayout();
      final profile = KeyboardProfile.fromLayout(layout);
      if (!mounted) return;
      setState(() {
        _physicalEnabled = flags.keyboardEnabled;
        _selected = profile;
        _applied = profile;
      });
      _syncSoftKeyboardLayout(profile.imeProfile);
    } catch (e) {
      debugPrint('keyboard: load failed: $e');
    }
  }

  Future<void> _refreshPresence() async {
    final l10n = AppLocalizations.of(context);
    final notDetected = l10n?.keyboardNotDetected ?? 'Not detected';
    final offLabel = l10n?.offLabel ?? 'Off';
    if (!_physicalEnabled) {
      if (!mounted) return;
      setState(() => _presence = offLabel);
      return;
    }
    try {
      final line = await const UsbHidKeyboardProbe().statusLine();
      if (!mounted) return;
      setState(() => _presence = line ?? notDetected);
    } catch (_) {
      if (!mounted) return;
      setState(() => _presence = notDetected);
    }
  }

  Future<void> _setPhysicalEnabled(bool enabled) async {
    if (_busy) return;

    setState(() => _busy = true);
    try {
      final flags = await _inputPolicy.readFlags();
      await _inputPolicy.applyFlags(
        flags.copyWith(keyboardEnabled: enabled),
      );
      if (!mounted) return;
      setState(() => _physicalEnabled = enabled);
      await _keyboard.restartToApply();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _apply() async {
    if (_busy) return;
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await CyberOverlayHost.show<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return CyberPromptContent(
          title: l10n.keyboardApplyConfirmTitle,
          body: Text(
            l10n.keyboardApplyConfirmOsBody,
            textAlign: TextAlign.center,
          ),
          actions: [
            CyberButton(
              variant: CyberButtonVariant.primary,
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.wifiApply),
            ),
            const SizedBox(height: 8),
            CyberButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancelText),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await _keyboard.setLayout(_selected.xkbLayout, restart: false);
      _syncSoftKeyboardLayout(_selected.imeProfile);
      if (!mounted) return;
      await _showApplySuccessTip();
      if (!mounted) return;
      await _keyboard.restartToApply();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.wifiApply}: $e')),
        );
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _showApplySuccessTip() async {
    final l10n = AppLocalizations.of(context)!;
    Timer? autoDismiss;
    try {
      await CyberOverlayHost.show<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          autoDismiss ??= Timer(const Duration(milliseconds: 1500), () {
            if (dialogContext.mounted &&
                ModalRoute.of(dialogContext)?.isCurrent == true) {
              Navigator.of(dialogContext).pop();
            }
          });
          return CyberPromptContent(
            title: l10n.keyboardApplySuccessTitle,
            body: Text(
              l10n.keyboardApplySuccessBody,
              textAlign: TextAlign.center,
            ),
            actions: [
              CyberButton(
                variant: CyberButtonVariant.primary,
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(l10n.confirmText),
              ),
            ],
          );
        },
      );
    } finally {
      autoDismiss?.cancel();
    }
  }

  @override
  void dispose() {
    _testFocus.removeListener(_ensureTestFieldVisible);
    _ime.keyboardHeightListenable.removeListener(_ensureTestFieldVisible);
    _poll?.cancel();
    _testFocus.dispose();
    _scrollCtrl.dispose();
    _testCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final dirty = _selected != _applied;
    return SettingsScaffold(
      title: l10n.keyboardText,
      body: SettingsScrollView(
        controller: _scrollCtrl,
        children: [
          SettingsGroup(
            bottomInset: SettingsDimens.inset,
            borderGradientCenter: CyberBorderGradientCenter.topLeftBottomRight,
            children: [
              CyberImeLayoutChooser(
                selected: _selected.imeProfile,
                enabled: !_busy,
                showDisplayName: false,
                showPreview: false,
                showFootnote: false,
                segmentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                onSelected: (p) {
                  CyberClickSoundRegistry.playClick();
                  final profile = KeyboardProfile.fromConfProfile(p.confId);
                  setState(() => _selected = profile);
                  _syncSoftKeyboardLayout(profile.imeProfile);
                },
              ),
            ],
          ),
          _KeyboardLayoutPreviewSection(
            profile: _selected.imeProfile,
            previewCaption: l10n.previewLabel,
            applyLabel: l10n.wifiApply,
            applyEnabled: !_busy && dirty,
            onApply: () => unawaited(_apply()),
          ),
          SettingsHelpFooter(
            l10n.keyboardLayoutHelpOs,
            bottomInset: 0,
          ),
          SettingsSectionHeader(l10n.keyboardTestSection),
          CyberKeyboardAvoidingLift(
            keyboardHeight: _ime.keyboardHeightListenable,
            child: _buildTestInputCard(l10n),
          ),
          SettingsSectionHeader(l10n.keyboardPhysicalSection),
          SettingsGroup(
            bottomInset: 0,
            borderGradientCenter: CyberBorderGradientCenter.bottomLeftTopRight,
            children: [
              SettingsSwitchRow(
                title: l10n.physicalKeyboardEnableLabel,
                value: _physicalEnabled,
                onChanged: _busy
                    ? null
                    : (v) => unawaited(_setPhysicalEnabled(v)),
              ),
              if (_physicalEnabled)
                SettingsValueRow(
                  title: l10n.cameraStatus,
                  value: _presence,
                ),
            ],
          ),
          if (!_physicalEnabled)
            SettingsHelpFooter(l10n.physicalKeyboardPolicyOffHelp),
        ],
      ),
    );
  }
}

class _KeyboardLayoutPreviewSection extends StatelessWidget {
  const _KeyboardLayoutPreviewSection({
    required this.profile,
    required this.previewCaption,
    required this.applyLabel,
    required this.applyEnabled,
    required this.onApply,
  });

  final CyberImeRegionalProfile profile;
  final String previewCaption;
  final String applyLabel;
  final bool applyEnabled;
  final VoidCallback onApply;

  String _footnote(AppLocalizations l10n) => switch (profile) {
        CyberImeRegionalProfile.qwertz ||
        CyberImeRegionalProfile.azerty =>
          l10n.keyboardLongPressAccentHint,
        CyberImeRegionalProfile.qwerty => '',
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final footnote = _footnote(l10n);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        SettingsDimens.inset,
        0,
        SettingsDimens.inset,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  previewCaption,
                  style: SettingsTextStyles.supporting.copyWith(
                    color: Colors.white54,
                  ),
                ),
              ),
              CyberButton(
                variant: CyberButtonVariant.primary,
                onPressed: applyEnabled ? onApply : null,
                child: Text(applyLabel),
              ),
            ],
          ),
          const SizedBox(height: 8),
          CyberImeLayoutPreviewCard(
            profile: profile,
            previewCaption: '',
            captionStyle: SettingsTextStyles.supporting.copyWith(
              color: Colors.white54,
            ),
          ),
          if (footnote.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
              child: Text(
                footnote,
                style: SettingsTextStyles.supporting.copyWith(
                  color: Colors.white54,
                  height: 1.35,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
