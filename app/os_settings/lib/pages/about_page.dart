import 'dart:async';

import 'package:cyber_hal/sys_info.dart';
import 'package:flutter/material.dart';
import 'package:os_settings/app/os_settings_app.dart';
import 'package:os_settings/chrome/settings_chrome.dart';

/// About — Brand / Model / Serial Number from product identity.
///
/// Uses the root-shell-warmed [OsSettingsServices.cachedProductInfo] when
/// present (identity does not change at runtime); cold path loads once.
class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  String _brand = kUnavailable;
  String _model = kUnavailable;
  String _sn = kUnavailable;
  bool _loading = true;
  bool _hydrated = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_hydrated) return;
    _hydrated = true;
    final cached = OsSettingsScope.of(context).cachedProductInfo;
    if (cached != null) {
      _applyProduct(cached);
      return;
    }
    unawaited(_load());
  }

  void _applyProduct(ProductInfo product) {
    _brand = dashOr(product.brand);
    _model = dashOr(product.model);
    _sn = dashOr(product.sn);
    _loading = false;
  }

  Future<void> _load() async {
    try {
      final services = OsSettingsScope.of(context);
      final product = await services.productInfo();
      if (!mounted) return;
      setState(() => _applyProduct(product));
    } catch (_) {
      try {
        final services = OsSettingsScope.of(context);
        final snap = await services.sysInfo().snapshot();
        if (!mounted) return;
        setState(() {
          _brand = dashOr(snap.brand);
          _model = dashOr(snap.model);
          _sn = dashOr(snap.serialNumber);
          _loading = false;
        });
      } catch (_) {
        if (mounted) setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SettingsScaffold(
      title: 'About',
      body: SettingsScrollView(
        children: [
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            SettingsGroup(
              bottomInset: 0,
              children: [
                SettingsValueRow(title: 'Brand', value: _brand),
                SettingsValueRow(title: 'Model', value: _model),
                SettingsValueRow(title: 'Serial Number', value: _sn),
              ],
            ),
        ],
      ),
    );
  }
}
