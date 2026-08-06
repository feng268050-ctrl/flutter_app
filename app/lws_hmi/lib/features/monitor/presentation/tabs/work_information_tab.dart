import 'dart:async';
import 'dart:math' as math;

import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/app/app_routes.dart';
import 'package:lws_hmi/app/theme/hmi_typography.dart';
import 'package:lws_hmi/features/monitor/application/work_information_display.dart';
import 'package:lws_hmi/features/monitor/presentation/widgets/monitor_chrome.dart';
import 'package:lws_hmi/features/monitor/presentation/widgets/monitor_gauges.dart';
import 'package:lws_hmi/features/settings/application/common_settings_scope.dart';
import 'package:lws_hmi/features/statistics/domain/stats_aggregate_models.dart';
import 'package:lws_hmi/features/statistics/domain/stats_aggregate_repository.dart';
import 'package:lws_hmi/features/statistics/infrastructure/sqlite_stats_aggregate_repository.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';

/// lws-ui `WorkInfoFragment` — 3 percent gauges + 3 data cards.
///
/// Binds to the single-row [StatsAggregate] (same store as Custom Home).
/// Refreshes on first show, when [visible] becomes true, on route resume, and
/// on a light poll while visible (job-runtime flush ~30s). Unit changes rebuild
/// via [ListenableBuilder] on [CommonSettingsStore].
class WorkInformationTab extends StatefulWidget {
  const WorkInformationTab({
    super.key,
    this.visible = true,
    this.repository,
    this.pollInterval = const Duration(seconds: 30),
  });

  /// When false (another Monitor tab selected), polling pauses.
  final bool visible;

  /// Injected in tests; defaults to the on-device SQLite aggregate.
  final StatsAggregateRepository? repository;

  /// Background reload while visible (job-runtime flush cadence).
  /// Set to [Duration.zero] in tests to disable polling.
  final Duration pollInterval;

  @override
  State<WorkInformationTab> createState() => _WorkInformationTabState();
}

class _WorkInformationTabState extends State<WorkInformationTab>
    with RouteAware {
  late final StatsAggregateRepository _repository =
      widget.repository ?? SqliteStatsAggregateRepository();
  late final bool _ownsRepository = widget.repository == null;

  StatsAggregate? _aggregate;
  Timer? _poll;
  bool _loading = false;
  ModalRoute<void>? _route;

  @override
  void initState() {
    super.initState();
    unawaited(refresh());
    _syncPoll();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route == _route) {
      return;
    }
    if (_route != null) {
      appRouteObserver.unsubscribe(this);
    }
    _route = route;
    if (route is PageRoute) {
      appRouteObserver.subscribe(this, route);
    }
  }

  @override
  void didUpdateWidget(covariant WorkInformationTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible && !oldWidget.visible) {
      unawaited(refresh());
    }
    _syncPoll();
  }

  @override
  void didPopNext() {
    // Returning to Monitor (e.g. after a pushed detail) — lws-ui onResume.
    if (widget.visible) {
      unawaited(refresh());
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    if (_route != null) {
      appRouteObserver.unsubscribe(this);
    }
    if (_ownsRepository) {
      unawaited(_repository.close());
    }
    super.dispose();
  }

  void _syncPoll() {
    _poll?.cancel();
    _poll = null;
    if (!widget.visible || widget.pollInterval <= Duration.zero) {
      return;
    }
    _poll = Timer(widget.pollInterval, _onPollTick);
  }

  void _onPollTick() {
    unawaited(refresh().whenComplete(() {
      if (!mounted || !widget.visible || widget.pollInterval <= Duration.zero) {
        return;
      }
      _poll = Timer(widget.pollInterval, _onPollTick);
    }));
  }

  /// Reloads aggregate + week anchors; safe to call while unmounted.
  Future<void> refresh() async {
    if (_loading) {
      return;
    }
    _loading = true;
    try {
      await _repository.refreshWeekAnchors(DateTime.now());
      final aggregate = await _repository.load();
      if (!mounted) {
        return;
      }
      setState(() => _aggregate = aggregate);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _aggregate = null);
    } finally {
      _loading = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final settings = CommonSettingsScope.maybeOf(context);

    Widget bodyForUnit(String? unitWire) {
      final display = WorkInformationDisplay.fromAggregate(
        _aggregate,
        unitWire: unitWire,
      );
      return _WorkInfoBody(l10n: l10n, display: display);
    }

    if (settings == null) {
      return bodyForUnit(null);
    }
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => bodyForUnit(settings.unit),
    );
  }
}

class _WorkInfoBody extends StatelessWidget {
  const _WorkInfoBody({
    required this.l10n,
    required this.display,
  });

  final AppLocalizations l10n;
  final WorkInformationDisplay display;

  @override
  Widget build(BuildContext context) {
    // Edge inset == inter-card gap ([MonitorDimens.pad] / [MonitorDimens.gap]).
    return Padding(
      padding: const EdgeInsets.all(MonitorDimens.pad),
      child: Column(
        children: [
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Expanded(
                  child: _PercentCard(
                    title: l10n.weldingProportionText,
                    value: display.weldRatioPercent.toDouble(),
                    color: const Color(0xFFFF0000),
                    borderGradientCenter:
                        CyberBorderGradientCenter.topLeftBottomRight,
                  ),
                ),
                const SizedBox(width: MonitorDimens.gap),
                Expanded(
                  child: _PercentCard(
                    title: l10n.cuttingProportionText,
                    value: display.cutRatioPercent.toDouble(),
                    color: const Color(0xFF00A4F2),
                    borderGradientCenter: CyberBorderGradientCenter.topBottom,
                  ),
                ),
                const SizedBox(width: MonitorDimens.gap),
                Expanded(
                  child: _PercentCard(
                    title: l10n.washProportionText,
                    value: display.cleanRatioPercent.toDouble(),
                    color: const Color(0xFFFF8000),
                    borderGradientCenter:
                        CyberBorderGradientCenter.bottomLeftTopRight,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: MonitorDimens.gap),
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Expanded(
                  child: MonitorWorkDataCard(
                    title: l10n.warnInfoLightTime,
                    value: display.laserOnNumber,
                    suffix: display.laserOnUnit,
                    borderGradientCenter:
                        CyberBorderGradientCenter.topLeftBottomRight,
                  ),
                ),
                const SizedBox(width: MonitorDimens.gap),
                Expanded(
                  child: MonitorWorkDataCard(
                    title: l10n.warnInfoWeldingConsumables,
                    value: display.wireNumber,
                    suffix: display.wireUnit,
                    borderGradientCenter: CyberBorderGradientCenter.topBottom,
                  ),
                ),
                const SizedBox(width: MonitorDimens.gap),
                Expanded(
                  child: MonitorWorkDataCard(
                    title: l10n.warnInfoLastWork,
                    value: display.jobRuntimeNumber,
                    suffix: display.jobRuntimeUnit,
                    borderGradientCenter:
                        CyberBorderGradientCenter.topRightBottomLeft,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PercentCard extends StatelessWidget {
  const _PercentCard({
    required this.title,
    required this.value,
    required this.color,
    this.borderGradientCenter = CyberBorderGradientCenter.topLeftBottomRight,
  });

  final String title;
  final double value;
  final Color color;
  final CyberBorderGradientCenter borderGradientCenter;

  @override
  Widget build(BuildContext context) {
    return MonitorGlassCard(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      borderGradientCenter: borderGradientCenter,
      child: Column(
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style:
                context.hmiTypography.navigation.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final side =
                    math.min(constraints.maxWidth, constraints.maxHeight);
                return Center(
                  child: PercentArcGauge(
                    value: value,
                    size: side.clamp(120.0, 220.0),
                    strokeWidth: 18,
                    progressColor: color,
                    trackColor: const Color(0xFF5A5A5A),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
