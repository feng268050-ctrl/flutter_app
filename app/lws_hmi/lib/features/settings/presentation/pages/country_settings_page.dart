import 'dart:async';

import 'package:cyber_hal/locale.dart';
import 'package:cyber_ime/cyber_ime.dart';
import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/app/theme/hmi_typography.dart';
import 'package:lws_hmi/features/settings/application/common_settings_scope.dart';
import 'package:lws_hmi/features/settings/presentation/widgets/settings_chrome.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';

class CountrySettingsPage extends StatefulWidget {
  const CountrySettingsPage({super.key, this.services});

  final AppServices? services;

  static bool _chineseUi(BuildContext context) {
    final lang = Localizations.localeOf(context).languageCode;
    return lang == 'zh';
  }

  static String countryLabel(BuildContext context, String code) {
    return RegionCatalog.displayName(
      code,
      chineseUi: _chineseUi(context),
    );
  }

  /// Prefer when [AppLocalizations] is already available (Common Settings row).
  static String countryLabelForLocale(String code, Locale locale) {
    return RegionCatalog.displayName(
      code,
      chineseUi: locale.languageCode == 'zh',
    );
  }

  @override
  State<CountrySettingsPage> createState() => _CountrySettingsPageState();
}

class _CountrySettingsPageState extends State<CountrySettingsPage> {
  final _searchCtrl = TextEditingController();
  final _ime = CyberImeSession.shared;
  late List<RegionCatalogEntry> _all;
  late List<RegionCatalogEntry> _filtered;

  @override
  void initState() {
    super.initState();
    _all = RegionCatalog.sortedForDisplay();
    _filtered = _all;
    _searchCtrl.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    setState(() {
      _filtered = RegionCatalog.filter(_all, _searchCtrl.text);
    });
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_onSearchChanged);
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final store = CommonSettingsScope.maybeOf(context);
    final appServices = widget.services ?? AppScope.maybeOf(context);
    final chineseUi = CountrySettingsPage._chineseUi(context);

    return SettingsScaffold(
      title: l10n.countrySettingText,
      body: store == null
          ? SettingsScrollView(
              children: [
                SettingsHelpFooter(l10n.countryPreferenceUnavailable),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    SettingsDimens.inset,
                    SettingsDimens.inset,
                    SettingsDimens.inset,
                    SettingsDimens.groupGap,
                  ),
                  child: CyberImeTextField(
                    fieldType: CyberImeFieldType.text,
                    controller: _searchCtrl,
                    session: _ime,
                    style: context.hmiTypography.body.copyWith(
                      color: CyberColors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: l10n.countrySearchHint,
                      hintStyle: const TextStyle(
                        color: CyberColors.textSecondary,
                      ),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: CyberColors.textSecondary,
                      ),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.06),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: CyberColors.borderMid,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: CyberColors.buttonPrimaryAccent,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      SettingsDimens.inset,
                      0,
                      SettingsDimens.inset,
                      0,
                    ),
                    child: ListenableBuilder(
                      listenable: store,
                      builder: (context, _) {
                        final region = store.region;
                        if (_filtered.isEmpty) {
                          return SettingsPanel(
                            borderGradientCenter:
                                CyberBorderGradientCenter.topLeftBottomRight,
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Text(
                                l10n.countryNoMatches,
                                style: context.hmiTypography.body.copyWith(
                                  color: CyberColors.textPrimary,
                                ),
                              ),
                            ),
                          );
                        }
                        return SettingsPanel(
                          borderGradientCenter:
                              CyberBorderGradientCenter.topLeftBottomRight,
                          child: ListView.separated(
                            physics: const BouncingScrollPhysics(
                              parent: AlwaysScrollableScrollPhysics(),
                            ),
                            itemCount: _filtered.length,
                            separatorBuilder: (_, __) => const Divider(
                              height: SettingsDimens.sectionDividerHeight,
                              thickness: SettingsDimens.sectionDividerHeight,
                              indent: 20,
                              endIndent: 20,
                              color: CyberColors.borderMid,
                            ),
                            itemBuilder: (context, index) {
                              final e = _filtered[index];
                              return SettingsOptionTile(
                                title:
                                    '${e.labelFor(chineseUi: chineseUi)} (${e.code})',
                                selected: region == e.code,
                                onTap: () {
                                  unawaited(_selectRegion(
                                    store: store,
                                    services: appServices,
                                    code: e.code,
                                  ));
                                },
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    SettingsDimens.inset,
                    0,
                    SettingsDimens.inset,
                    SettingsDimens.inset,
                  ),
                  child: SettingsHelpFooter(l10n.countryAppliesFooter),
                ),
              ],
            ),
    );
  }

  static Future<void> _selectRegion({
    required LocaleSettings store,
    required AppServices? services,
    required String code,
  }) async {
    final previous = store.region;
    final next = RegionCatalog.normalize(code);
    if (previous == next && store.hadPersistedRegion) {
      return;
    }
    await store.setRegion(next);
    final applier = services?.regionSettings;
    if (applier != null) {
      await applier.applyRegionChange(
        previousRegion: previous,
        nextRegion: next,
      );
    }
  }
}
