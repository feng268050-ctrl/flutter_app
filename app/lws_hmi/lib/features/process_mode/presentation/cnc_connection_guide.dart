import 'package:flutter/material.dart';
import 'package:lws_hmi/app/theme/hmi_typography.dart';
import 'package:lws_hmi/features/process_mode/application/cnc_session_controller.dart';
import 'package:lws_hmi/features/process_mode/domain/process_mode_assets.dart';
import 'package:lws_hmi/app/theme/hmi_typography.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';

/// Quick-mode CNC connection guide (lws-ui `CNCCutFragment`).
///
/// Parent [Positioned] supplies insets that clear the process wheel. The
/// `cnc_bg` asset itself carries the rounded frame and bright edge — use
/// [BoxFit.fill] (not cover) so that perimeter is preserved.
final class CncConnectionGuide extends StatelessWidget {
  const CncConnectionGuide({
    super.key,
    required this.linkStatus,
  });

  final CncLinkStatus linkStatus;

  /// Average luminance sampled from `cnc_bg.webp` perimeter (bright edge).
  static const Color _frameEdge = Color(0xFF5B5B5B);

  /// Title — [HmiTypography.cncGuideTitleSize] (38).
  static const double _titleSize = HmiTypography.cncGuideTitleSize;

  static const double _bodyLineHeight = 1.25;

  /// Shared min height so step 1/2/3 labels align across columns.
  static const double _stepLabelMinHeight =
      HmiTypography.sectionTitleSize * _bodyLineHeight * 3;

  /// lws-ui `cnc_step_image` height (198dp); keep near Android so art sits high.
  static const double _stepImageHeight = 180;

  static TextStyle _bodyStyle(HmiTypography typography) =>
      typography.sectionTitle.copyWith(
        color: Colors.white,
        height: _bodyLineHeight,
      );

  String? get _statusAsset {
    switch (linkStatus) {
      case CncLinkStatus.connecting:
        return ProcessModeAssets.cncUnconnect;
      case CncLinkStatus.success:
        return ProcessModeAssets.cncConnectSuccess;
      case CncLinkStatus.failed:
        return ProcessModeAssets.cncConnectError;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final bodyStyle = _bodyStyle(context.hmiTypography);
    return DecoratedBox(
      key: const ValueKey('quick-mode-cnc-guide'),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _frameEdge, width: 1.5),
        image: const DecorationImage(
          image: AssetImage(ProcessModeAssets.cncBg),
          fit: BoxFit.fill,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 22),
            Text(
              l10n?.cncConnectionGuideTitle ?? 'Connection Guide',
              textAlign: TextAlign.center,
              style: context.hmiTypography.displayAction.copyWith(
                color: Colors.white,
                fontSize: _titleSize,
                height: 1.0,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 20),
            // Pack steps under the title (Android wrap_content) — do not
            // Expanded-stretch the art or labels sink to the bottom.
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _CncStepColumn(
                    stepAsset: ProcessModeAssets.cncStep1,
                    statusAsset: _statusAsset,
                    label: l10n?.cncConnectionGuideStep1 ??
                        '1. Verify the RS485 connection.',
                    labelStyle: bodyStyle,
                    labelMinHeight: _stepLabelMinHeight,
                    imageHeight: _stepImageHeight,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _CncStepColumn(
                    stepAsset: ProcessModeAssets.cncStep2,
                    statusAsset: null,
                    label: l10n?.cncConnectionGuideStep2 ??
                        '2. Verify the cutting nozzle sensor cable.',
                    labelStyle: bodyStyle,
                    labelMinHeight: _stepLabelMinHeight,
                    imageHeight: _stepImageHeight,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _CncStepColumn(
                    stepAsset: ProcessModeAssets.cncStep2,
                    statusAsset: null,
                    label: l10n?.cncConnectionGuideStep3 ??
                        '3. Confirm that the welding gun and fixture are securely connected.',
                    labelStyle: bodyStyle,
                    labelMinHeight: _stepLabelMinHeight,
                    imageHeight: _stepImageHeight,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Text(
                l10n?.cncConnectionGuideNote ??
                    'Note: After connecting, further adjustments are made on the CNC.',
                textAlign: TextAlign.center,
                style: bodyStyle.copyWith(height: 1.2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _CncStepColumn extends StatelessWidget {
  const _CncStepColumn({
    required this.stepAsset,
    required this.statusAsset,
    required this.label,
    required this.labelStyle,
    required this.labelMinHeight,
    required this.imageHeight,
  });

  final String stepAsset;
  final String? statusAsset;
  final String label;
  final TextStyle labelStyle;
  final double labelMinHeight;
  final double imageHeight;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: imageHeight,
          width: double.infinity,
          child: Center(
            child: Image.asset(stepAsset, fit: BoxFit.contain),
          ),
        ),
        SizedBox(
          height: 44,
          width: double.infinity,
          child: statusAsset == null
              ? const SizedBox.shrink()
              : Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Center(
                    child: Image.asset(
                      statusAsset!,
                      height: 36,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
        ),
        SizedBox(
          height: labelMinHeight,
          width: double.infinity,
          child: Text(
            label,
            textAlign: TextAlign.start,
            style: labelStyle,
          ),
        ),
      ],
    );
  }
}
