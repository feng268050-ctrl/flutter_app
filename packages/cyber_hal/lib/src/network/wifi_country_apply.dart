import 'dart:io';

/// Upsert wpa `country=` and apply cfg80211 regdomain (soft-fail friendly).
///
/// Product Country preference uses this so regulatory updates without reboot.
/// Prefer `iw reg set` + conf upsert; optionally `wpa_cli set country` when
/// the control interface is up (engineering path — not D-Bus primary).
abstract final class WifiCountryApply {
  static const defaultWpaConfPath =
      '/var/lib/wpa_supplicant/wpa_supplicant.conf';

  /// Pure helper: ensure `country=<cc>` exists in wpa conf text.
  static String upsertCountryInConf(String confText, String country) {
    final cc = country.trim().toUpperCase();
    final lines = confText.split('\n');
    var replaced = false;
    final out = <String>[];
    for (final line in lines) {
      if (line.trimLeft().startsWith('country=')) {
        if (!replaced) {
          out.add('country=$cc');
          replaced = true;
        }
        continue;
      }
      out.add(line);
    }
    if (!replaced) {
      // Insert after update_config if present, else at top.
      var inserted = false;
      final withInsert = <String>[];
      for (final line in out) {
        withInsert.add(line);
        if (!inserted && line.trimLeft().startsWith('update_config=')) {
          withInsert.add('country=$cc');
          inserted = true;
        }
      }
      if (!inserted) {
        return 'country=$cc\n${out.join('\n')}';
      }
      return withInsert.join('\n');
    }
    return out.join('\n');
  }

  /// Write conf + `iw reg set` + best-effort wpa_cli. Never throws to callers
  /// that catch — returns false on soft failure.
  static Future<bool> apply({
    required String country,
    String wpaConfPath = defaultWpaConfPath,
    String? iface,
    Future<ProcessResult> Function(String exe, List<String> args)? run,
  }) async {
    final cc = country.trim().toUpperCase();
    if (cc.length != 2) {
      return false;
    }
    final runner = run ?? ((exe, args) => Process.run(exe, args));
    try {
      final f = File(wpaConfPath);
      if (await f.exists()) {
        final next = upsertCountryInConf(await f.readAsString(), cc);
        await f.writeAsString(next, flush: true);
      } else {
        await f.parent.create(recursive: true);
        await f.writeAsString(
          'ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=root\n'
          'update_config=1\n'
          'country=$cc\n',
          flush: true,
        );
        try {
          await Process.run('chmod', ['600', wpaConfPath]);
        } catch (_) {}
      }
    } catch (_) {
      // Continue — regdomain may still apply.
    }

    var ok = false;
    final ifc = (iface ?? '').trim().isEmpty ? 'wlan0' : iface!.trim();
    try {
      final r = await runner('wpa_cli', ['-i', ifc, 'set', 'country', cc]);
      if (r.exitCode == 0) {
        ok = true;
        await runner('wpa_cli', ['-i', ifc, 'save_config']);
      }
    } catch (_) {}

    // Optional when `iw` is packaged; soft-fail on appliances without it.
    try {
      final r = await runner('iw', ['reg', 'set', cc]);
      if (r.exitCode == 0) {
        ok = true;
      }
    } catch (_) {}

    return ok;
  }
}
