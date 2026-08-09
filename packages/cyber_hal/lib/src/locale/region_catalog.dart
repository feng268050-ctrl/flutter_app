import 'package:cyber_hal/src/locale/region_catalog_data.dart';

/// One ISO 3166-1 alpha-2 country / territory (+ XK).
final class RegionCatalogEntry {
  const RegionCatalogEntry({
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

  /// IANA timezone seed when Region-linked (capital / primary zone).
  final String defaultTimezone;

  /// Primary NTP hostname (must be in NTP catalog or normalize safely).
  final String preferredNtp;

  /// Localized label: Chinese UI uses [nameZh], otherwise [nameEn].
  String labelFor({required bool chineseUi}) => chineseUi ? nameZh : nameEn;
}

/// Product Region catalog — full ISO 3166-1 (+ XK) with TZ / NTP defaults.
///
/// Product default is [defaultRegion] (`US`). Region-driven NTP MUST NOT be
/// `cn.pool.ntp.org`.
abstract final class RegionCatalog {
  static const preferredNtpDefault = RegionCatalogData.preferredNtp;

  /// Legacy Asia-centric timezone treated as Region-linked on first seed.
  static const legacyAsiaTimezone = 'Asia/Shanghai';

  /// Legacy NTP treated as Region-linked for clock seeding.
  static const legacyChinaNtp = 'cn.pool.ntp.org';

  static const defaultRegion = 'US';

  static const entries = RegionCatalogData.entries;

  static const supportedCodes = RegionCatalogData.codes;

  static final Map<String, RegionCatalogEntry> _byCode = {
    for (final e in entries) e.code: e,
  };

  static RegionCatalogEntry? entryFor(String? code) {
    final cc = (code ?? '').trim().toUpperCase();
    return _byCode[cc];
  }

  /// Unknown / empty → [defaultRegion].
  static String normalize(String? raw) {
    final cc = (raw ?? '').trim().toUpperCase();
    if (_byCode.containsKey(cc)) {
      return cc;
    }
    return defaultRegion;
  }

  static bool isSupported(String? raw) {
    final cc = (raw ?? '').trim().toUpperCase();
    return _byCode.containsKey(cc);
  }

  /// Display name for [code] (falls back to code or US entry).
  static String displayName(String code, {required bool chineseUi}) {
    final e = entryFor(code) ?? entryFor(defaultRegion)!;
    return e.labelFor(chineseUi: chineseUi);
  }

  /// Filter by ISO code / English / Chinese name (case-insensitive).
  static List<RegionCatalogEntry> filter(
    Iterable<RegionCatalogEntry> source,
    String query,
  ) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) {
      return List<RegionCatalogEntry>.of(source);
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
  static List<RegionCatalogEntry> sortedForDisplay() {
    final list = List<RegionCatalogEntry>.of(entries);
    list.sort(
      (a, b) => a.nameEn.toLowerCase().compareTo(b.nameEn.toLowerCase()),
    );
    return list;
  }
}
