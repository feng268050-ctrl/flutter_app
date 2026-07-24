/// Snapshot for the five equipment indicators on [WorkModeStatusBar].
final class WorkModeEquipmentStatus {
  const WorkModeEquipmentStatus({
    this.gunSwitchOn = false,
    this.groundClampOn = false,
    this.keySwitchOn = false,
    this.gasFlowOn = false,
    this.eStopTriggered = false,
  });

  static const unknown = WorkModeEquipmentStatus();

  final bool gunSwitchOn;
  final bool groundClampOn;
  final bool keySwitchOn;
  final bool gasFlowOn;
  final bool eStopTriggered;

  WorkModeEquipmentStatus copyWith({
    bool? gunSwitchOn,
    bool? groundClampOn,
    bool? keySwitchOn,
    bool? gasFlowOn,
    bool? eStopTriggered,
  }) {
    return WorkModeEquipmentStatus(
      gunSwitchOn: gunSwitchOn ?? this.gunSwitchOn,
      groundClampOn: groundClampOn ?? this.groundClampOn,
      keySwitchOn: keySwitchOn ?? this.keySwitchOn,
      gasFlowOn: gasFlowOn ?? this.gasFlowOn,
      eStopTriggered: eStopTriggered ?? this.eStopTriggered,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is WorkModeEquipmentStatus &&
        other.gunSwitchOn == gunSwitchOn &&
        other.groundClampOn == groundClampOn &&
        other.keySwitchOn == keySwitchOn &&
        other.gasFlowOn == gasFlowOn &&
        other.eStopTriggered == eStopTriggered;
  }

  @override
  int get hashCode => Object.hash(
        gunSwitchOn,
        groundClampOn,
        keySwitchOn,
        gasFlowOn,
        eStopTriggered,
      );
}
