import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';

/// lws-ui `safety_black` full-screen backdrop behind the frost card.
const Color _kSafetyBlack = Color(0xFF060720);

/// Blue link color from lws-ui `activity_safety_tips.xml` (`#324BF3`).
const Color _kDisclaimerLink = Color(0xFF324BF3);

/// Screen-edge inset from lws-ui `activity_safety_tips.xml` (`30dp`).
const double _kScreenPad = 30;

/// Card content insets from lws-ui (`50/50/50/32`).
const EdgeInsets _kCardPad = EdgeInsets.fromLTRB(50, 50, 50, 32);

/// Shows Safety Tips; Product Disclaimer is nested via the footer link.
///
/// Returns when the user taps Agree on Safety Tips (lws-ui `toHome`).
Future<void> showSafetyTipsDialog({required BuildContext context}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'Safety Tips',
    barrierColor: _kSafetyBlack,
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return FadeTransition(
        opacity: animation,
        child: const _SafetyTipsShell(mode: _SafetyTipsMode.tips),
      );
    },
  );
}

enum _SafetyTipsMode { tips, disclaimer }

/// Full-bleed shell: black stage + near-fullscreen Cyber frost card.
class _SafetyTipsShell extends StatelessWidget {
  const _SafetyTipsShell({required this.mode});

  final _SafetyTipsMode mode;

  @override
  Widget build(BuildContext context) {
    final panel = CyberPanelBorder(tone: CyberTone.dark);
    return Material(
      type: MaterialType.transparency,
      child: ColoredBox(
        color: _kSafetyBlack,
        child: Padding(
          padding: const EdgeInsets.all(_kScreenPad),
          child: ClipRRect(
            borderRadius: panel.borderRadius,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: panel.borderRadius,
                border: Border.all(
                  color: panel.flatBorderColor,
                  width: panel.width,
                ),
              ),
              child: CyberModal(
                sampleMode: CyberBlurSampleMode.realtime,
                intensity: CyberBlurIntensity.high,
                blurTint: CyberBlurTint.dark,
                useFakeGlass: false,
                borderRadius: panel.borderRadius,
                padding: _kCardPad,
                child: _SafetyTipsBody(mode: mode),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SafetyTipsBody extends StatefulWidget {
  const _SafetyTipsBody({required this.mode});

  final _SafetyTipsMode mode;

  @override
  State<_SafetyTipsBody> createState() => _SafetyTipsBodyState();
}

class _SafetyTipsBodyState extends State<_SafetyTipsBody> {
  /// Matches lws-ui layout `android:checked="true"`.
  bool _agreed = true;

  Future<void> _openDisclaimer() async {
    CyberClickSoundRegistry.playClick();
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Product Disclaimer',
      barrierColor: _kSafetyBlack,
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return FadeTransition(
          opacity: animation,
          child: const _SafetyTipsShell(mode: _SafetyTipsMode.disclaimer),
        );
      },
    );
  }

  void _onAgree() {
    if (!_agreed) {
      return;
    }
    CyberClickSoundRegistry.playClick();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isTips = widget.mode == _SafetyTipsMode.tips;
    final title =
        isTips ? l10n.safetyTipsTitle : l10n.productDisclaimerTitle;
    final content =
        isTips ? l10n.safetyTipsContent : l10n.productDisclaimerContent;
    final checkboxLabel =
        isTips ? l10n.safetyTipsInfo : l10n.productDisclaimerInfo;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: CyberColors.textPrimary,
            fontSize: 37,
            fontWeight: FontWeight.w700,
            height: 1.15,
            decoration: TextDecoration.none,
          ),
        ),
        const SizedBox(height: 40),
        Expanded(
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: Text(
              content,
              style: const TextStyle(
                color: CyberColors.textPrimary,
                fontSize: 29,
                height: 1.35,
                fontWeight: FontWeight.w400,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CyberCheckbox(
                    key: ValueKey(
                      isTips
                          ? 'safety-tips-agree-cb'
                          : 'product-disclaimer-agree-cb',
                    ),
                    value: _agreed,
                    size: CyberDimens.checkboxLargeSize,
                    onChanged: (v) {
                      setState(() => _agreed = v ?? false);
                    },
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: isTips
                        ? Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                checkboxLabel,
                                style: const TextStyle(
                                  color: CyberColors.textPrimary,
                                  fontSize: 29,
                                  height: 1.25,
                                  decoration: TextDecoration.none,
                                ),
                              ),
                              // lws-ui: ` “` + Product Disclaimer. + `”`
                              GestureDetector(
                                key: const ValueKey(
                                  'safety-tips-disclaimer-link',
                                ),
                                onTap: _openDisclaimer,
                                child: Text(
                                  ' “${l10n.safetyTipsInfoUse}”',
                                  style: const TextStyle(
                                    color: _kDisclaimerLink,
                                    fontSize: 29,
                                    height: 1.25,
                                    fontWeight: FontWeight.w700,
                                    decoration: TextDecoration.none,
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Text(
                            checkboxLabel,
                            style: const TextStyle(
                              color: CyberColors.textPrimary,
                              fontSize: 29,
                              height: 1.25,
                              decoration: TextDecoration.none,
                            ),
                          ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: CyberDimens.contentPadding),
            SizedBox(
              width: 163,
              child: CyberButton(
                key: ValueKey(
                  isTips
                      ? 'safety-tips-agree-btn'
                      : 'product-disclaimer-agree-btn',
                ),
                size: CyberButtonSize.medium,
                variant: CyberButtonVariant.primary,
                shape: CyberButtonShape.rounded,
                stretch: true,
                onPressed: _agreed ? _onAgree : null,
                child: Text(l10n.safetyTipsAgree),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
