import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lws_hmi/features/process_library/domain/process_library_models.dart';
import 'package:lws_hmi/features/process_mode/domain/process_mode_assets.dart';
import 'package:lws_hmi/features/work_mode/domain/work_mode_accent.dart';
import 'package:lws_hmi/features/work_mode/presentation/work_mode_status_bar.dart';

/// Shared colors / geometry for Quick + Engineer process chrome (lws-ui).
abstract final class ProcessModeTokens {
  /// lws-ui `engineer_base_background_color` / quick activity bg.
  static const Color background = Color(0xFF060720);

  /// Quick activity root uses near-black; keep shell aligned with engineer.
  static const Color quickRootBackground = Color(0xFF0A0B0C);

  /// Engineer tab inactive text — lws-ui `engineer_tab_no_active_text`.
  static const Color tabInactiveText = Color(0x99FFFFFF);

  /// Engineer weld tab active — lws-ui `engineer_weld_tab_active`.
  static const Color tabWeldActive = Color(0xFFFD7632);

  /// Engineer wash tab active — lws-ui `engineer_wash_tab_active`.
  static const Color tabCleanActive = Color(0xFF37F3D2);

  /// Engineer cut tab active — lws-ui `engineer_cut_tab_active`.
  static const Color tabCutActive = Color(0xFF324BF3);

  static Color tabActiveColor(ProcessType type) {
    if (type.isCleaning) {
      return tabCleanActive;
    }
    if (type == ProcessType.handCutting || type == ProcessType.cncCutting) {
      return tabCutActive;
    }
    return tabWeldActive;
  }

  /// Side-op highlight mid color (lws-ui `quick_mode_wheel_active_*`).
  static Color sideOperationHighlightMid(ProcessType type) {
    if (type.isCleaning) {
      return const Color(0x8037F3D2);
    }
    if (type == ProcessType.handCutting || type == ProcessType.cncCutting) {
      return const Color(0x800151F4);
    }
    return const Color(0xB2FF8000);
  }

  /// Feed hold / continuous-feed GradientButton mid (lws-ui `quick_model_*`).
  static Color feedHoldGradientMid(ProcessType type) {
    if (type.isCleaning) {
      return const Color(0xFF37F3D2);
    }
    if (type == ProcessType.handCutting || type == ProcessType.cncCutting) {
      return const Color(0xFF0151F4);
    }
    return const Color(0xFFF46E01);
  }

  /// Transparent ends for the side-op / divider horizontal gradient.
  static Color sideOperationHighlightEdge(ProcessType type) {
    if (type.isCleaning) {
      return const Color(0x0037F3D2);
    }
    if (type == ProcessType.handCutting || type == ProcessType.cncCutting) {
      return const Color(0x000151F4);
    }
    return const Color(0x00FF8000);
  }

  /// Horizontal metal-sheen highlight: transparent → mid → transparent.
  static LinearGradient sideOperationHighlight(ProcessType type) {
    final edge = sideOperationHighlightEdge(type);
    return LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [edge, sideOperationHighlightMid(type), edge],
      stops: const [0.0, 0.5, 1.0],
    );
  }

  /// Divider line: transparent → mode accent → transparent.
  static LinearGradient sideOperationDivider(ProcessType type) {
    final edge = sideOperationHighlightEdge(type);
    return LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [edge, tabActiveColor(type), edge],
    );
  }

  /// Disabled side-op label/icon — lws-ui `quick_mode_btn_text` disabled.
  static const Color sideOperationDisabled = Color(0xFF848585);

  static WorkModeAccent accentFor(ProcessType type) =>
      WorkModeAccent.forProcessType(type);
}

/// Design-canvas dimens on 1280×800 (lws-ui activity_quick_mode / engineer_tab).
abstract final class ProcessModeDimens {
  static const double designWidth = 1280;
  static const double designHeight = 800;

  /// Status bar height shared with [WorkModeStatusBarDimens.height].
  static const double statusBarHeight = WorkModeStatusBarDimens.height;

  // --- Quick mode process wheel (activity_quick_mode.xml) ---
  // Fixed logical px (lws-ui design values frozen for Flutter HMI).

  static const double wheelWidth = 520 / 3; // 173.333…
  static const double wheelHeight = 680 / 3; // 226.666…
  static const double wheelItemHeight = 168 / 3; // 56 — was 136/3; more row gap
  static const double wheelSelectedTextSize = 56 / 3; // 18.666…
  static const double wheelUnselectedTextSize = 16;
  static const double wheelAccentBandWidth = 400;
  static const double wheelAccentSolidWidth = 550 / 3; // 183.333…

  /// lws-ui OffsetWheel: selected equal L/R pad (`selectedTextMarginBottomTop`).
  static const double wheelSelectedPadding = 24;

  /// Nearly-flat ListWheel (lws-ui OffsetWheel is a flat ListView + pad arc).
  static const double wheelDiameterRatio = 100;
  static const double wheelPerspective = 0.001;

  /// Mode / material linear arc: `|d| × 10 + 24` (lws-ui OffsetWheelBuilder).
  static double linearArcPad(double distance) => distance * 10 + 24;

  /// Clears the process wheel / left accent for the CNC guide.
  static const double cncGuideLeftInset = 210;
  static const double cncGuideTopInset = 24;
  static const double cncGuideRightInset = 24;
  static const double cncGuideBottomInset = 24;

  /// Center laser dashboard design canvas from lws-ui `laser_progress.xml`.
  ///
  /// Android lays the Quick screen out at 1280×800dp. Flutter-pi reports a
  /// smaller logical viewport for the same panel, so dashboard geometry must
  /// be derived from the viewport rather than copied as fixed logical pixels.
  static const double dashboardDesignSize = 570;

  static double dashboardScaleFor(Size viewport) {
    final widthScale = viewport.width / designWidth;
    final heightScale = viewport.height / designHeight;
    return math.min(1.0, math.min(widthScale, heightScale));
  }

  /// Fixed reference size for picker placement math (live dashboard uses
  /// [dashboardScaleFor] at runtime).
  static const double dashboardSize = 380;
  static const double dashboardOuterRing = 380;

  /// Outer rail stroke (design dp) — equal to inner (`laser_circular_seek_mini`).
  static const double dashboardOuterStrokeDesign = 50;
  static const double dashboardOuterStroke = 100 / 3; // 33.333…

  /// Thin bright line (lws-ui `laser_circular_seek_line` progress_width).
  static const double dashboardLineStrokeDesign = 6;
  static const double dashboardLineStroke = 4;

  /// Thin highlight path radius matches the outer rail outer face (outerRing/2).
  static const double dashboardLineRing =
      dashboardOuterRing + dashboardLineStroke;

  /// Dark inner rail matches the outer rail stroke 1:1.
  static const double dashboardInnerStroke = dashboardOuterStroke;

  /// Nest inside the outer ring's inner face with equal stroke widths.
  static const double dashboardInnerRing =
      dashboardOuterRing - 2 * dashboardOuterStroke;

  /// Pressure panel hugs the inner face of the inner rail (not mid-stroke).
  static const double dashboardInnerSize =
      dashboardInnerRing - 2 * dashboardInnerStroke;
  static const double dashboardSplitTopWidth = dashboardInnerRing + 12;
  static const double dashboardSplitTopHeight =
      dashboardSplitTopWidth * (477.48 / 532.14);
  static const double dashboardSplitWidth = dashboardInnerRing;
  static const double dashboardSplitHeight =
      dashboardSplitWidth * (477.48 / 500.14);
  static const double dashboardBorderWidth = dashboardLineRing;
  static const double dashboardBorderHeight =
      dashboardBorderWidth * (573.5 / 541);
  static const double dashboardSplitOffsetY = 16 / 3; // 5.333…
  static const double dashboardBorderOffsetX = 0;
  static const double dashboardBorderOffsetY = 16 / 3; // 5.333…

  /// lws-ui `text_size_14` / `text_size_48` / `text_size_10` (named ≠ sp).
  static const double dashboardTitleSize = 22;
  static const double dashboardValueSize = 202 / 3; // 67.333…
  static const double dashboardUnitSize = 50 / 3; // 16.666…

  /// Keep content rhythm proportional to the enlarged pressure panel.
  static const double dashboardContentTop = 50 * dashboardInnerSize / 372;
  static const double dashboardContentGap = 5 * dashboardInnerSize / 372;
  static const double dashboardButtonGap = 16.5 * dashboardInnerSize / 372;
  static const double dashboardButtonTextSize = 28 / 3; // 9.333…
  static const double dashboardButtonIconSize = 12;
  static const double dashboardButtonIconGap = 8 / 3; // 2.666…

  /// `fragment_general_operations.xml` LaserButtonLinearLayout design bounds.
  /// Runtime size uses the same 1280×800 scale as the center dashboard.
  static const double quickLaserButtonWidth = 564;
  static const double quickLaserButtonHeight = 223;
  static const double quickLaserButtonIconSize = 67;
  static const double quickLaserButtonLabelSize = 45;

  /// Trapezoid clip inside the laser button (matches `_QuickLaserTrapezoid`).
  static const double quickLaserTrapezoidTopWidthRatio = 0.5;
  static const double quickLaserTrapezoidBottomWidthRatio = 0.93;
  static const double quickLaserTrapezoidHeightRatio = 0.8;

  /// Edge shadow band along Laser Enable rim (top + upper slants). Stays inside
  /// the 564×223 graphic; covers arc-shoulder voids without changing colors.
  static const double quickLaserRimShadowStroke = 18;
  static const double quickLaserRimShadowBlur = 8;

  /// Side ops (Manual Gas / Auto Wire / Feed / Retract) — lws-ui styles.
  static const double quickSideButtonWidth = 264;
  static const double quickSideButtonInset = 30;
  /// Lower than lws-ui 35.5 so wheels sit farther above the four side buttons.
  static const double quickSideButtonBottom = 12;
  static const double quickSideOpIconSize = 24;
  static const double quickSideOpLabelSize = 27;
  static const double quickSideOpIconGap = 6;
  static const double quickSideOpVerticalPadding = 12;
  static const double quickSideOpDividerHeight = 8;
  static const double quickSideOpGapAboveDivider = 27;
  static const double quickSideOpGapBelowDivider = 15;

  /// Thin bright ring radius (lws-ui outer highlight), same formula as
  /// `_LaserDashboardMetrics.outerHighlightRadius`.
  static double outerHighlightRadiusFor(Size viewport) {
    final s = dashboardScaleFor(viewport);
    return (dashboardDesignSize / 2) * s -
        (dashboardOuterStrokeDesign * s) / 2 -
        (dashboardLineStrokeDesign * s) / 2;
  }

  /// Lift mode / material selection midline (and gear/thickness value + accent
  /// only — scale chrome stays on the dashboard circle center).
  static const double quickSelectorNudgeY = -25;

  /// Quick Mode top chrome: Record Work (left) / More Parameters (right).
  /// Equal screen-edge inset; same [quickTopChromeTop] for a shared baseline.
  static const double quickTopChromeInset = 40;
  static const double quickTopChromeTop = 20;
  static const double quickTopChromeLabelSize = 26;

  /// Gear/Thickness: toStartOf/toEndOf dashboard + overlap + translation.
  static const double pickerWidth = 560 / 3; // 186.666…
  static const double pickerCenterOverlap = 100;
  /// Smaller than lws-ui 60dp so gear/thickness sit further outward.
  static const double pickerHorizontalOffset = 40 / 3; // 13.333…

  /// lws-ui `translationY="-8dp"` on gear/thickness pickers — omitted from
  /// page Y so the selected value / accent shares mode & material midline.
  static const double pickerVerticalOffset = -16 / 3; // -5.333…

  /// Column asymmetry: scale image center vs pick widget center.
  static double get pickerScaleCenterOffsetY {
    const title = 32.0;
    const gap = 16.0;
    const scaleH = 402.0;
    const bottom = 140 / 3; // 46.666…
    const total = title + gap + scaleH + bottom;
    const scaleCenterFromTop = title + gap + scaleH / 2;
    return total / 2 - scaleCenterFromTop;
  }

  /// Page Y for gear/thickness pick chrome (scale center ↔ dashboard circle).
  /// Value wheel / accent are nudged separately via [quickSelectorNudgeY].
  static double get pickerVerticalFromPageCenter => pickerScaleCenterOffsetY;

  static const double materialVerticalOffset = -79 / 3; // -26.333…

  /// Gear/Thickness center X from page center (lws-ui RelativeLayout math).
  static double get pickerCenterFromPageCenter =>
      -(dashboardSize / 2) +
      pickerCenterOverlap -
      (pickerWidth / 2) +
      pickerHorizontalOffset;

  // --- Engineer tab bar (engineer_tab.xml, weightSum=1280) ---

  static const double engineerTabBarHeight = 88;
  static const double engineerTabIconSize = 24;
  static const double engineerTabIconGap = 13;
  static const double engineerTabUnderlineHeight = 1.5;
  static const double engineerTabUnderlineInset = 18;

  /// Enlarged for the 1280×800 touch panel (lws-ui tabs used 12sp).
  static const double engineerTabLabelSize = 20;

  /// Left device panel — lws-ui `engineer_welding_left_panel_width`.
  static const double engineerLeftPanelWidth = 460;

  /// Flex weights for five engineer tabs (sum 1280, same as lws-ui `weightSum`).
  /// Cutting widened vs original Android art; the five `*_tab_bg` assets were
  /// remeshed to these ratios so painted frames match hit targets.
  static const List<int> engineerTabWeights = [290, 214, 282, 284, 210];
}

/// Display strings aligned with lws-ui [ModelConstant] English labels.
abstract final class ProcessModeLabels {
  /// Quick-mode wheel labels (full English names).
  static String wheelLabel(ProcessType type) {
    switch (type) {
      case ProcessType.continuousWelding:
        return 'Continuous Welding';
      case ProcessType.spotWelding:
        return 'Spot Welding';
      case ProcessType.weldCleaning:
        return 'Weld Seam Cleaning';
      case ProcessType.wideCleaning:
        return 'Wide-Area Cleaning';
      case ProcessType.handCutting:
        return 'Cutting';
      case ProcessType.cncCutting:
        return 'CNC Cutting';
    }
  }

  /// Engineer tab short English labels (fit tab background partitions).
  static String engineerTabLabel(ProcessType type) {
    switch (type) {
      case ProcessType.continuousWelding:
        return 'Continuous';
      case ProcessType.spotWelding:
        return 'Spot';
      case ProcessType.weldCleaning:
        return 'Weld Seam';
      case ProcessType.wideCleaning:
        return 'Wide-Area';
      case ProcessType.handCutting:
        return 'Cutting';
      case ProcessType.cncCutting:
        return 'CNC Cutting';
    }
  }
}

/// Engineer Mode tabs mirror lws-ui: five process types (no CNC).
abstract final class EngineerProcessTabs {
  static const List<ProcessType> types = [
    ProcessType.continuousWelding,
    ProcessType.spotWelding,
    ProcessType.weldCleaning,
    ProcessType.wideCleaning,
    ProcessType.handCutting,
  ];

  static String tabBackground(ProcessType type) {
    switch (type) {
      case ProcessType.continuousWelding:
        return ProcessModeAssets.continuousWeldingTabBg;
      case ProcessType.spotWelding:
        return ProcessModeAssets.spotWeldingTabBg;
      case ProcessType.weldCleaning:
        return ProcessModeAssets.weldCleaningTabBg;
      case ProcessType.wideCleaning:
        return ProcessModeAssets.wideCleaningTabBg;
      case ProcessType.handCutting:
        return ProcessModeAssets.handCuttingTabBg;
      case ProcessType.cncCutting:
        return ProcessModeAssets.handCuttingTabBg;
    }
  }

  static String iconOn(ProcessType type) {
    switch (type) {
      case ProcessType.continuousWelding:
        return ProcessModeAssets.continuousWeldingOn;
      case ProcessType.spotWelding:
        return ProcessModeAssets.spotWeldingOn;
      case ProcessType.weldCleaning:
        return ProcessModeAssets.weldCleaningOn;
      case ProcessType.wideCleaning:
        return ProcessModeAssets.wideCleaningOn;
      case ProcessType.handCutting:
      case ProcessType.cncCutting:
        return ProcessModeAssets.cutOn;
    }
  }

  static String iconOff(ProcessType type) {
    switch (type) {
      case ProcessType.continuousWelding:
        return ProcessModeAssets.continuousWeldingOff;
      case ProcessType.spotWelding:
        return ProcessModeAssets.spotWeldingOff;
      case ProcessType.weldCleaning:
        return ProcessModeAssets.weldCleaningOff;
      case ProcessType.wideCleaning:
        return ProcessModeAssets.wideCleaningOff;
      case ProcessType.handCutting:
      case ProcessType.cncCutting:
        return ProcessModeAssets.cutOff;
    }
  }
}

/// Quick Mode process wheel order (all six types, including CNC).
abstract final class QuickProcessWheelItems {
  static const List<ProcessType> types = ProcessType.values;
}
