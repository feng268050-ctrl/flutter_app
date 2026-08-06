import 'dart:ui' as ui;

import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/app/app_routes.dart';
import 'package:lws_hmi/app/theme/hmi_button_metrics.dart';
import 'package:lws_hmi/app/theme/hmi_typography.dart';
import 'package:lws_hmi/features/safety_tips/application/safety_tips_coordinator.dart';
import 'package:lws_hmi/features/safety_tips/application/safety_tips_gate.dart';
import 'package:lws_hmi/features/settings/presentation/widgets/settings_chrome.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';
import 'package:lws_hmi/ui/hmi/hmi_button.dart';

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

enum _SafetyTipsMode { tips, disclaimer }

/// Startup Safety Tips page (lws-ui `SafetyTipsActivity`).
///
/// First-screen named route [AppRoutes.safetyTips] — not a dialog over Home.
class SafetyTipsPage extends StatefulWidget {
  const SafetyTipsPage({super.key});

  @override
  State<SafetyTipsPage> createState() => _SafetyTipsPageState();
}

class _SafetyTipsPageState extends State<SafetyTipsPage> {
  @override
  void initState() {
    super.initState();
    SafetyTipsGate.setActive(true);
  }

  @override
  Widget build(BuildContext context) {
    return const _SafetyTipsShell(mode: _SafetyTipsMode.tips);
  }
}

/// Full-screen Product Disclaimer page (lws-ui `UseSafetyTipsActivity`).
///
/// Pushed as [AppRoutes.productDisclaimer] over [SafetyTipsPage].
class ProductDisclaimerPage extends StatelessWidget {
  const ProductDisclaimerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _SafetyTipsShell(mode: _SafetyTipsMode.disclaimer);
  }
}

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
    // Separate named route (lws-ui startActivity UseSafetyTipsActivity).
    await Navigator.of(context).pushNamed(AppRoutes.productDisclaimer);
  }

  void _onAgree() {
    if (!_agreed) {
      return;
    }
    CyberClickSoundRegistry.playClick();
    if (widget.mode == _SafetyTipsMode.tips) {
      SafetyTipsCoordinator.goHomeAfterAccept(context);
    } else {
      Navigator.of(context).pop();
    }
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
            style: context.hmiTypography.importantDialogTitle.copyWith(
              color: CyberColors.textPrimary,
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
              // Split ARB blocks on blank lines so "1. / 2. / …" keep clear
              // vertical gaps (plain Text collapses visual rhythm on device).
              child: _NumberedBodyText(
                content: content,
                style: context.hmiTypography.pageTitle.copyWith(
                  color: CyberColors.textPrimary,
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
                                  style: context.hmiTypography.pageTitle.copyWith(
                                    color: CyberColors.textPrimary,
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
                                    style: context.hmiTypography.pageTitle.copyWith(
                                      color: _kDisclaimerLink,
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
                              style: context.hmiTypography.pageTitle.copyWith(
                                color: CyberColors.textPrimary,
                                height: 1.25,
                                decoration: TextDecoration.none,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: CyberDimens.contentPadding),
              HmiButton(
                key: ValueKey(
                  isTips
                      ? 'safety-tips-agree-btn'
                      : 'product-disclaimer-agree-btn',
                ),
                label: l10n.safetyTipsAgree,
                // 100% small CTA; fixed width matches lws-ui Agree (163).
                size: HmiButtonSize.small,
                widthPolicy: HmiButtonWidthPolicy.fixed,
                width: 163,
                variant: CyberButtonVariant.primary,
                shape: CyberButtonShape.rounded,
                onPressed: _agreed ? _onAgree : null,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Renders Safety Tips / Disclaimer body as numbered blocks with fixed gaps.
///
/// ARB strings already use `\n\n` between `1.` / `2.` / … items; splitting here
/// makes inter-item spacing independent of line-height.
final class _NumberedBodyText extends StatelessWidget {
  const _NumberedBodyText({
    required this.content,
    required this.style,
  });

  final String content;
  final TextStyle style;

  /// Gap between numbered sections (and between intro + first section).
  static const _sectionGap = 20.0;

  @override
  Widget build(BuildContext context) {
    final blocks = content
        .split(RegExp(r'\n\s*\n'))
        .map((b) => b.trim())
        .where((b) => b.isNotEmpty)
        .toList(growable: false);
    if (blocks.isEmpty) {
      return Text(content, style: style);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < blocks.length; i++) ...[
          if (i > 0) const SizedBox(height: _sectionGap),
          Text(blocks[i], style: style),
        ],
      ],
    );
  }
}
