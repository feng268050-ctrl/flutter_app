import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lws_hmi/platform/http/http_client_controller.dart';
import 'package:lws_hmi/platform/http/http_proxy_config.dart';

/// P2.1 Demo: HTTP(S) proxy + outbound request probe.
class HttpDemoSection extends StatefulWidget {
  const HttpDemoSection({super.key, required this.controller});

  final HttpClientController controller;

  @override
  State<HttpDemoSection> createState() => _HttpDemoSectionState();
}

class _HttpDemoSectionState extends State<HttpDemoSection> {
  final _host = TextEditingController();
  final _port = TextEditingController(text: '8080');
  final _user = TextEditingController();
  final _pass = TextEditingController();
  final _url = TextEditingController(text: 'https://www.baidu.com/');
  bool _proxyEnabled = false;
  bool _busy = false;
  String _result = '';

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final p = await widget.controller.getProxy();
      if (!mounted) {
        return;
      }
      setState(() {
        _proxyEnabled = p.enabled;
        _host.text = p.host;
        _port.text = '${p.port}';
        _user.text = p.username;
        _pass.text = p.password;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _result = 'proxy load: $e');
      }
    }
  }

  @override
  void dispose() {
    _host.dispose();
    _port.dispose();
    _user.dispose();
    _pass.dispose();
    _url.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'HTTP / Proxy',
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Use proxy', style: TextStyle(color: Colors.white)),
          value: _proxyEnabled,
          onChanged: _busy ? null : (v) => setState(() => _proxyEnabled = v),
        ),
        _field(_host, 'Proxy host'),
        _field(_port, 'Proxy port'),
        _field(_user, 'Proxy user (optional)'),
        _field(_pass, 'Proxy password', obscure: true),
        FilledButton(
          onPressed: _busy
              ? null
              : () => unawaited(() async {
                    setState(() => _busy = true);
                    try {
                      final host = _host.text.trim();
                      if (_proxyEnabled && host.isEmpty) {
                        throw StateError('proxy host is empty');
                      }
                      await widget.controller.setProxy(
                        HttpProxyConfig(
                          enabled: _proxyEnabled,
                          host: host,
                          port: int.tryParse(_port.text.trim()) ?? 8080,
                          username: _user.text.trim(),
                          password: _pass.text,
                        ),
                      );
                      setState(() => _result = 'proxy saved');
                    } catch (e) {
                      setState(() => _result = 'proxy save: $e');
                    } finally {
                      setState(() => _busy = false);
                    }
                  }()),
          child: const Text('Save proxy'),
        ),
        const SizedBox(height: 12),
        _field(_url, 'Request URL'),
        FilledButton(
          onPressed: _busy
              ? null
              : () => unawaited(() async {
                    setState(() {
                      _busy = true;
                      _result = 'requesting…';
                    });
                    try {
                      final uri = Uri.parse(_url.text.trim());
                      final r = await widget.controller.request(
                        method: 'GET',
                        url: uri,
                      );
                      setState(() => _result = r.summary);
                    } catch (e) {
                      setState(() => _result = 'request: $e');
                    } finally {
                      setState(() => _busy = false);
                    }
                  }()),
          child: const Text('Send request'),
        ),
        const SizedBox(height: 8),
        SelectableText(
          _result.isEmpty ? '(no result yet)' : _result,
          style: TextStyle(
            color: Colors.white.withOpacity(0.85),
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _field(
    TextEditingController c,
    String label, {
    bool obscure = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: TextField(
        controller: c,
        obscureText: obscure,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
          enabledBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: Colors.white24),
          ),
        ),
      ),
    );
  }
}
