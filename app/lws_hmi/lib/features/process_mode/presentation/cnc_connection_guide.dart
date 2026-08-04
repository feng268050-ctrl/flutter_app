import 'package:flutter/material.dart';
import 'package:lws_hmi/features/process_mode/application/cnc_session_controller.dart';
import 'package:lws_hmi/features/process_mode/domain/process_mode_assets.dart';
import 'package:lws_hmi/app/theme/app_typography.dart';

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

  /// lws-ui `cnc_step_image` height (198dp); keep near Android so art sits high.
  static const double _stepImageHeight = 180;

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
            const Text(
              'Connection Guide',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: AppTypography.displaySize,
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
                    label: '1. Verify the RS485 connection.',
                    imageHeight: _stepImageHeight,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _CncStepColumn(
                    stepAsset: ProcessModeAssets.cncStep2,
                    statusAsset: null,
                    label: '2. Verify the cutting nozzle sensor cable.',
                    imageHeight: _stepImageHeight,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _CncStepColumn(
                    stepAsset: ProcessModeAssets.cncStep2,
                    statusAsset: null,
                    label:
                        '3. Confirm that the welding gun and fixture are securely connected.',
                    imageHeight: _stepImageHeight,
                  ),
                ),
              ],
            ),
            const Spacer(),
            const Padding(
              padding: EdgeInsets.only(bottom: 20),
              child: Text(
                'Note: After connecting, further adjustments are made on the CNC.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: AppTypography.bodySize,
                  height: 1.2,
                ),
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
    required this.imageHeight,
  });

  final String stepAsset;
  final String? statusAsset;
  final String label;
  final double imageHeight;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: imageHeight,
          width: double.infinity,
          child: Image.asset(stepAsset, fit: BoxFit.contain),
        ),
        SizedBox(
          height: 44,
          child: statusAsset == null
              ? const SizedBox.shrink()
              : Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Image.asset(
                    statusAsset!,
                    height: 36,
                    fit: BoxFit.contain,
                  ),
                ),
        ),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: AppTypography.supportingSize,
            height: 1.25,
          ),
        ),
      ],
    );
  }
}
