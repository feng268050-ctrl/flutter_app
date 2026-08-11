import 'dart:async';

import 'package:cyber_ime/cyber_ime.dart';
import 'package:cyber_hal/locale.dart';
import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:os_settings/app/os_settings_app.dart';
import 'package:os_settings/chrome/settings_chrome.dart';
import 'package:os_settings/l10n/app_localizations.dart';

/// Country/Region — HAL locale.conf Region.
class CountryRegionPage extends StatefulWidget {
  const CountryRegionPage({super.key});

  @override
  State<CountryRegionPage> createState() => _CountryRegionPageState();
}

class _CountryRegionPageState extends State<CountryRegionPage> {
  final _searchCtrl = TextEditingController();
  late List<RegionCatalogEntry> _all;
  late List<RegionCatalogEntry> _filtered;
  LocaleSettings? _locale;
  bool _ready = false;

  bool get _chineseUi {
    final code = Localizations.localeOf(context).languageCode;
    return code == 'zh';
  }

  @override
  void initState() {
    super.initState();
    _all = RegionCatalog.sortedForDisplay();
    _filtered = _all;
    _searchCtrl.addListener(_onSearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_boot());
    });
  }

  Future<void> _boot() async {
    final locale = OsSettingsScope.of(context).locale();
    await locale.read();
    if (!mounted) return;
    setState(() {
      _locale = locale;
      _ready = true;
    });
  }

  void _onSearchChanged() {
    setState(() {
      _filtered = RegionCatalog.filter(_all, _searchCtrl.text);
    });
  }

  Future<void> _selectRegion(LocaleSettings store, String code) async {
    final previous = store.region;
    final next = RegionCatalog.normalize(code);
    if (previous == next && store.hadPersistedRegion) {
      return;
    }
    await store.setRegion(next);
    final services = OsSettingsScope.maybeOf(context)?.services;
    if (services != null) {
      await services.regionSettings().applyRegionChange(
            previousRegion: previous,
            nextRegion: next,
          );
    }
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_onSearchChanged);
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = _locale;
    return SettingsScaffold(
      title: 'Country/Region',
      body: !_ready || locale == null
          ? const Center(child: CircularProgressIndicator())
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
                    style: SettingsTextStyles.title.copyWith(
                      fontSize: SettingsDimens.subtitleSize,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search',
                      hintStyle: SettingsTextStyles.supporting,
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: SettingsDimens.inset,
                    ),
                    child: _filtered.isEmpty
                        ? SettingsPanel(
                            child: Padding(
                              padding: SettingsDimens.rowPadding,
                              child: Text(
                                'No matches',
                                style: SettingsTextStyles.supporting,
                              ),
                            ),
                          )
                        : ListenableBuilder(
                            listenable: locale,
                            builder: (context, _) {
                              final region = locale.region;
                              return SettingsPanel(
                                child: ListView.separated(
                                  physics: const BouncingScrollPhysics(),
                                  itemCount: _filtered.length,
                                  separatorBuilder: (_, __) => const Divider(
                                    height: SettingsDimens.sectionDividerHeight,
                                    thickness:
                                        SettingsDimens.sectionDividerHeight,
                                    indent: 20,
                                    endIndent: 20,
                                    color: CyberColors.borderMid,
                                  ),
                                  itemBuilder: (context, index) {
                                    final e = _filtered[index];
                                    return SettingsOptionTile(
                                      title:
                                          '${e.labelFor(chineseUi: _chineseUi)} (${e.code})',
                                      selected: region == e.code,
                                      onTap: () {
                                        unawaited(_selectRegion(locale, e.code));
                                      },
                                    );
                                  },
                                ),
                              );
                            },
                          ),
                  ),
                ),
                SettingsHelpFooter(
                  AppLocalizations.of(context)!.regionSettingHelp,
                ),
              ],
            ),
    );
  }
}
