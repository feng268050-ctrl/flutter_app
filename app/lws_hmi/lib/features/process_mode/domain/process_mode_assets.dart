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
      'assets/process/continuous_welding_tab_bg.png';
  static const spotWeldingTabBg = 'assets/process/point_welding_tab_bg.png';
  static const weldCleaningTabBg = 'assets/process/weld_clean_tab_bg.png';
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

  /// Quick-mode side operation icons (lws-ui mipmap-xxxhdpi).
  static const manualGasIcon = 'assets/process/manual_air_supply_white_on.webp';
  static const autoWireFeedOnIcon =
      'assets/process/gas_delivery_enable_white_on.webp';
  static const autoWireFeedOffIcon =
      'assets/process/gas_delivery_enable_white_off.webp';
  static const feedIcon = 'assets/process/entering_silk.webp';
  static const retractOnIcon = 'assets/process/retreat_white_on.webp';
  static const retractOffIcon = 'assets/process/retreat_white_off.webp';

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
