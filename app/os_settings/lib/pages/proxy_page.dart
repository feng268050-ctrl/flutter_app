import 'dart:async';

import 'package:cyber_ime/cyber_ime.dart';
import 'package:cyber_hal/network.dart';
import 'package:flutter/material.dart';
import 'package:os_settings/app/os_settings_app.dart';
import 'package:os_settings/chrome/settings_chrome.dart';
import 'package:os_settings/ui/cyber_ime_input_dialog.dart';

/// HTTP proxy settings using HAL [LinuxProxy].
class ProxyPage extends StatefulWidget {
  const ProxyPage({super.key});

  @override
  State<ProxyPage> createState() => _ProxyPageState();
}

class _ProxyPageState extends State<ProxyPage> {
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

  ProxyUri? get _httpUri {
    if (_host.trim().isEmpty) return null;
    return ProxyUri(
      scheme: ProxyScheme.http,
      host: _host.trim(),
      port: _port,
      username: _user.trim().isEmpty ? null : _user.trim(),
      password: _pass.isEmpty ? null : _pass,
    );
  }

  Future<void> _load() async {
    try {
      final p = await OsSettingsScope.of(context).proxy().getSettings();
      final http = p.httpProxy;
      if (!mounted) return;
      setState(() {
        _enabled = p.enabled;
        _host = http?.host ?? '';
        _port = http?.port ?? 8080;
        _user = http?.username ?? '';
        _pass = http?.password ?? '';
      });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Future<void> _save({
    bool? enabled,
    String? host,
    int? port,
    String? user,
    String? password,
  }) async {
    setState(() {
      _busy = true;
      _error = null;
      if (enabled != null) _enabled = enabled;
      if (host != null) _host = host;
      if (port != null) _port = port;
      if (user != null) _user = user;
      if (password != null) _pass = password;
    });
    try {
      final uri = _httpUri;
      await OsSettingsScope.of(context).proxy().setSettings(
            ProxySettings(
              enabled: _enabled,
              httpProxy: uri,
              httpsProxy: uri,
            ),
          );
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
    required Future<void> Function(String value) onSave,
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
    if (value != null) await onSave(value);
  }

  @override
  Widget build(BuildContext context) {
    return SettingsScaffold(
      title: 'HTTP Proxy',
      body: SettingsScrollView(
        children: [
          SettingsGroup(
            children: [
              SettingsSwitchRow(
                title: 'Enable Proxy',
                value: _enabled,
                onChanged: _busy
                    ? null
                    : (v) => unawaited(_save(enabled: v)),
              ),
              SettingsNavRow(
                title: 'Host',
                value: _host.isEmpty ? 'Not Set' : _host,
                onTap: _busy
                    ? null
                    : () => _editField(
                          title: 'Host',
                          initial: _host,
                          onSave: (v) => _save(host: v.trim()),
                        ),
              ),
              SettingsNavRow(
                title: 'Port',
                value: '$_port',
                onTap: _busy
                    ? null
                    : () => _editField(
                          title: 'Port',
                          initial: '$_port',
                          fieldType: CyberImeFieldType.number,
                          onSave: (v) async {
                            final p = int.tryParse(v.trim()) ?? _port;
                            await _save(port: p);
                          },
                        ),
              ),
              SettingsNavRow(
                title: 'Authentication',
                value: _user.isEmpty ? 'Off' : _user,
                onTap: _busy
                    ? null
                    : () async {
                        await _editField(
                          title: 'Username',
                          initial: _user,
                          onSave: (u) async {
                            await _editField(
                              title: 'Password',
                              initial: _pass,
                              obscure: true,
                              fieldType: CyberImeFieldType.password,
                              onSave: (pw) => _save(user: u.trim(), password: pw),
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
