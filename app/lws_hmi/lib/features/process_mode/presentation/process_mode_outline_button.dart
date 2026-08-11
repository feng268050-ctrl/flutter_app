import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/app/theme/hmi_button_metrics.dart';
import 'package:lws_hmi/app/theme/hmi_text_scale.dart';
import 'package:lws_hmi/app/theme/hmi_typography.dart';
import 'package:lws_hmi/features/process_mode/application/device_control_controller.dart';
import 'package:lws_hmi/features/process_mode/domain/device_control_feedback_copy.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';
import 'package:lws_hmi/features/process_mode/domain/device_control_ids.dart';
import 'package:lws_hmi/features/process_mode/presentation/feed_hold_progress.dart';
import 'package:lws_hmi/features/process_mode/presentation/manual_wire_gesture.dart';
import 'package:lws_hmi/ui/hmi/hmi_adaptive_icon_label.dart';

/// Engineer Retract/Feed outline chrome — reused by Quick Mode side ops.
///
/// Visual: orange rim, dark fill; filled orange + white label when active.
/// Face size / type / icon tokens alias [HmiButtonMetrics] + [HmiTypography]
/// (not a second ladder of magic numbers).
abstract final class ProcessModeOutlineChrome {
  static const Color actionOrange = Color(0xFFF46E01);
  static const Color idleFill = Color(0xFF2C1923);
  static const Color disabledForeground = Color(0xFF7D3E2B);

  /// Quick side ops / Engineer Feed·Retract layout slot — [HmiButtonSize.hero].
  static const double labelSize = HmiTypography.buttonHeroFontSize;
  static const double iconSize = HmiButtonMetrics.heroIconSize;
  static const double defaultHeight = HmiButtonMetrics.heroHeight;

  /// Engineer Feed / Retract glyph only; layout slot stays [iconSize] so
  /// edge insets and row geometry do not shift.
  static const double engineerWireIconVisualSize = 28.0;

  /// Engineer Enable Laser (filled) — [HmiButtonSize.jumbo].
  static const double laserEnableHeight = HmiButtonMetrics.jumboHeight;
  static const double laserEnableLabelSize = HmiTypography.buttonJumboFontSize;
  static const double laserEnableIconSize = HmiButtonMetrics.jumboIconSize;

  static const double iconLabelGap = HmiIconLabelLayout.iconLabelGap;

  /// Clearance between fixed-left icon and label when label is nudged right
  /// (Quick Manual Gas / Feed / Retract). Auto Wire Feed uses [noIconLabelClearance].
  static const double iconLabelClearance = 3.0;
  static const double noIconLabelClearance = 0.0;

  static const double radius = 14.0;
  static const double strokeWidth = 1.5;
}

/// Tap outline button (Quick Manual Gas / Auto Wire).
final class ProcessModeOutlineButton extends StatelessWidget {
  const ProcessModeOutlineButton({
    super.key,
    required this.label,
    required this.leading,
    required this.selected,
    required this.enabled,
    required this.onPressed,
    this.height = ProcessModeOutlineChrome.defaultHeight,
    this.iconLabelClearance = ProcessModeOutlineChrome.iconLabelClearance,
  });

  final String label;
  final Widget leading;
  final bool selected;
  final bool enabled;
  final VoidCallback? onPressed;
  final double height;
  final double iconLabelClearance;

  @override
  Widget build(BuildContext context) {
    final highlight = enabled && selected;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled
              ? () {
                  CyberClickSoundRegistry.playClick();
                  onPressed?.call();
                }
              : null,
          borderRadius: BorderRadius.circular(ProcessModeOutlineChrome.radius),
          child: Opacity(
            opacity: enabled ? 1 : 0.55,
            child: _OutlineFace(
              height: height,
              highlight: highlight,
              enabled: enabled,
              leading: leading,
              label: label,
              iconLabelClearance: iconLabelClearance,
            ),
          ),
        ),
      ),
    );
  }
}

/// Hold/pulse Feed·Retract — same face as Engineer `_EngineerWireActionButton`.
final class ProcessModeOutlineWireButton extends StatefulWidget {
  const ProcessModeOutlineWireButton({
    super.key,
    required this.label,
    required this.leading,
    required this.enabled,
    required this.laserBlocked,
    required this.retract,
    required this.active,
    required this.controller,
    required this.onMessage,
    this.height = ProcessModeOutlineChrome.defaultHeight,
    this.latchedLabel,
  });

  final String label;
  final Widget leading;
  final bool enabled;
  final bool laserBlocked;
  final bool retract;
  final bool active;
  final DeviceControlController controller;
  final ValueChanged<String> onMessage;
  final double height;
  final String? latchedLabel;

  @override
  State<ProcessModeOutlineWireButton> createState() =>
      _ProcessModeOutlineWireButtonState();
}

final class _ProcessModeOutlineWireButtonState
    extends State<ProcessModeOutlineWireButton>
    with SingleTickerProviderStateMixin {
  late final ManualWireGesture _gesture = ManualWireGesture(
    controller: widget.controller,
    retract: widget.retract,
    isEnabled: () => widget.enabled,
    isActive: () => widget.active,
    onMessage: widget.onMessage,
    onVisualChanged: _onGestureVisual,
    l10n: () => AppLocalizations.of(context)!,
  );

  FeedHoldProgressController? _feedProgress;
  bool _wasLatched = false;

  @override
  void initState() {
    super.initState();
    if (!widget.retract) {
      _feedProgress = FeedHoldProgressController(
        vsync: this,
        onChanged: () {
          if (mounted) {
            setState(() {});
          }
        },
        onFillCompleted: () {
          if (!mounted) {
            return;
          }
          // Align continuous-feed latch with fill reaching 1.
          _gesture.promoteContinuousFeedIfHolding();
        },
      );
    }
  }

  void _onGestureVisual() {
    if (!mounted) {
      return;
    }
    final progress = _feedProgress;
    if (progress != null) {
      final latched = _gesture.latched;
      if (latched && !_wasLatched) {
        progress.onLatched();
      } else if (!latched && _wasLatched) {
        progress.reset();
      }
      _wasLatched = latched;
    }
    setState(() {});
  }

  @override
  void dispose() {
    _feedProgress?.dispose();
    _gesture.dispose();
    super.dispose();
  }

  void _pointerDown() {
    if (!widget.enabled) {
      return;
    }
    if (widget.controller.busy) {
      widget.onMessage(
        LaserEnableBlockReason.busy.localizedMessage(
          AppLocalizations.of(context)!,
        ),
      );
      return;
    }
    if (widget.laserBlocked) {
      widget.onMessage(DeviceControlFeedbackCopy.endOfWorkFirst(
          AppLocalizations.of(context)!));
      return;
    }
    CyberClickSoundRegistry.playClick();
    final progress = _feedProgress;
    // Tap-to-stop continuous feed: no new fill; gesture handles stop on up.
    if (progress != null && !_gesture.latched && !widget.active) {
      progress.onPressStart();
    }
    _gesture.pointerDown();
  }

  void _pointerUp() {
    if (!widget.enabled || widget.controller.busy || widget.laserBlocked) {
      return;
    }
    final wasLatched = _gesture.latched;
    _gesture.pointerUp();
    final progress = _feedProgress;
    if (progress == null) {
      return;
    }
    if (wasLatched || _gesture.latched) {
      // Continuous feed: solid face; do not reverse fill.
      return;
    }
    progress.onPressEndEarly();
  }

  @override
  Widget build(BuildContext context) {
    // Continuous feed (latched): solid bright orange stays after release.
    final latched = !widget.retract && _gesture.latched;
    final progress = _feedProgress;
    final filling = progress != null && progress.showsFill;
    // Feed: Retract-like pressed solid until L→R fill starts (≥200ms); idle
    // chrome while filling; solid when latched / continuous. Retract: pressed.
    final solidHighlight = widget.enabled &&
        (widget.retract
            ? (widget.active || _gesture.pressed || _gesture.holdingRun)
            : (latched ||
                (_gesture.pressed && !filling) ||
                (widget.active && !filling && !_gesture.pressed)));
    final l10n = AppLocalizations.of(context)!;
    final label = latched
        ? (widget.latchedLabel ??
            DeviceControlFeedbackCopy.continuousFeedLabel(l10n))
        : widget.label;

    return Semantics(
      button: true,
      enabled: widget.enabled,
      label: label,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (_) => _pointerDown(),
        onPointerUp: (_) => _pointerUp(),
        onPointerCancel: (_) => _pointerUp(),
        child: Opacity(
          opacity: widget.enabled ? 1 : 0.55,
          child: _OutlineFace(
            height: widget.height,
            highlight: solidHighlight,
            enabled: widget.enabled,
            leading: widget.leading,
            label: label,
            progress: filling ? progress.value : 0,
            progressForcesReadableLabel: filling,
            continuousRipple: latched,
            // Continuous Feed chrome: label only (no leading icon).
            showLeading: !latched,
          ),
        ),
      ),
    );
  }
}

final class _OutlineFace extends StatelessWidget {
  const _OutlineFace({
    required this.height,
    required this.highlight,
    required this.enabled,
    required this.leading,
    required this.label,
    this.progress = 0,
    this.progressForcesReadableLabel = false,
    this.continuousRipple = false,
    this.showLeading = true,
    this.iconLabelClearance = ProcessModeOutlineChrome.iconLabelClearance,
  });

  final double height;
  final bool highlight;
  final bool enabled;
  final Widget leading;
  final String label;
  final double progress;
  final bool progressForcesReadableLabel;
  final bool continuousRipple;
  final bool showLeading;
  final double iconLabelClearance;

  @override
  Widget build(BuildContext context) {
    final onFill = highlight || progressForcesReadableLabel;
    final foreground = !enabled
        ? ProcessModeOutlineChrome.disabledForeground
        : (onFill ? Colors.white : ProcessModeOutlineChrome.actionOrange);
    final style = TextStyle(
      color: foreground,
      fontSize: ProcessModeOutlineChrome.labelSize,
      fontWeight: FontWeight.w600,
      height: 1.0,
    );
    const iconSize = ProcessModeOutlineChrome.iconSize;
    final edgeInset = ((height - iconSize) / 2).clamp(0.0, height);
    final tintedLeading = ColorFiltered(
      colorFilter: ColorFilter.mode(foreground, BlendMode.srcIn),
      child: leading,
    );
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(ProcessModeOutlineChrome.radius),
        color: highlight
            ? ProcessModeOutlineChrome.actionOrange
            : ProcessModeOutlineChrome.idleFill,
        border: Border.all(
          color: ProcessModeOutlineChrome.actionOrange,
          width: ProcessModeOutlineChrome.strokeWidth,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(ProcessModeOutlineChrome.radius),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (progress > 0)
              FeedHoldProgressFill(
                progress: progress,
                radius: ProcessModeOutlineChrome.radius,
                color: ProcessModeOutlineChrome.actionOrange,
              ),
            if (continuousRipple) const FeedContinuousRipple(),
            // Product rule: Quick Manual Gas / Auto Wire Feed / Feed / Retract
            // stay at the Medium label size for every user text-size tier.
            HmiFixedTextScale(
              child: HmiAdaptiveIconLabel(
                label: label,
                style: style,
                iconSize: iconSize,
                buttonHeight: height,
                horizontalPadding: edgeInset,
                leading: showLeading ? tintedLeading : null,
                // Label on button center; icon fixed. Long labels nudge right
                // with [iconLabelClearance] then ellipsis; L/R chrome equal.
                forceLabelCentered: true,
                minimumGap: iconLabelClearance,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
