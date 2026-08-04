import 'dart:convert';

/// Mutates camera `GET/PUT /Media/Video/overlays?channel=1` JSON (lws-ui parity).
abstract final class CameraVideoOverlayEditor {
  static const overlaysChannel1Path = 'Media/Video/overlays?channel=1';
  static const nameOverlayYOffset = 50;

  /// Returns overlay config root when [response] is a successful payload
  /// (`VideoOverlay` present, no IPC `errCode` error wrapper).
  static Map<String, Object?>? parseOverlayConfig(Object? response) {
    if (response is! Map) {
      return null;
    }
    final map = _asStringKeyedMap(response);
    if (map.containsKey('errCode') && map['errCode'] != null) {
      return null;
    }
    final videoOverlay = map['VideoOverlay'];
    if (videoOverlay is! Map) {
      return null;
    }
    return map;
  }

  /// Updates `VideoOverlay.NameOverlay`.
  ///
  /// When [enable] == 1: `enable=1`, `x=positionX`, `y=positionY + 50`, `name`.
  /// When [enable] == 0: `enable=0` (hide device name).
  static Map<String, Object?>? applyNameOverlay(
    Map<String, Object?> config, {
    required int enable,
    required int positionX,
    required int positionY,
    required String name,
  }) {
    final root = _deepCopyMap(config);
    final videoOverlayRaw = root['VideoOverlay'];
    if (videoOverlayRaw is! Map) {
      return null;
    }
    final videoOverlay = _asStringKeyedMap(videoOverlayRaw);
    root['VideoOverlay'] = videoOverlay;

    final nameRaw = videoOverlay['NameOverlay'];
    final nameOverlay = nameRaw is Map
        ? _asStringKeyedMap(nameRaw)
        : <String, Object?>{};
    videoOverlay['NameOverlay'] = nameOverlay;

    if (enable == 1) {
      nameOverlay['enable'] = 1;
      nameOverlay['x'] = positionX;
      nameOverlay['y'] = positionY + nameOverlayYOffset;
      nameOverlay['name'] = name;
    } else {
      nameOverlay['enable'] = 0;
    }
    return root;
  }

  /// Decode a JSON string into a map for [parseOverlayConfig].
  static Map<String, Object?>? decodeJsonObject(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map) {
        return null;
      }
      return _asStringKeyedMap(decoded);
    } catch (_) {
      return null;
    }
  }

  static Map<String, Object?> _asStringKeyedMap(Map<dynamic, dynamic> raw) {
    return <String, Object?>{
      for (final e in raw.entries) e.key.toString(): e.value,
    };
  }

  static Map<String, Object?> _deepCopyMap(Map<String, Object?> source) {
    final out = <String, Object?>{};
    for (final e in source.entries) {
      final v = e.value;
      if (v is Map) {
        out[e.key] = _deepCopyMap(_asStringKeyedMap(v));
      } else if (v is List) {
        out[e.key] = _deepCopyList(v);
      } else {
        out[e.key] = v;
      }
    }
    return out;
  }

  static List<Object?> _deepCopyList(List<dynamic> source) {
    return <Object?>[
      for (final v in source)
        if (v is Map)
          _deepCopyMap(_asStringKeyedMap(v))
        else if (v is List)
          _deepCopyList(v)
        else
          v,
    ];
  }
}
