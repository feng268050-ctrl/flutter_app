import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cyber_hal/cyber_hal.dart';
import 'package:cyber_hal/network/cloud_http_client.dart';
import 'package:cyber_hal/network/cloud_origin.dart';
import 'package:cyber_hal/secrets.dart';
import 'package:cyber_hal/sys_info.dart';
import 'package:flutter/foundation.dart';

/// Injectable POST JSON for [DeviceCloudEd25519Client] (tests).
typedef DeviceCloudEd25519PostJson = Future<CloudHttpResponse> Function(
  Uri url, {
  Object? jsonBody,
});

/// Result of `POST /v1/devices/:sn/activate`.
final class DeviceActivateResult {
  const DeviceActivateResult({
    required this.ok,
    this.statusCode = 0,
    this.error,
    this.errorCode,
    this.foreignKeyConflict = false,
  });

  final bool ok;
  final int statusCode;
  final String? error;
  final String? errorCode;

  /// Server already activated under a different public key (fail closed).
  final bool foreignKeyConflict;
}

/// Result of `POST /v1/devices/:sn/token`.
final class DeviceAccessTokenResult {
  const DeviceAccessTokenResult({
    required this.ok,
    this.accessToken,
    this.statusCode = 0,
    this.error,
    this.errorCode,
  });

  final bool ok;
  final String? accessToken;
  final int statusCode;
  final String? error;
  final String? errorCode;
}

/// Outcome of [DeviceCloudEd25519Coordinator.ensureActivated].
enum DeviceCloudEd25519EnsureStatus {
  /// Local key ready and activate succeeded (or same-key idempotent).
  activated,

  /// Skipped: 云服务 off, no HTTPS origin, empty VS SN, no VS, etc.
  skipped,

  /// Transient failure (network / server); sealed key kept for retry.
  retryLater,

  /// Permanent conflict: server activated under a different key.
  foreignKeyConflict,
}

final class DeviceCloudEd25519EnsureResult {
  const DeviceCloudEd25519EnsureResult({
    required this.status,
    this.publicKeyBase64,
    this.error,
  });

  final DeviceCloudEd25519EnsureStatus status;
  final String? publicKeyBase64;
  final String? error;
}

/// HTTP client for device activate + Ed25519-proven token mint.
final class DeviceCloudEd25519Client {
  DeviceCloudEd25519Client({
    required this.cloudHttp,
    DeviceCloudEd25519PostJson? postJson,
  }) : _postJson = postJson ??
            ((url, {Object? jsonBody}) =>
                cloudHttp.postJson(url, jsonBody: jsonBody));

  final CloudHttpClient cloudHttp;
  final DeviceCloudEd25519PostJson _postJson;

  Future<DeviceActivateResult> activate({
    required Uri pinnedBase,
    required String deviceSn,
    required String publicKeyBase64,
  }) async {
    final sn = deviceSn.trim();
    if (sn.isEmpty) {
      return const DeviceActivateResult(ok: false, error: 'empty sn');
    }
    if (pinnedBase.scheme.toLowerCase() != 'https') {
      return const DeviceActivateResult(
        ok: false,
        error: 'activate requires https origin',
      );
    }
    final url = CloudApiOriginConfig.joinUnderBase(
      pinnedBase,
      '/v1/devices/${Uri.encodeComponent(sn)}/activate',
    );
    final resp = await _postJson(
      url,
      jsonBody: <String, String>{'public_key': publicKeyBase64},
    );
    final parsed = _parseApiResult(resp.body);
    if (resp.ok) {
      return DeviceActivateResult(
        ok: true,
        statusCode: resp.statusCode,
        errorCode: parsed.errorCode,
      );
    }
    final code = (parsed.errorCode ?? '').toUpperCase();
    final foreign = resp.statusCode == 409 ||
        code == 'DEVICE_ALREADY_ACTIVATED';
    return DeviceActivateResult(
      ok: false,
      statusCode: resp.statusCode,
      error: resp.error ?? parsed.message ?? 'HTTP ${resp.statusCode}',
      errorCode: parsed.errorCode,
      foreignKeyConflict: foreign,
    );
  }

  Future<DeviceAccessTokenResult> mintAccessToken({
    required Uri pinnedBase,
    required String deviceSn,
    required Uint8List signature,
    required int tsUnixSeconds,
    required String nonce,
  }) async {
    final sn = deviceSn.trim();
    if (sn.isEmpty) {
      return const DeviceAccessTokenResult(ok: false, error: 'empty sn');
    }
    if (pinnedBase.scheme.toLowerCase() != 'https') {
      return const DeviceAccessTokenResult(
        ok: false,
        error: 'token mint requires https origin',
      );
    }
    final url = CloudApiOriginConfig.joinUnderBase(
      pinnedBase,
      '/v1/devices/${Uri.encodeComponent(sn)}/token',
    );
    final resp = await _postJson(
      url,
      jsonBody: <String, Object?>{
        'ts': tsUnixSeconds,
        'nonce': nonce,
        'signature': base64Encode(signature),
      },
    );
    final parsed = _parseApiResult(resp.body);
    if (!resp.ok) {
      return DeviceAccessTokenResult(
        ok: false,
        statusCode: resp.statusCode,
        error: resp.error ?? parsed.message ?? 'HTTP ${resp.statusCode}',
        errorCode: parsed.errorCode,
      );
    }
    final token = parsed.accessToken;
    if (token == null || token.isEmpty) {
      return DeviceAccessTokenResult(
        ok: false,
        statusCode: resp.statusCode,
        error: 'missing access_token',
        errorCode: parsed.errorCode,
      );
    }
    return DeviceAccessTokenResult(
      ok: true,
      accessToken: token,
      statusCode: resp.statusCode,
      errorCode: parsed.errorCode,
    );
  }

  static _ParsedApi _parseApiResult(String body) {
    if (body.trim().isEmpty) {
      return const _ParsedApi();
    }
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map) {
        return const _ParsedApi();
      }
      final map = Map<String, dynamic>.from(decoded);
      final errorCode =
          map['errorCode']?.toString() ?? map['error_code']?.toString();
      final message = map['message']?.toString() ?? map['msg']?.toString();
      String? accessToken;
      final data = map['data'];
      if (data is Map) {
        accessToken = data['access_token']?.toString() ??
            data['accessToken']?.toString();
      }
      return _ParsedApi(
        errorCode: errorCode,
        message: message,
        accessToken: accessToken,
      );
    } catch (_) {
      return const _ParsedApi();
    }
  }
}

final class _ParsedApi {
  const _ParsedApi({
    this.errorCode,
    this.message,
    this.accessToken,
  });

  final String? errorCode;
  final String? message;
  final String? accessToken;
}

/// Ensure-activated + optional token mint, gated by 云服务 / HTTPS / VS SN.
final class DeviceCloudEd25519Coordinator {
  DeviceCloudEd25519Coordinator({
    required this.identity,
    required this.client,
    required this.vendorIdentity,
    Random? random,
  }) : _random = random ?? Random.secure();

  final CloudEd25519Identity identity;
  final DeviceCloudEd25519Client client;
  final VendorIdentityReader vendorIdentity;
  final Random _random;

  String? _cachedAccessToken;
  DateTime? _cachedAccessTokenExp;

  /// Last minted device access token (opaque Bearer), if any.
  String? get cachedAccessToken => _cachedAccessToken;

  /// Drop cached Bearer (e.g. when 云服务 turns off).
  void clearCachedAccessToken() {
    _cachedAccessToken = null;
    _cachedAccessTokenExp = null;
  }

  /// Product SN from Vendor Storage only (empty when unset — no chipId fallback).
  Future<String> readVendorProductSn() async {
    return (await vendorIdentity.readSn()).trim();
  }

  /// Generate/seal if needed, then POST activate with the same public key.
  Future<DeviceCloudEd25519EnsureResult> ensureActivated({
    required Uri pinnedBase,
    required bool cloudServicesEnabled,
  }) async {
    if (!cloudServicesEnabled) {
      return const DeviceCloudEd25519EnsureResult(
        status: DeviceCloudEd25519EnsureStatus.skipped,
        error: 'cloud services off',
      );
    }
    if (pinnedBase.scheme.toLowerCase() != 'https') {
      return const DeviceCloudEd25519EnsureResult(
        status: DeviceCloudEd25519EnsureStatus.skipped,
        error: 'https origin required',
      );
    }
    final sn = await readVendorProductSn();
    if (sn.isEmpty) {
      return const DeviceCloudEd25519EnsureResult(
        status: DeviceCloudEd25519EnsureStatus.skipped,
        error: 'empty vendor storage sn',
      );
    }

    CloudEd25519KeyMaterial? material;
    try {
      material = await identity.ensureLocalKey(productSn: sn);
    } on HalIoException catch (e) {
      // Emulator / missing VS helpers → fail closed (skip, do not invent key).
      debugPrint('cloud-ed25519: local key ensure failed: $e');
      return DeviceCloudEd25519EnsureResult(
        status: DeviceCloudEd25519EnsureStatus.skipped,
        error: e.message,
      );
    } catch (e) {
      debugPrint('cloud-ed25519: local key ensure failed: $e');
      return DeviceCloudEd25519EnsureResult(
        status: DeviceCloudEd25519EnsureStatus.retryLater,
        error: e.toString(),
      );
    }
    if (material == null) {
      return const DeviceCloudEd25519EnsureResult(
        status: DeviceCloudEd25519EnsureStatus.skipped,
        error: 'no local key',
      );
    }

    final pub = material.publicKeyBase64;
    final act = await client.activate(
      pinnedBase: pinnedBase,
      deviceSn: sn,
      publicKeyBase64: pub,
    );
    if (act.ok) {
      return DeviceCloudEd25519EnsureResult(
        status: DeviceCloudEd25519EnsureStatus.activated,
        publicKeyBase64: pub,
      );
    }
    if (act.foreignKeyConflict) {
      // Same-key idempotent is already ok=true from server. Different key →
      // fail closed; do not overwrite local sealed blob.
      // Re-check: if server returned 409, treat as foreign (client marks all
      // 409 as foreign). Retry with same key after true same-key 200 is ok.
      return DeviceCloudEd25519EnsureResult(
        status: DeviceCloudEd25519EnsureStatus.foreignKeyConflict,
        publicKeyBase64: pub,
        error: act.error ?? act.errorCode,
      );
    }
    return DeviceCloudEd25519EnsureResult(
      status: DeviceCloudEd25519EnsureStatus.retryLater,
      publicKeyBase64: pub,
      error: act.error ?? act.errorCode,
    );
  }

  /// Mint (or return cached) device access_token via Ed25519 identity proof.
  Future<DeviceAccessTokenResult> mintAccessToken({
    required Uri pinnedBase,
    required bool cloudServicesEnabled,
    bool forceRefresh = false,
  }) async {
    if (!cloudServicesEnabled) {
      return const DeviceAccessTokenResult(
        ok: false,
        error: 'cloud services off',
      );
    }
    if (pinnedBase.scheme.toLowerCase() != 'https') {
      return const DeviceAccessTokenResult(
        ok: false,
        error: 'https origin required',
      );
    }
    if (!forceRefresh) {
      final cached = _cachedAccessToken;
      final exp = _cachedAccessTokenExp;
      // Proactive refresh when remaining lifetime < 1h (opaque JWT aside from exp).
      if (cached != null &&
          cached.isNotEmpty &&
          exp != null &&
          exp.isAfter(DateTime.now().toUtc().add(const Duration(hours: 1)))) {
        return DeviceAccessTokenResult(ok: true, accessToken: cached);
      }
    }
    final sn = await readVendorProductSn();
    if (sn.isEmpty) {
      return const DeviceAccessTokenResult(
        ok: false,
        error: 'empty vendor storage sn',
      );
    }
    final material = await identity.loadUnsealed(sn);
    if (material == null) {
      return const DeviceAccessTokenResult(
        ok: false,
        error: 'no sealed cloud key',
      );
    }
    final ts = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
    final nonce = _newNonce();
    final signature = await identity.signTokenMessage(
      privateKeySeed: material.privateKeySeed,
      sn: sn,
      tsUnixSeconds: ts,
      nonce: nonce,
    );
    final result = await client.mintAccessToken(
      pinnedBase: pinnedBase,
      deviceSn: sn,
      signature: signature,
      tsUnixSeconds: ts,
      nonce: nonce,
    );
    if (result.ok && result.accessToken != null) {
      _cachedAccessToken = result.accessToken;
      _cachedAccessTokenExp = _expFromJwt(result.accessToken!) ??
          DateTime.now().toUtc().add(const Duration(hours: 12));
    }
    return result;
  }

  String _newNonce() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  /// Best-effort read of JWT `exp` (opaque otherwise).
  static DateTime? _expFromJwt(String jwt) {
    try {
      final parts = jwt.split('.');
      if (parts.length < 2) {
        return null;
      }
      var payload = parts[1];
      final pad = payload.length % 4;
      if (pad > 0) {
        payload = payload.padRight(payload.length + (4 - pad), '=');
      }
      final json = utf8.decode(base64Url.decode(payload));
      final map = jsonDecode(json);
      if (map is! Map) {
        return null;
      }
      final exp = map['exp'];
      if (exp is num) {
        return DateTime.fromMillisecondsSinceEpoch(
          exp.toInt() * 1000,
          isUtc: true,
        );
      }
    } catch (_) {}
    return null;
  }
}
