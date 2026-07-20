import 'dart:async';

import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/features/settings/presentation/widgets/settings_chrome.dart';
import 'package:lws_hmi/platform/http/http_proxy_config.dart';

/// HTTP Proxy — phone-style rows (matches lws-ui proxy activity shape).
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
    TextInputType? keyboardType,
  }) async {
    final ctrl = TextEditingController(text: initial);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          obscureText: obscure,
          keyboardType: keyboardType,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () {
              CyberClickSoundRegistry.playClick();
              Navigator.pop(ctx, false);
            },
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              CyberClickSoundRegistry.playClick();
              Navigator.pop(ctx, true);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (ok == true) onSave(ctrl.text);
  }

  @override
  Widget build(BuildContext context) {
    return SettingsScaffold(
      title: 'HTTP Proxy',
      body: SettingsScrollView(
        children: [
          const SettingsSectionHeader('Proxy'),
          SettingsGroup(
            children: [
              SettingsSwitchRow(
                title: 'HTTP Proxy',
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
                title: 'Server',
                value: _host.isEmpty ? 'Not Set' : _host,
                onTap: _busy
                    ? null
                    : () => _editField(
                          title: 'Server',
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
                title: 'Port',
                value: '$_port',
                onTap: _busy
                    ? null
                    : () => _editField(
                          title: 'Port',
                          initial: '$_port',
                          keyboardType: TextInputType.number,
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
