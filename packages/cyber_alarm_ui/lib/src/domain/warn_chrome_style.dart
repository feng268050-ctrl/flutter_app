/// Visual chrome for warn frost dialogs (independent of cyber_alarm severity).
enum WarnChromeStyle {
  /// Red siren icon + red title (hard / non-bypass presentation).
  warn,

  /// Info icon + black title (bypassable / informational presentation).
  info,
}

extension WarnChromeStyleX on WarnChromeStyle {
  bool get isInfo => this == WarnChromeStyle.info;
}
