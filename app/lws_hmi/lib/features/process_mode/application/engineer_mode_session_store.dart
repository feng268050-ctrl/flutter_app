import 'package:flutter/foundation.dart';
import 'package:lws_hmi/features/process_library/domain/process_library_models.dart';
import 'package:lws_hmi/features/process_mode/domain/engineer_mode_draft.dart';

/// Process-lifetime Engineer Mode drafts (lws-ui `MemoryCacheManager` +
/// `engineer_data_cache:{processType}`).
///
/// Field edits are **not** Room writes; [Save as Favorite] is. This store keeps
/// the working draft across leave/re-enter of Engineer Mode and across process
/// tabs so Flutter route disposal does not wipe the session (Android Activity
/// ViewModel dies, but MemoryCache survives).
final class EngineerModeSessionStore {
  EngineerModeSessionStore._();

  static final EngineerModeSessionStore instance = EngineerModeSessionStore._();

  final Map<ProcessType, EngineerModeDraft> _byType = {};

  EngineerModeDraft? get(ProcessType type) => _byType[type];

  /// Publish the working draft for [draft.preset.processType].
  void put(EngineerModeDraft draft) {
    _byType[draft.preset.processType] = draft;
  }

  void remove(ProcessType type) {
    _byType.remove(type);
  }

  @visibleForTesting
  void clearForTest() {
    _byType.clear();
  }
}
