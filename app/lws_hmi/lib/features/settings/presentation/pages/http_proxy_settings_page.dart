import 'dart:async';

import 'package:cyber_ime/cyber_ime.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/features/settings/presentation/widgets/settings_chrome.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';
import 'package:lws_hmi/platform/http/http_proxy_config.dart';
import 'package:lws_hmi/ui/cyber/cyber_ime_input_dialog.dart';

/// Proxy settings — phone-style rows (matches lws-ui proxy activity shape).
class HttpProxySettingsPage extends StatefulWidget {
  const HttpProxySettingsPage({super.key, required this.services});

  final AppServices services;

  @override
  State<HttpProxySettingsPage> createState() => _HttpProxySettingsPageState();
}

class _HttpProxySettingsPageState extends State<HttpProxySettingsPage> {
  bool _enabled = false;
  String _host = '';
  int _port = 8080;
  String _user = '';
  String _pass = '';
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final p = await widget.services.http.getProxy();
      if (!mounted) return;
      setState(() {
        _enabled = p.enabled;
        _host = p.host;
        _port = p.port;
        _user = p.username;
        _pass = p.password;
      });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Future<void> _save(HttpProxyConfig config) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.services.http.setProxy(config);
      await _load();
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editField({
    required String title,
    required String initial,
    required ValueChanged<String> onSave,
    bool obscure = false,
    CyberImeFieldType fieldType = CyberImeFieldType.text,
  }) async {
    final value = await showCyberImeInputDialog(
      context: context,
      title: title,
      fieldType: fieldType,
      initial: initial,
      obscureText: obscure,
    );
    if (value != null) onSave(value);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SettingsScaffold(
      title: l10n.httpProxySettingsTitle,
      body: SettingsScrollView(
        children: [
          SettingsGroup(
            children: [
              SettingsSwitchRow(
                title: l10n.httpProxyEnable,
                value: _enabled,
                onChanged: _busy
                    ? null
                    : (v) => unawaited(
                          _save(
                            HttpProxyConfig(
                              enabled: v,
                              host: _host,
                              port: _port,
                              username: _user,
                              password: _pass,
                            ),
                          ),
                        ),
              ),
              SettingsNavRow(
                title: l10n.httpProxyHost,
                value: _host.isEmpty ? l10n.valueNotSet : _host,
                onTap: _busy
                    ? null
                    : () => _editField(
                          title: l10n.httpProxyHost,
                          initial: _host,
                          onSave: (v) => unawaited(
                            _save(
                              HttpProxyConfig(
                                enabled: _enabled,
                                host: v.trim(),
                                port: _port,
                                username: _user,
                                password: _pass,
                              ),
                            ),
                          ),
                        ),
              ),
              SettingsNavRow(
                title: l10n.httpProxyPort,
                value: '$_port',
                onTap: _busy
                    ? null
                    : () => _editField(
                          title: l10n.httpProxyPort,
                          initial: '$_port',
                          fieldType: CyberImeFieldType.number,
                          onSave: (v) {
                            final p = int.tryParse(v.trim()) ?? _port;
                            unawaited(
                              _save(
                                HttpProxyConfig(
                                  enabled: _enabled,
                                  host: _host,
                                  port: p,
                                  username: _user,
                                  password: _pass,
                                ),
                              ),
                            );
                          },
                        ),
              ),
              SettingsNavRow(
                title: l10n.httpProxyAuthType,
                value: _user.isEmpty ? l10n.offLabel : _user,
                onTap: _busy
                    ? null
                    : () async {
                        await _editField(
                          title: l10n.httpProxyUsername,
                          initial: _user,
                          onSave: (u) async {
                            await _editField(
                              title: l10n.httpProxyPassword,
                              initial: _pass,
                              obscure: true,
                              fieldType: CyberImeFieldType.password,
                              onSave: (pw) => unawaited(
                                _save(
                                  HttpProxyConfig(
                                    enabled: _enabled,
                                    host: _host,
                                    port: _port,
                                    username: u.trim(),
                                    password: pw,
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
              ),
            ],
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.redAccent),
              ),
            ),
        ],
      ),
    );
  }
}
