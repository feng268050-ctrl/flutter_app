import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/features/process_library/domain/process_library_models.dart';
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
}
