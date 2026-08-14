import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/features/process_library/domain/process_library_models.dart';
import 'package:lws_hmi/features/process_mode/domain/process_mode_tokens.dart';
import 'package:lws_hmi/features/work_mode/domain/work_mode_accent.dart';

void main() {
  test('forProcessType maps weld / clean / cut families', () {
    expect(
      WorkModeAccent.forProcessType(ProcessType.continuousWelding),
      WorkModeAccent.weld,
    );
    expect(
      WorkModeAccent.forProcessType(ProcessType.spotWelding),
      WorkModeAccent.weld,
    );
    expect(
      WorkModeAccent.forProcessType(ProcessType.weldCleaning),
      WorkModeAccent.clean,
    );
    expect(
      WorkModeAccent.forProcessType(ProcessType.wideCleaning),
      WorkModeAccent.clean,
    );
    expect(
      WorkModeAccent.forProcessType(ProcessType.handCutting),
      WorkModeAccent.cut,
    );
    expect(
      WorkModeAccent.forProcessType(ProcessType.cncCutting),
      WorkModeAccent.cut,
    );
  });

  test('quickSelectionHighlight follows lws-ui wheel_active mid colors', () {
    expect(
      ProcessModeTokens.quickSelectionHighlight(ProcessType.continuousWelding)
          .colors[1],
      const Color(0xB2FF8000),
    );
    expect(
      ProcessModeTokens.quickSelectionHighlight(ProcessType.weldCleaning)
          .colors[1],
      const Color(0x8037F3D2),
    );
    expect(
      ProcessModeTokens.quickSelectionHighlight(ProcessType.wideCleaning)
          .colors[1],
      const Color(0x8037F3D2),
    );
    expect(
      ProcessModeTokens.quickSelectionHighlight(ProcessType.handCutting)
          .colors[1],
      const Color(0x800151F4),
    );
    expect(
      ProcessModeTokens.quickSelectionHighlight(ProcessType.cncCutting)
          .colors[1],
      const Color(0x800151F4),
    );
  });
}
