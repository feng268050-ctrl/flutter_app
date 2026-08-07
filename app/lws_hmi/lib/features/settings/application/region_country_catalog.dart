import 'package:lws_hmi/features/settings/application/region_country_data.dart';

/// One ISO 3166-1 alpha-2 country / territory (+ XK).
final class RegionCountryEntry {
  const RegionCountryEntry({
    required this.code,
    required this.nameEn,
    required this.nameZh,
    required this.defaultTimezone,
    required this.preferredNtp,
  });

  /// ISO 3166-1 alpha-2 (uppercase), or `XK` (Kosovo).
  final String code;

  /// English display name.
  final String nameEn;

  /// Simplified Chinese display name.
  final String nameZh;

  /// IANA timezone seed when Country-linked (capital / primary zone).
  final String defaultTimezone;

  /// Primary NTP hostname (must be in [NtpServerCatalog] or normalize safely).
  final String preferredNtp;

  /// Localized label: Chinese UI uses [nameZh], otherwise [nameEn].
  String labelFor({required bool chineseUi}) => chineseUi ? nameZh : nameEn;
}

/// Product Country catalog — full ISO 3166-1 (+ XK) with TZ / NTP defaults.
///
/// Product default is [defaultCountry] (`US`). Country-driven NTP MUST NOT be
/// `cn.pool.ntp.org`.
abstract final class RegionCountryCatalog {
  static const preferredNtpDefault = RegionCountryData.preferredNtp;

  /// Legacy Asia-centric timezone treated as Country-linked on first migrate.
  static const legacyAsiaTimezone = 'Asia/Shanghai';

  /// Legacy NTP treated as Country-linked for migration.
  static const legacyChinaNtp = 'cn.pool.ntp.org';

  static const defaultCountry = 'US';

  static const entries = RegionCountryData.entries;

  static const supportedCodes = RegionCountryData.codes;

  static final Map<String, RegionCountryEntry> _byCode = {
    for (final e in entries) e.code: e,
  };

  static RegionCountryEntry? entryFor(String? code) {
    final cc = (code ?? '').trim().toUpperCase();
    return _byCode[cc];
  }

  /// Unknown / empty → [defaultCountry].
  static String normalize(String? raw) {
    final cc = (raw ?? '').trim().toUpperCase();
    if (_byCode.containsKey(cc)) {
      return cc;
    }
    return defaultCountry;
  }

  static bool isSupported(String? raw) {
    final cc = (raw ?? '').trim().toUpperCase();
    return _byCode.containsKey(cc);
  }

  /// Display name for [code] (falls back to code or US entry).
  static String displayName(String code, {required bool chineseUi}) {
    final e = entryFor(code) ?? entryFor(defaultCountry)!;
    return e.labelFor(chineseUi: chineseUi);
  }

  /// Filter by ISO code / English / Chinese name (case-insensitive).
  static List<RegionCountryEntry> filter(
    Iterable<RegionCountryEntry> source,
    String query,
  ) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) {
      return List<RegionCountryEntry>.of(source);
    }
    return [
      for (final e in source)
        if (e.code.toLowerCase().contains(q) ||
            e.nameEn.toLowerCase().contains(q) ||
            e.nameZh.contains(query.trim()))
          e,
    ];
  }

  /// A–Z by English name (Latin alphabet).
  static List<RegionCountryEntry> sortedForDisplay() {
    final list = List<RegionCountryEntry>.of(entries);
    list.sort(
      (a, b) => a.nameEn.toLowerCase().compareTo(b.nameEn.toLowerCase()),
    );
    return list;
  }
}
