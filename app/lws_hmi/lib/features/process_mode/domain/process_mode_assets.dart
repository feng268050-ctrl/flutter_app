import 'package:lws_hmi/features/process_library/domain/process_library_models.dart';

/// Process-mode visual assets (from lws-ui mipmap-xxxhdpi).
abstract final class ProcessModeAssets {
  static const continuousWeldingOn =
      'assets/process/continuous_welding_on.webp';
  static const continuousWeldingOff =
      'assets/process/continuous_welding_off.webp';

  static const spotWeldingOn = 'assets/process/spot_weld_on.webp';
  static const spotWeldingOff = 'assets/process/spot_weld_off.webp';

  static const weldCleaningOn = 'assets/process/weld_cleaning_on.webp';
  static const weldCleaningOff = 'assets/process/weld_cleaning_off.webp';

  static const wideCleaningOn = 'assets/process/wide_width_cleaning_on.webp';
  static const wideCleaningOff = 'assets/process/wide_width_cleaning_off.webp';

  static const cutOn = 'assets/process/cut_on.webp';
  static const cutOff = 'assets/process/cut_off.webp';

  static const continuousWeldingTabBg =
      'assets/process/continuous_welding_tab_bg.webp';
  static const spotWeldingTabBg = 'assets/process/point_welding_tab_bg.webp';
  static const weldCleaningTabBg = 'assets/process/weld_clean_tab_bg.webp';
  static const wideCleaningTabBg = 'assets/process/width_clean_tab_bg.webp';
  static const handCuttingTabBg = 'assets/process/hand_cut_tab_bg.webp';

  /// Circular pick chrome used by gear / thickness (U3).
  static const circleBorder = 'assets/process/quick_model_circle_border.webp';
  static const circleCenter = 'assets/process/quick_model_circle_center.webp';
  static const circleSplitBorder =
      'assets/process/quick_model_circle_split_border.webp';
  static const circleSplitBorderTop =
      'assets/process/quick_model_circle_split_border_top.webp';

  static const pressureMonitoringOrange =
      'assets/process/pressure_monitoring_bg_orange.webp';
  static const pressureMonitoringGreen =
      'assets/process/pressure_monitoring_bg_green.webp';
  static const pressureMonitoringBlue =
      'assets/process/pressure_monitoring_bg_blue.webp';

  static const laserEnableBtn = 'assets/process/laser_enable_btn.webp';
  static const laserEnableBtnGreen =
      'assets/process/laser_enable_btn_green.webp';
  static const laserEnableBtnBlue = 'assets/process/laser_enable_btn_blue.webp';

  static const scaleLeft = 'assets/process/scale_left.webp';
  static const scaleRight = 'assets/process/scale_right.webp';

  /// CNC connection guide / running overlay (lws-ui mipmap-xxxhdpi).
  static const cncBg = 'assets/process/cnc_bg.webp';
  static const cncStep1 = 'assets/process/cnc_step_1.webp';
  static const cncStep2 = 'assets/process/cnc_step_2.webp';
  static const cncUnconnect = 'assets/process/unconnect.webp';
  static const cncConnectSuccess = 'assets/process/connect_success.webp';
  static const cncConnectError = 'assets/process/connect_error.webp';
  static const cncBlueLink = 'assets/process/blue_link.webp';
  static const cncExitBtn = 'assets/process/cnc_exit_btn.webp';
  static const cncDialogBtn = 'assets/process/cnc_dialog_btn.webp';

  /// Laser-enable Important Reminder (lws-ui open_laser / nozzle_* / fsr_*).
  static const laserReminderProtection =
      'assets/process/laser_reminder/open_laser_icon1.webp';
  static const laserReminderNozzleWeld =
      'assets/process/laser_reminder/nozzle_weld.webp';
  static const laserReminderNozzleCut =
      'assets/process/laser_reminder/nozzle_cut.webp';
  static const laserReminderNozzleWeldPathClean =
      'assets/process/laser_reminder/nozzle_weld_path_clean.webp';
  static const laserReminderNozzleUltraWideClean =
      'assets/process/laser_reminder/nozzle_ultra_wide_clean.webp';

  static String laserReminderFocusScale(int focusScaleRef) {
    if (focusScaleRef >= 0 && focusScaleRef <= 9) {
      return 'assets/process/laser_reminder/fsr_$focusScaleRef.webp';
    }
    if (focusScaleRef >= -9 && focusScaleRef <= -1) {
      return 'assets/process/laser_reminder/fsr_n${-focusScaleRef}.webp';
    }
    return '';
  }

  /// Engineer material type icons (lws-ui mipmap-xxhdpi).
  static const stainlessSteelIcon = 'assets/process/stainless_steel_icon.webp';
  static const carbonSteelIcon = 'assets/process/carbon_steel_icon.webp';
  static const galvanizedSheetIcon =
      'assets/process/galvanized_sheet_icon.webp';
  static const aluminumAlloyIcon = 'assets/process/aluminum_alloy_icon.webp';
  static const brassIcon = 'assets/process/brass_icon.webp';
  static const customizeIcon = 'assets/process/customize_icon.webp';
  static const selectDownWhiteArrow =
      'assets/process/select_down_white_arrow.webp';
  static const engineerDataValueBackground =
      'assets/process/engineer_data_value_background.webp';

  /// Frost status dialog glyphs (lws-ui `dialog_succd` / `dialog_error`).
  static const dialogSuccess = 'assets/process/dialog_succd.webp';
  static const dialogError = 'assets/process/dialog_error.webp';

  static String materialIcon(MaterialType material) {
    switch (material) {
      case MaterialType.stainlessSteel:
        return stainlessSteelIcon;
      case MaterialType.carbonSteel:
        return carbonSteelIcon;
      case MaterialType.galvanizedSheet:
        return galvanizedSheetIcon;
      case MaterialType.aluminumAlloy:
        return aluminumAlloyIcon;
      case MaterialType.brass:
        return brassIcon;
      case MaterialType.custom:
        return customizeIcon;
    }
  }
}
