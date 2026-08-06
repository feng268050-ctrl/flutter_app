/// One settled work session used to update the single-row statistics aggregate.
///
  /// [autoWireFeedSeconds] deliberately excludes manual jog/feed operations. It
  /// is the duration of automatic wire feed belonging to this work session.
  ///
  /// Production settle uses laser-enable session duration × process wire speed
  /// (lws-ui `weldStop`); this event path keeps an explicit feed-seconds field
  /// for tests / importers (`wireFeedLengthMm = seconds × speed`).
final class WorkStopEvent {
  const WorkStopEvent({
    required this.sessionId,
    required this.modeType,
    required this.durationSeconds,
    required this.laserOnSeconds,
    this.autoWireFeedSeconds = 0,
    this.autoWireFeedSpeedMmPerSecond = 0,
    this.materialType,
    this.endedAtMs,
  });

  final String sessionId;
  final int modeType;
  final int durationSeconds;
  final int laserOnSeconds;
  final int autoWireFeedSeconds;
  final double autoWireFeedSpeedMmPerSecond;
  final int? materialType;
  final int? endedAtMs;

  int get wireFeedLengthMm =>
      (autoWireFeedSeconds * autoWireFeedSpeedMmPerSecond).round();
}

/// Immutable process context captured when Laser Enable starts a work session.
///
/// The automatic feed fields deliberately describe the process preset, never
/// the manual Feed/Retract controls.
final class WorkSessionStartEvent {
  const WorkSessionStartEvent({
    required this.sessionId,
    required this.modeType,
    required this.autoWireFeedEnabled,
    this.autoWireFeedSpeedMmPerSecond = 0,
    this.materialType,
    this.startedAtMs,
  });

  final String sessionId;
  final int modeType;
  final bool autoWireFeedEnabled;
  final double autoWireFeedSpeedMmPerSecond;
  final int? materialType;
  final int? startedAtMs;
}

/// The confirmed, unit-safe subset of one legacy `lws-ui static_data` row.
///
/// The legacy schema does not record units for `consumableTimeLength` or a
/// machine-readable meaning for its week fields. Those values are therefore
/// intentionally absent here: callers may only populate them after a separate
/// source/version check has established their meaning.
final class LegacyStaticDataImport {
  const LegacyStaticDataImport({
    required this.source,
    required this.weldSecondsTotal,
    required this.cutSecondsTotal,
    required this.cleanSecondsTotal,
    required this.jobRuntimeSecondsTotal,
    this.favoriteMaterialType,
    this.wireFeedLengthMmTotal,
    this.weekAnchorStartedAtMs,
    this.weekAnchorLaserOnSecondsTotal,
    this.prevWeekAnchorStartedAtMs,
    this.prevWeekAnchorLaserOnSecondsTotal,
  });

  /// Stable identifier for the imported export, recorded for audit/idempotency.
  final String source;
  final int weldSecondsTotal;
  final int cutSecondsTotal;
  final int cleanSecondsTotal;
  final int jobRuntimeSecondsTotal;
  final int? favoriteMaterialType;

  /// May be supplied only by a versioned exporter that proves millimetres.
  final int? wireFeedLengthMmTotal;

  /// May be supplied only by a versioned exporter that proves the anchor
  /// semantics and epoch-millisecond time base.
  final int? weekAnchorStartedAtMs;
  final int? weekAnchorLaserOnSecondsTotal;
  final int? prevWeekAnchorStartedAtMs;
  final int? prevWeekAnchorLaserOnSecondsTotal;
}

enum LegacyStaticDataMigrationResult {
  imported,
  alreadyImported,
  targetNotEmpty,
}

final class StatsAggregate {
  const StatsAggregate({
    required this.schemaVersion,
    required this.createdAtMs,
    required this.updatedAtMs,
    required this.lastResetAtMs,
    required this.lastSettledSessionId,
    required this.weldSecondsTotal,
    required this.cutSecondsTotal,
    required this.cleanSecondsTotal,
    required this.laserOnSecondsTotal,
    required this.jobRuntimeSecondsTotal,
    required this.wireFeedLengthMmTotal,
    required this.weldSessionCountTotal,
    required this.cutSessionCountTotal,
    required this.cleanSessionCountTotal,
    required this.laserEnableCountTotal,
    required this.lastSessionModeType,
    required this.lastSessionDurationSeconds,
    required this.lastSessionWireFeedSpeedMmPerSecond,
    required this.lastSessionMaterialType,
    required this.lastSessionEndedAtMs,
    required this.weekAnchorStartedAtMs,
    required this.weekAnchorLaserOnSecondsTotal,
    required this.prevWeekAnchorStartedAtMs,
    required this.prevWeekAnchorLaserOnSecondsTotal,
    required this.favoriteMaterialType,
    required this.favoriteMaterialUpdatedAtMs,
    required this.stainlessSteelSessionCountTotal,
    required this.carbonSteelSessionCountTotal,
    required this.galvanizedSheetSessionCountTotal,
    required this.aluminumAlloySessionCountTotal,
    required this.brassSessionCountTotal,
    required this.customMaterialSessionCountTotal,
    required this.legacyStaticDataImportedAtMs,
    required this.legacyStaticDataImportSource,
  });

  final int schemaVersion;
  final int createdAtMs;
  final int updatedAtMs;
  final int lastResetAtMs;
  final String? lastSettledSessionId;
  final int weldSecondsTotal;
  final int cutSecondsTotal;
  final int cleanSecondsTotal;
  final int laserOnSecondsTotal;
  final int jobRuntimeSecondsTotal;
  final int wireFeedLengthMmTotal;
  final int weldSessionCountTotal;
  final int cutSessionCountTotal;
  final int cleanSessionCountTotal;
  final int laserEnableCountTotal;
  final int? lastSessionModeType;
  final int? lastSessionDurationSeconds;
  final double? lastSessionWireFeedSpeedMmPerSecond;
  final int? lastSessionMaterialType;
  final int? lastSessionEndedAtMs;
  final int weekAnchorStartedAtMs;
  final int weekAnchorLaserOnSecondsTotal;
  final int prevWeekAnchorStartedAtMs;
  final int prevWeekAnchorLaserOnSecondsTotal;
  final int? favoriteMaterialType;
  final int? favoriteMaterialUpdatedAtMs;
  final int stainlessSteelSessionCountTotal;
  final int carbonSteelSessionCountTotal;
  final int galvanizedSheetSessionCountTotal;
  final int aluminumAlloySessionCountTotal;
  final int brassSessionCountTotal;
  final int customMaterialSessionCountTotal;
  final int? legacyStaticDataImportedAtMs;
  final String? legacyStaticDataImportSource;
}
