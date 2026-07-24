import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/features/work_mode/domain/work_mode_equipment_status.dart';

void main() {
  test('WorkModeEquipmentStatus copyWith preserves untouched fields', () {
    const base = WorkModeEquipmentStatus(
      gunSwitchOn: true,
      groundClampOn: true,
    );
    final next = base.copyWith(eStopTriggered: true, gasFlowOn: true);
    expect(
      next,
      const WorkModeEquipmentStatus(
        gunSwitchOn: true,
        groundClampOn: true,
        gasFlowOn: true,
        eStopTriggered: true,
      ),
    );
  });
}
