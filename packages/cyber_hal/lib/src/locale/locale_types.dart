/// Preferred UI / IME language (BCP-47 wire values).
enum PreferredLanguage {
  enUs('en-US'),
  zhCn('zh-CN'),
  zhTw('zh-TW');

  const PreferredLanguage(this.wire);
  final String wire;

  static const PreferredLanguage defaultValue = PreferredLanguage.enUs;

  /// Parse wire / legacy tokens; unsupported → [defaultValue].
  static PreferredLanguage parse(String? raw) {
    switch ((raw ?? '').trim()) {
      case 'zh-CN':
      case 'ZH':
        return PreferredLanguage.zhCn;
      case 'zh-TW':
        return PreferredLanguage.zhTw;
      case 'en-US':
      case 'EN':
        return PreferredLanguage.enUs;
      default:
        return PreferredLanguage.defaultValue;
    }
  }

  /// Endonym — always the language’s own script/name.
  String get endonym => switch (this) {
        PreferredLanguage.zhCn => '简体中文',
        PreferredLanguage.zhTw => '繁體中文',
        PreferredLanguage.enUs => 'English',
      };

  bool get isChinese =>
      this == PreferredLanguage.zhCn || this == PreferredLanguage.zhTw;

  static const supported = <PreferredLanguage>[
    PreferredLanguage.enUs,
    PreferredLanguage.zhCn,
    PreferredLanguage.zhTw,
  ];

  static const supportedWires = <String>[
    'en-US',
    'zh-CN',
    'zh-TW',
  ];
}

/// Measurement system preference.
enum UnitSystem {
  metric('Metric'),
  imperial('Imperial');

  const UnitSystem(this.wire);
  final String wire;

  static const UnitSystem defaultValue = UnitSystem.metric;

  static UnitSystem parse(String? raw) {
    final v = (raw ?? '').trim();
    if (v == UnitSystem.imperial.wire) {
      return UnitSystem.imperial;
    }
    if (v == UnitSystem.metric.wire) {
      return UnitSystem.metric;
    }
    return UnitSystem.defaultValue;
  }

  static const supported = <UnitSystem>[
    UnitSystem.metric,
    UnitSystem.imperial,
  ];

  static const supportedWires = <String>['Metric', 'Imperial'];
}

/// Product Region as ISO 3166-1 alpha-2 (+ XK). Normalize via [RegionCatalog].
typedef Region = String;
