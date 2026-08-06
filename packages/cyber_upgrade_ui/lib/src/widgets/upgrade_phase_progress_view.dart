import 'package:cyber_ui/cyber_ui.dart';
import 'package:cyber_upgrade_ui/src/domain/upgrade_phase.dart';
import 'package:cyber_upgrade_ui/src/domain/upgrade_progress.dart';
import 'package:flutter/material.dart';

/// Multi-phase (or single-phase) upgrade progress body.
class UpgradePhaseProgressView extends StatelessWidget {
  const UpgradePhaseProgressView({
    super.key,
    required this.phases,
    required this.progress,
    this.statusLabel,
    this.showPhaseList = false,
    this.compact = false,
    this.titleStyle,
    this.percentStyle,
    this.phaseListStyle,
    this.barColor = CyberColors.buttonPrimaryFill,
    this.barBackgroundColor,
    this.barHeight = 10,
    this.percentLabel,
    this.footer,
  });

  final List<UpgradePhase> phases;
  final UpgradeProgress progress;

  /// Optional App-localized status line (overrides active phase [label]).
  final String? statusLabel;

  /// When true, list all phases and highlight the active one.
  final bool showPhaseList;

  /// Dialog-friendly layout without vertical [Spacer]s.
  final bool compact;

  final TextStyle? titleStyle;
  final TextStyle? percentStyle;
  final TextStyle? phaseListStyle;

  final Color barColor;
  final Color? barBackgroundColor;
  final double barHeight;

  /// Optional override for the percent line (e.g. localized `42%`).
  final String? percentLabel;

  /// Optional trailing controls (e.g. Close on failure).
  final Widget? footer;

  UpgradePhase? get _active {
    for (final p in phases) {
      if (p.id == progress.activePhaseId) {
        return p;
      }
    }
    return phases.isEmpty ? null : phases.first;
  }

  @override
  Widget build(BuildContext context) {
    final active = _active;
    final title = (statusLabel != null && statusLabel!.trim().isNotEmpty)
        ? statusLabel!.trim()
        : (active?.label ?? '');

    final showBar = !progress.indeterminate &&
        !progress.isTerminalOk &&
        !progress.isTerminalFail &&
        progress.percent != null;
    final showSpinner = progress.indeterminate &&
        !progress.isTerminalOk &&
        !progress.isTerminalFail;

    final titleTextStyle = titleStyle ??
        const TextStyle(
          color: CyberColors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        );
    final secondary = percentStyle ??
        const TextStyle(
          color: CyberColors.textSecondary,
          fontSize: 16,
        );

    return Column(
      mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!compact) const Spacer(),
        if (title.isNotEmpty)
          Text(
            title,
            textAlign: TextAlign.center,
            style: titleTextStyle,
          ),
        if (showPhaseList && phases.length > 1) ...[
          const SizedBox(height: 16),
          ...phases.map((phase) {
            final activePhase = phase.id == progress.activePhaseId;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                phase.label,
                textAlign: TextAlign.center,
                style: (phaseListStyle ?? secondary).copyWith(
                  color: activePhase
                      ? CyberColors.textPrimary
                      : CyberColors.textSecondary,
                  fontWeight:
                      activePhase ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            );
          }),
        ],
        if (showBar) ...[
          SizedBox(height: title.isNotEmpty ? 24 : 0),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress.clampedPercent / 100.0,
              minHeight: barHeight,
              backgroundColor: barBackgroundColor ??
                  CyberColors.textSecondary.withValues(alpha: 0.25),
              color: barColor,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            percentLabel ?? '${progress.clampedPercent}%',
            textAlign: TextAlign.center,
            style: secondary,
          ),
        ] else if (showSpinner) ...[
          const SizedBox(height: 28),
          Center(
            child: SizedBox(
              width: 36,
              height: 36,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: barColor,
              ),
            ),
          ),
        ],
        if (progress.isTerminalFail &&
            (progress.errorMessage?.isNotEmpty ?? false)) ...[
          const SizedBox(height: 16),
          Text(
            progress.errorMessage!,
            textAlign: TextAlign.center,
            style: secondary,
          ),
        ],
        if (footer != null) ...[
          const SizedBox(height: 24),
          footer!,
        ],
        if (!compact) const Spacer(),
      ],
    );
  }
}
