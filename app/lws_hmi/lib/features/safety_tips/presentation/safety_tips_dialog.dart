import 'dart:ui' as ui;

import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/app/theme/app_typography.dart';
import 'package:lws_hmi/features/settings/presentation/widgets/settings_chrome.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';

/// Blue link color from lws-ui `activity_safety_tips.xml` (`#324BF3`).
const Color _kDisclaimerLink = Color(0xFF324BF3);

/// Screen-edge inset from lws-ui `activity_safety_tips.xml` (`30dp`).
const double _kScreenPad = 30;

/// Card content insets from lws-ui (`50/50/50/32`).
///
/// Horizontal pad is applied to title / scroll *content* / footer — not around
/// the scroll viewport — so the scrollbar sits flush on the frost card edge.
const double _kCardPadH = 50;
const double _kCardPadTop = 50;
const double _kCardPadBottom = 32;

/// Shows Safety Tips; Product Disclaimer is nested via the footer link.
///
/// Returns when the user taps Agree on Safety Tips (lws-ui `toHome`).
Future<void> showSafetyTipsDialog({required BuildContext context}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'Safety Tips',
    // Shell paints home wallpaper; keep route barrier clear.
    barrierColor: Colors.transparent,
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

/// Full-bleed shell: home wallpaper → σ30 page blur → Settings/Monitor card.
class _SafetyTipsShell extends StatelessWidget {
  const _SafetyTipsShell({required this.mode});

  final _SafetyTipsMode mode;

  @override
  Widget build(BuildContext context) {
    final corner = CyberGlassTheme.of(context).cornerRadius;
    const sigma = SettingsPerspectiveChrome.blurSigma;

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned.fill(child: SettingsHomeBackdrop()),
          // Sole Gaussian between home wallpaper and the frost container.
          Positioned.fill(
            child: IgnorePointer(
              child: ImageFiltered(
                imageFilter: ui.ImageFilter.blur(
                  sigmaX: sigma,
                  sigmaY: sigma,
                  tileMode: ui.TileMode.clamp,
                ),
                child: const SettingsHomeBackdrop(),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(_kScreenPad),
            child: Stack(
              // Allow [SettingsPerspectiveChrome.cardShadow] outside the face.
              clipBehavior: Clip.none,
              fit: StackFit.expand,
              children: [
                Positioned.fill(
                  child: SettingsPerspectiveChrome.face(
                    cornerRadius: corner,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    0,
                    _kCardPadTop,
                    0,
                    _kCardPadBottom,
                  ),
                  child: _SafetyTipsBody(mode: mode),
                ),
                Positioned.fill(
                  child: SettingsPerspectiveChrome.rim(cornerRadius: corner),
                ),
              ],
            ),
          ),
        ],
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
      barrierColor: Colors.transparent,
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
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: _kCardPadH),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: CyberColors.textPrimary,
              fontSize: AppTypography.largeDialogTitleSize,
              fontWeight: FontWeight.w700,
              height: 1.15,
              decoration: TextDecoration.none,
            ),
          ),
        ),
        const SizedBox(height: 40),
        Expanded(
          // Scrollbar tracks the full card width (flush to the frost edge);
          // body text keeps the 50dp horizontal inset.
          child: Scrollbar(
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: _kCardPadH),
              child: Text(
                content,
                style: const TextStyle(
                  color: CyberColors.textPrimary,
                  fontSize: AppTypography.pageTitleSize,
                  height: 1.35,
                  fontWeight: FontWeight.w400,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: _kCardPadH),
          child: Row(
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
                    const SizedBox(width: 12),
                    Expanded(
                      child: isTips
                          ? Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  checkboxLabel,
                                  style: const TextStyle(
                                    color: CyberColors.textPrimary,
                                    fontSize: AppTypography.pageTitleSize,
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
                                      fontSize: AppTypography.pageTitleSize,
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
                                fontSize: AppTypography.pageTitleSize,
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
                // Fixed width (lws-ui); only small-tier height is applied.
                width: 163,
                child: CyberButton(
                  key: ValueKey(
                    isTips
                        ? 'safety-tips-agree-btn'
                        : 'product-disclaimer-agree-btn',
                  ),
                  // medium keeps label/padding style; height alone → small tier.
                  size: CyberButtonSize.medium,
                  height: CyberDimens.actionButtonSmallHeight,
                  variant: CyberButtonVariant.primary,
                  shape: CyberButtonShape.rounded,
                  stretch: true,
                  onPressed: _agreed ? _onAgree : null,
                  child: Text(l10n.safetyTipsAgree),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
