import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/features/monitor/presentation/widgets/monitor_chrome.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';

/// lws-ui `fragment_ai_vision` — info panel + choose button + preview box.
class AiVisionTab extends StatelessWidget {
  const AiVisionTab({super.key});

  /// lws-ui label bar fill `#CC2E3653`.
  static const _labelBar = Color(0xCC2E3653);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.all(MonitorDimens.pad),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: MonitorDimens.aiInfoW,
            child: Column(
              children: [
                Expanded(
                  child: MonitorGlassCard(
                    padding: const EdgeInsets.fromLTRB(0, 22, 0, 8),
                    borderGradientCenter:
                        CyberBorderGradientCenter.topLeftBottomRight,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 10, 24, 21),
                          child: Text(
                            l10n.deviceMonitorWorkInfoTitle,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 35,
                              fontWeight: FontWeight.w400,
                              height: 1.0,
                            ),
                          ),
                        ),
                        _InfoBlock(
                          label: l10n.aiVisionProcessTypeText,
                          value: l10n.aiVisionWorkInfoUnavailable,
                        ),
                        _InfoBlock(
                          label: l10n.aiVisionMaterialTypeText,
                          value: l10n.aiVisionWorkInfoUnavailable,
                        ),
                        _InfoBlock(
                          label: l10n.processVideoRecordingTime,
                          value: l10n.aiVisionWorkInfoUnavailable,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: CyberButton(
                    variant: CyberButtonVariant.primary,
                    shape: CyberButtonShape.rounded,
                    stretch: true,
                    borderGradientCenter:
                        CyberBorderGradientCenter.topLeftBottomRight,
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Choose video — coming soon'),
                        ),
                      );
                    },
                    child: Text(
                      l10n.aiVisionChooseBtn,
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: MonitorGlassCard(
              padding: const EdgeInsets.all(10),
              borderGradientCenter:
                  CyberBorderGradientCenter.bottomLeftTopRight,
              child: Center(
                child: Text(
                  l10n.liveVideoFailed,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 24,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoBlock extends StatelessWidget {
  const _InfoBlock({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    // lws-ui: label on `#CC2E3653` bar; value below — not nested Frost cards.
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ColoredBox(
            color: AiVisionTab._labelBar,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 31, vertical: 16),
              child: Text(
                label,
                style: const TextStyle(
                  color: Color(0xFFE1E1E1),
                  fontSize: 24,
                  height: 1.0,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(31, 16, 31, 0),
            child: Text(
              value,
              style: const TextStyle(
                color: Color(0xFFE1E1E1),
                fontSize: 24,
                height: 1.0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
