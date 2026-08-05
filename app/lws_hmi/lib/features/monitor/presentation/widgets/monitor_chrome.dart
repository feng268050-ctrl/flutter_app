import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/app/theme/hmi_button_metrics.dart';
import 'package:lws_hmi/app/theme/hmi_typography.dart';
import 'package:lws_hmi/device/display_value.dart';
import 'package:lws_hmi/features/home/application/temp_series.dart';
import 'package:lws_hmi/features/home/presentation/temp_trend_arrows.dart';
import 'package:lws_hmi/features/settings/application/common_settings_scope.dart';
import 'package:lws_hmi/features/settings/application/temperature_unit_convert.dart';
import 'package:lws_hmi/features/settings/presentation/widgets/settings_chrome.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';
import 'package:lws_hmi/ui/hmi/hmi_button.dart';

/// Design tokens aligned with lws-ui Monitor / Frost glass stand-ins.
abstract final class MonitorDimens {
  static const pad = 24.0;

  /// Matches [SettingsDimens.outerAmbientExtent] — layout gutter so panel
  /// outer glow can paint without being clipped by scroll/flex ancestors.
  static const outerAmbientExtent = 20.0;

  /// Outer ambient / contact shadows: equal on all four sides (shared with
  /// [SettingsDimens] — no top-left / bottom-right directional bias).
  static const panelOuterShadowExtent = SettingsDimens.outerAmbientExtent;
  static const panelOuterShadowEdge = SettingsDimens.outerAmbientEdge;
  static const panelRim = SettingsDimens.panelRim;
  static const panelHighlight = SettingsDimens.panelHighlight;
  static const panelInnerHighlight = Color(0x30FFFFFF);
  static const panelSurfaceGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0x2EFFFFFF), Color(0x18000000)],
  );
  static const panelDepthLipShadow = SettingsDimens.depthLipShadow;
  static const panelCardShadow = SettingsDimens.cardShadow;
  static const corner = 18.0;
  static const metricH = 88.0;
  static const leftPanelW = 740.0;
  static const leftPanelH = 608.0;
  static const logPanelW = 468.0;
  static const gaugeCardW = 604.0;
  static const gaugeCardH = 344.0;
  static const gaugeSide = 220.0;
  static const tileW = 290.0;
  static const tileH = 102.0;
  static const workRingH = 250.0;
  static const aiInfoW = 360.0;

  /// Alarm / section titles → [HmiTypography.pageTitle] (28).
  static const sectionTitleSize = 28.0;

  /// Metric/comm labels → [HmiTypography.metricLabel] (20).
  static const metricLabelSize = 20.0;

  /// Temperature / metric values → [HmiTypography.metricValue] (28).
  static const metricValueSize = 28.0;

  /// lws-ui `@color/warn_text`.
  static const labelColor = Color(0xFFB0B1C2);
}

/// Monitor panel shell — same chrome as [SettingsPanel].
///
/// Under [SettingsBlurredPageShell] (see [MonitorPage]): plates use
/// [SettingsPerspectiveChrome] (tint + rim; page ImageFiltered owns σ30).
///
/// Outside that shell:
/// - [frosted] true → [SettingsPanel] capture frost.
/// - [frosted] false → keycap-style translucent light fill + border.
class MonitorGlassCard extends StatelessWidget {
  const MonitorGlassCard({
    super.key,
    required this.child,
    this.height,
    this.width,
    this.padding = const EdgeInsets.all(MonitorDimens.pad),
    this.margin,
    this.frosted = true,
    this.faceFill,
    this.borderGradientCenter = CyberBorderGradientCenter.topLeftBottomRight,
  });

  final Widget child;
  final double? height;
  final double? width;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;

  /// When false, keycap-style inset glass only (no capture frost / depth shells).
  final bool frosted;

  /// Full-bleed under-plate inside the glass clip (ignores [padding]).
  ///
  /// Use for media / preview cards so [padding] does not leave a frosted
  /// wallpaper rim (“透视边”) while outer ambient / rim depth still paint.
  final Color? faceFill;

  final CyberBorderGradientCenter borderGradientCenter;

  @override
  Widget build(BuildContext context) {
    final pagePerspective = SettingsPageBackdropBlur.maybeOf(context) != null;
    final padded = Padding(padding: padding, child: child);
    final Widget content;
    if (faceFill != null) {
      // Under-plate must fill the ClipRRect; padding applies only to [child].
      content = Stack(
        fit: StackFit.passthrough,
        children: [
          Positioned.fill(child: ColoredBox(color: faceFill!)),
          padded,
        ],
      );
    } else {
      content = padded;
    }
    final panelChild = (width != null || height != null)
        ? SizedBox(width: width, height: height, child: content)
        : content;
    final Widget body;
    if (frosted) {
      body = SettingsPanel(
        borderRadius: BorderRadius.circular(MonitorDimens.corner),
        borderGradientCenter: borderGradientCenter,
        innerShadowWidth: 0,
        outerAmbientExtent: MonitorDimens.panelOuterShadowExtent,
        outerAmbientEdge: MonitorDimens.panelOuterShadowEdge,
        depthLipOffset: Offset.zero,
        depthLipShadow: MonitorDimens.panelDepthLipShadow,
        cardShadow: MonitorDimens.panelCardShadow,
        lightFromTopLeft: false,
        rimColor: MonitorDimens.panelRim,
        lightRim: MonitorDimens.panelHighlight,
        innerHighlightWidth: 6,
        innerHighlightColor: MonitorDimens.panelInnerHighlight,
        // Ignored under SettingsBlurredPageShell ([SettingsPerspectiveChrome]).
        surfaceGradient: MonitorDimens.panelSurfaceGradient,
        blurIntensity: CyberBlurIntensity.high,
        blurSigma: 30,
        child: panelChild,
      );
    } else if (pagePerspective) {
      // Nested tile: face under content; rim above so rows cannot break stroke.
      body = Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: SettingsPerspectiveChrome.face(
              cornerRadius: MonitorDimens.corner,
              borderGradientCenter: borderGradientCenter,
            ),
          ),
          panelChild,
          Positioned.fill(
            child: SettingsPerspectiveChrome.rim(
              cornerRadius: MonitorDimens.corner,
            ),
          ),
        ],
      );
    } else {
      // IME keycap model when the page still uses per-panel frost.
      final radius = BorderRadius.circular(MonitorDimens.corner);
      body = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              CyberColors.lightFillTop,
              CyberColors.lightFillMid,
              CyberColors.lightFillBottom,
            ],
          ),
          border: Border.all(
            color: CyberColors.borderUniform,
            width: CyberDimens.borderWidth,
          ),
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: panelChild,
        ),
      );
    }
    // Stretch to the parent's max width so short labels do not shrink the
    // frost plate (Work Info data cards). Keep height optional for scroll.
    return Container(
      width: width ?? double.infinity,
      height: height,
      margin: margin,
      child: body,
    );
  }
}

/// Monitor action pill — frost plate + transparent-face [HmiButton].
///
/// Used by Alarms Clear and AI Vision Detect / Replay / Re-detect (same
/// component). [HmiButton.paintFill] is off so the [SettingsPanel] blur shows
/// through; [SettingsPanel.elevated] is off so lip/contact shadows do not read
/// as a solid embossed chip over the preview.
class MonitorFrostActionButton extends StatelessWidget {
  const MonitorFrostActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.leading,
    this.icon,
    this.size = HmiButtonSize.medium,
    this.variant = CyberButtonVariant.standard,
    this.groupIconWithLabel = false,
    this.clickSoundEnabled = true,
    this.borderGradientCenter = CyberBorderGradientCenter.topLeftBottomRight,
  });

  final String label;
  final VoidCallback? onPressed;
  final Widget? leading;
  final IconData? icon;
  final HmiButtonSize size;
  final CyberButtonVariant variant;

  /// Center icon+label as one group (Alarms Clear). Default keeps label-centered
  /// / icon left-inset layout used by other Monitor pills.
  final bool groupIconWithLabel;

  final bool clickSoundEnabled;
  final CyberBorderGradientCenter borderGradientCenter;

  /// Default pill height ([HmiButtonSize.medium]).
  static const height = 52.0;

  @override
  Widget build(BuildContext context) {
    final metrics = HmiButtonMetrics.forSize(size, context.hmiTypography);
    final radius = BorderRadius.circular(metrics.height / 2);
    return SettingsPanel(
      elevated: false,
      borderRadius: radius,
      borderGradientCenter: borderGradientCenter,
      lightFromTopLeft: false,
      rimColor: MonitorDimens.panelRim,
      lightRim: MonitorDimens.panelHighlight,
      child: HmiButton(
        label: label,
        size: size,
        variant: variant,
        shape: CyberButtonShape.rounded,
        paintFill: false,
        icon: icon,
        leading: leading,
        groupIconWithLabel: groupIconWithLabel,
        clickSoundEnabled: clickSoundEnabled,
        borderGradientCenter: borderGradientCenter,
        onPressed: onPressed,
      ),
    );
  }
}

class MonitorSectionHeader extends StatelessWidget {
  const MonitorSectionHeader(this.title, {super.key});

  final String title;

  /// Shared with Settings — [SettingsDimens.sectionDividerHeight].
  static const dividerHeight = SettingsDimens.sectionDividerHeight;

  /// lws-ui SectionHeader `dividerTopSpacing` default (`frost_dialog_content_padding`).
  static const dividerTopSpacing = 24.0;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: context.hmiTypography.pageTitle.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w400,
              height: 1.1,
            ),
          ),
          const SizedBox(height: dividerTopSpacing),
          // lws-ui `frost_divider_start_aligned`: solid mid, then fade L→R.
          const SizedBox(
            height: dividerHeight,
            width: double.infinity,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    SettingsDimens.sectionDividerColor,
                    SettingsDimens.sectionDividerColor,
                    Color(0x00000000),
                  ],
                  stops: [0.0, 0.4, 1.0],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Maps Alarm / metric cards onto Cyber status light (Icon variant).
enum MonitorIndicatorKind { idle, success, failure }

class MonitorStatusIcon extends StatelessWidget {
  const MonitorStatusIcon({super.key, required this.kind, this.size = 28});

  final MonitorIndicatorKind kind;
  final double size;

  @override
  Widget build(BuildContext context) {
    final state = switch (kind) {
      MonitorIndicatorKind.idle => CyberStatusState.idle,
      MonitorIndicatorKind.success => CyberStatusState.success,
      MonitorIndicatorKind.failure => CyberStatusState.failure,
    };
    return CyberStatusIndicator(
      state: state,
      variant: CyberStatusVariant.icon,
      size: size,
    );
  }
}

/// Machine Status tiles — Cyber status light Dot variant.
class MonitorStatusDot extends StatelessWidget {
  const MonitorStatusDot({super.key, required this.on, this.size = 28});

  final bool? on;
  final double size;

  @override
  Widget build(BuildContext context) {
    // On → green center; unknown/off → idle gray (lws-ui machine tiles).
    final state = on == true ? CyberStatusState.success : CyberStatusState.idle;
    return CyberStatusIndicator(
      state: state,
      variant: CyberStatusVariant.dot,
      size: size,
    );
  }
}

/// Alarm metric card: value above label + optional trend arrows + status icon.
class MonitorMetricCard extends StatelessWidget {
  const MonitorMetricCard({
    super.key,
    required this.value,
    required this.label,
    this.fault = false,
    this.hasValue = true,
    this.trend = TempTrend.none,
  });

  final String value;
  final String label;
  final bool fault;
  final bool hasValue;

  /// Rise/fall vs previous sample (Live Machine Status parity).
  final TempTrend trend;

  @override
  Widget build(BuildContext context) {
    // Missing sample → idle (empty); known fault → red; else green.
    final kind = !hasValue
        ? MonitorIndicatorKind.idle
        : (fault ? MonitorIndicatorKind.failure : MonitorIndicatorKind.success);
    // Same plate chrome as Alarm Log / other MonitorGlassCards (page owns σ30).
    return MonitorGlassCard(
      height: MonitorDimens.metricH,
      padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  height: 24,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        value,
                        maxLines: 1,
                        softWrap: false,
                        style: context.hmiTypography.metricValue.copyWith(
                          color: fault ? const Color(0xFFFF8A80) : Colors.white,
                          fontWeight: FontWeight.w400,
                          height: 1.1,
                        ),
                      ),
                    ),
                  ),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    label,
                    maxLines: 1,
                    softWrap: false,
                    style: context.hmiTypography.metricLabel.copyWith(
                      color: MonitorDimens.labelColor,
                      fontWeight: FontWeight.w400,
                      height: 1.15,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Same size/colors as Live Machine Status (“更多监测”).
          if (hasValue && trend != TempTrend.none) ...[
            const SizedBox(width: 6),
            TempTrendArrows(trend: trend),
            const SizedBox(width: 6),
          ],
          MonitorStatusIcon(kind: kind),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

/// Comm-status row card (label + icon).
class MonitorCommCard extends StatelessWidget {
  const MonitorCommCard({
    super.key,
    required this.label,
    required this.kind,
  });

  final String label;
  final MonitorIndicatorKind kind;

  @override
  Widget build(BuildContext context) {
    // Same plate chrome as Alarm Log (page owns σ30; no panel BackdropFilter).
    // Idle → muted label; pass → white; fault → warn red (same as temp value).
    final labelColor = switch (kind) {
      MonitorIndicatorKind.idle => MonitorDimens.labelColor,
      MonitorIndicatorKind.success => Colors.white,
      MonitorIndicatorKind.failure => const Color(0xFFFF8A80),
    };
    return MonitorGlassCard(
      height: MonitorDimens.metricH,
      padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
      child: Row(
        children: [
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                label,
                maxLines: 1,
                softWrap: false,
                style: context.hmiTypography.metricLabel.copyWith(
                  color: labelColor,
                  fontWeight: FontWeight.w400,
                  height: 1.15,
                ),
              ),
            ),
          ),
          MonitorStatusIcon(kind: kind),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

class MonitorTempMetricCard extends StatelessWidget {
  const MonitorTempMetricCard({
    super.key,
    required this.series,
    required this.label,
    required this.overTemp,
  });

  final TempSeries series;
  final String label;
  final bool overTemp;

  @override
  Widget build(BuildContext context) {
    final common = CommonSettingsScope.maybeOf(context);
    final l10n = AppLocalizations.of(context);

    Widget card() {
      final unit = common?.unit;
      final hasValue = series.lastCelsius != null;
      final String value;
      if (overTemp && !hasValue) {
        value = l10n?.overTempLabel ?? 'Over Temp';
      } else if (hasValue) {
        value = TemperatureUnitConvert.formatSensorCelsius(
          series.lastCelsius!,
          unit,
        );
      } else {
        value = kUnavailableDisplay;
      }
      return MonitorMetricCard(
        value: value,
        label: label,
        fault: overTemp,
        hasValue: hasValue || overTemp,
        trend: hasValue ? series.trend : TempTrend.none,
      );
    }

    if (common == null) {
      return card();
    }
    return ListenableBuilder(
      listenable: common,
      builder: (context, _) => card(),
    );
  }
}

class MonitorHealthBanner extends StatelessWidget {
  const MonitorHealthBanner({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = CyberGlassTheme.of(context);
    return CyberOutlinedPanel(
      clipBehavior: Clip.antiAlias,
      outline: CyberPanelOutline(
        style: CyberPanelOutlineStyle.uniform,
        tone: theme.tone,
        width: 1.0,
        cornerRadius: 12,
        uniformColor: CyberColors.borderUniform,
      ),
      color: Colors.white.withOpacity(0.06),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message?.trim().isNotEmpty == true
                    ? message!
                    : l10n.modbusCommunicationFault,
                style: context.hmiTypography.body.copyWith(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MonitorAlarmLogRow extends StatelessWidget {
  const MonitorAlarmLogRow({
    super.key,
    required this.code,
    required this.label,
    this.timestamp,
  });

  final String code;
  final String label;
  final DateTime? timestamp;

  /// lws-ui `item_warn_log` / `#FF0000`.
  static const titleRed = Color(0xFFFF0000);

  /// Row siren (lws-ui `warn_icon`).
  static const iconAsset = 'assets/warn/warn_icon.webp';

  @override
  Widget build(BuildContext context) {
    final time = timestamp;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 8, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 6, right: 6),
                child: Image.asset(
                  iconAsset,
                  width: 24,
                  height: 24,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.medium,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.warning_amber_rounded,
                    size: 24,
                    color: titleRed,
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '$code $label',
                    style: context.hmiTypography.sectionTitle.copyWith(
                      color: titleRed,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (time != null)
            Padding(
              padding: const EdgeInsets.only(left: 30, top: 2),
              child: Text(
                _formatTime(time.toLocal()),
                style: context.hmiTypography.sectionTitle.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w400,
                  height: 1.2,
                ),
              ),
            ),
          const SizedBox(height: 10),
          const Divider(
            height: SettingsDimens.sectionDividerHeight,
            thickness: SettingsDimens.sectionDividerHeight,
            color: SettingsDimens.sectionDividerColor,
          ),
        ],
      ),
    );
  }

  static String _formatTime(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${t.year}-${two(t.month)}-${two(t.day)} '
        '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
  }
}

class MonitorStatusTile extends StatelessWidget {
  const MonitorStatusTile({
    super.key,
    required this.label,
    this.on,
    this.height,
    this.borderGradientCenter = CyberBorderGradientCenter.topLeftBottomRight,
  });

  final String label;
  final bool? on;
  final double? height;
  final CyberBorderGradientCenter borderGradientCenter;

  @override
  Widget build(BuildContext context) {
    return MonitorGlassCard(
      height: height ?? MonitorDimens.tileH,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      borderGradientCenter: borderGradientCenter,
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.hmiTypography.settingsRowTitle.copyWith(color: Colors.white),
            ),
          ),
          MonitorStatusDot(on: on),
        ],
      ),
    );
  }
}

class MonitorWorkDataCard extends StatelessWidget {
  const MonitorWorkDataCard({
    super.key,
    required this.title,
    required this.value,
    this.suffix = '',
    this.borderGradientCenter = CyberBorderGradientCenter.topLeftBottomRight,
  });

  final String title;
  final String value;
  final String suffix;
  final CyberBorderGradientCenter borderGradientCenter;

  @override
  Widget build(BuildContext context) {
    return MonitorGlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      borderGradientCenter: borderGradientCenter,
      // Expand so SettingsPanel frost fills the Expanded cell; FittedBox alone
      // would shrink the plate to the short title/value intrinsic width.
      child: SizedBox.expand(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final tight = constraints.maxHeight < 140;
            // Work Info tab: +2 over prior 16/22, 28/40, 16/24.
            final titleSize = tight ? 18.0 : 24.0;
            final valueSize = tight ? 30.0 : 42.0;
            final suffixSize = tight ? 18.0 : 26.0;
            return Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: constraints.maxWidth),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: titleSize,
                        ),
                      ),
                      SizedBox(height: tight ? 6 : 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            value,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: valueSize,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (suffix.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Padding(
                              padding: EdgeInsets.only(bottom: tight ? 2 : 6),
                              child: Text(
                                suffix,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: suffixSize,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
