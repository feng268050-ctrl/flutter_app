import 'dart:convert';

import 'package:cyber_hal/secrets.dart';
import 'package:cyber_hal/sys_info.dart';
import 'package:lws_hmi/platform/cloud/cloud_http_client.dart';
import 'package:lws_hmi/platform/cloud/device_cloud_ed25519.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeVendorIdentity extends VendorIdentityReader {
  _FakeVendorIdentity(this.sn);
  final String sn;

  @override
  Future<String> readSn() async => sn;
}

void main() {
  group('DeviceCloudEd25519Coordinator', () {
    late FakeKekProvider kek;
    late CloudEd25519SealedStore store;
    late CloudEd25519Identity identity;

    setUp(() {
      kek = FakeKekProvider();
      store = CloudEd25519SealedStore.memory();
      identity = CloudEd25519Identity(secrets: kek, store: store);
    });

    DeviceCloudEd25519Client clientWith(
      Future<CloudHttpResponse> Function(Uri url, {Object? jsonBody}) post,
    ) {
      return DeviceCloudEd25519Client(
        cloudHttp: CloudHttpClient(appVersion: 'test'),
        postJson: post,
      );
    }

    test('ensureActivated seals once and retries same pubkey', () async {
      final pubs = <String>[];
      final client = clientWith((url, {Object? jsonBody}) async {
        final map = jsonBody as Map;
        pubs.add(map['public_key'] as String);
        if (pubs.length == 1) {
          return const CloudHttpResponse(
            statusCode: 0,
            body: '',
            error: 'network down',
          );
        }
        return const CloudHttpResponse(
          statusCode: 200,
          body: '{"success":true,"code":200}',
        );
      });
      final coord = DeviceCloudEd25519Coordinator(
        identity: identity,
        client: client,
        vendorIdentity: _FakeVendorIdentity('SNTEST'),
      );
      final base = Uri.parse('https://api.example.com');

      final first = await coord.ensureActivated(
        pinnedBase: base,
        cloudServicesEnabled: true,
      );
      expect(first.status, DeviceCloudEd25519EnsureStatus.retryLater);
      expect(await identity.hasSealedBlob(), isTrue);

      final second = await coord.ensureActivated(
        pinnedBase: base,
        cloudServicesEnabled: true,
      );
      expect(second.status, DeviceCloudEd25519EnsureStatus.activated);
      expect(pubs, hasLength(2));
      expect(pubs[0], pubs[1]);
      expect(base64Decode(pubs[0]), hasLength(32));
    });

    test('skips when cloud services off', () async {
      final client = clientWith((url, {Object? jsonBody}) async {
        fail('should not call activate');
      });
      final coord = DeviceCloudEd25519Coordinator(
        identity: identity,
        client: client,
        vendorIdentity: _FakeVendorIdentity('SNTEST'),
      );
      final r = await coord.ensureActivated(
        pinnedBase: Uri.parse('https://api.example.com'),
        cloudServicesEnabled: false,
      );
      expect(r.status, DeviceCloudEd25519EnsureStatus.skipped);
      expect(await identity.hasSealedBlob(), isFalse);
    });

    test('skips empty vendor SN', () async {
      final client = clientWith((url, {Object? jsonBody}) async {
        fail('should not call activate');
      });
      final coord = DeviceCloudEd25519Coordinator(
        identity: identity,
        client: client,
        vendorIdentity: _FakeVendorIdentity(''),
      );
      final r = await coord.ensureActivated(
        pinnedBase: Uri.parse('https://api.example.com'),
        cloudServicesEnabled: true,
      );
      expect(r.status, DeviceCloudEd25519EnsureStatus.skipped);
    });

    test('foreign key conflict fail closed without overwrite', () async {
      await identity.ensureLocalKey(productSn: 'SNTEST');
      final before = await store.readSealed();
      final client = clientWith((url, {Object? jsonBody}) async {
        return const CloudHttpResponse(
          statusCode: 409,
          body:
              '{"success":false,"errorCode":"DEVICE_ALREADY_ACTIVATED"}',
        );
      });
      final coord = DeviceCloudEd25519Coordinator(
        identity: identity,
        client: client,
        vendorIdentity: _FakeVendorIdentity('SNTEST'),
      );
      final r = await coord.ensureActivated(
        pinnedBase: Uri.parse('https://api.example.com'),
        cloudServicesEnabled: true,
      );
      expect(r.status, DeviceCloudEd25519EnsureStatus.foreignKeyConflict);
      expect(await store.readSealed(), before);
    });

    test('mintAccessToken posts signature over TLS', () async {
      await identity.ensureLocalKey(productSn: 'SNTEST');
      Map<String, Object?>? body;
      final client = clientWith((url, {Object? jsonBody}) async {
        body = Map<String, Object?>.from(jsonBody as Map);
        return const CloudHttpResponse(
          statusCode: 200,
          body:
              '{"success":true,"data":{"access_token":"hdr.payload.sig"}}',
        );
      });
      final coord = DeviceCloudEd25519Coordinator(
        identity: identity,
        client: client,
        vendorIdentity: _FakeVendorIdentity('SNTEST'),
      );
      final r = await coord.mintAccessToken(
        pinnedBase: Uri.parse('https://api.example.com'),
        cloudServicesEnabled: true,
      );
      expect(r.ok, isTrue);
      expect(r.accessToken, 'hdr.payload.sig');
      expect(body!['ts'], isA<int>());
      expect(body!['nonce'], isA<String>());
      final sig = base64Decode(body!['signature'] as String);
      expect(sig, hasLength(64));
    });
  });
}
