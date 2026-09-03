// Copyright 2026 The OpenGMaps Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license.

import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';

/// Resolves a [BitmapDescriptor] (or [MapBitmap] for ground overlays) into a
/// JSON-safe icon payload for the Maps JavaScript bridge.
///
/// Returned shapes:
/// * `{'kind': 'default'}` — stock red pin (optionally `hue` 0–360).
/// * `{'kind': 'url', 'url': dataUrl, 'width': w?, 'height': h?}` — PNG bytes.
/// * `{'kind': 'pin', 'background': css?, 'border': css?, 'glyph': {...}?}` —
///   [PinConfig] rendered with `PinElement` in JS.
class OhosIconResolver {
  OhosIconResolver({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;

  /// Resolve [icon] to a bridge payload. Never throws: failures degrade to
  /// the default marker so one bad icon can't break the whole overlay sync.
  Future<Map<String, Object?>> resolve(BitmapDescriptor icon) async {
    try {
      final Object json = icon.toJson();
      if (json is! List || json.isEmpty) return const {'kind': 'default'};
      final String type = '${json[0]}';
      switch (type) {
        case 'defaultMarker':
          final num? hue = json.length > 1 ? json[1] as num? : null;
          return {
            'kind': 'default',
            if (hue != null) 'hue': hue.toDouble(),
          };
        case 'fromBytes':
          final Uint8List bytes = _asBytes(json[1]);
          return _url(bytes, null, null);
        case 'bytes':
          final Map<String, Object?> m = _asMap(json[1]);
          return _url(
            _asBytes(m['byteData']),
            (m['width'] as num?)?.toDouble(),
            (m['height'] as num?)?.toDouble(),
          );
        case 'fromAsset':
          final String name = json[1] as String;
          final String? package = json.length > 2 ? json[2] as String? : null;
          final Uint8List bytes = await _loadAsset(name, package);
          return _url(bytes, null, null);
        case 'fromAssetImage':
          final String name = json[1] as String;
          // Resolved variant name is stored directly (e.g. 3.0x/xxx.png).
          final Uint8List bytes = await _bundle.load(name).then(
                (ByteData d) => d.buffer.asUint8List(),
              );
          return _url(bytes, null, null);
        case 'asset':
          final Map<String, Object?> m = _asMap(json[1]);
          final Uint8List bytes =
              await _loadAsset(m['assetName'] as String, null);
          return _url(
            bytes,
            (m['width'] as num?)?.toDouble(),
            (m['height'] as num?)?.toDouble(),
          );
        case 'pinConfig':
          return _pin(json.length > 1 ? _asMap(json[1]) : const {});
        default:
          return const {'kind': 'default'};
      }
    } catch (_) {
      return const {'kind': 'default'};
    }
  }

  Future<Uint8List> _loadAsset(String name, String? package) async {
    final String key =
        package != null ? 'packages/$package/$name' : name;
    final ByteData data = await _bundle.load(key);
    return data.buffer.asUint8List();
  }

  Map<String, Object?> _url(Uint8List bytes, double? w, double? h) => {
        'kind': 'url',
        'url': 'data:image/png;base64,${base64Encode(bytes)}',
        if (w != null) 'width': w,
        if (h != null) 'height': h,
      };

  Map<String, Object?> _pin(Map<String, Object?> m) {
    Object? glyph;
    final Object? rawGlyph = m['glyph'];
    if (rawGlyph is List && rawGlyph.isNotEmpty) {
      final String gType = '${rawGlyph[0]}';
      final Map<String, Object?> g =
          rawGlyph.length > 1 ? _asMap(rawGlyph[1]) : const {};
      switch (gType) {
        case 'textGlyph':
          glyph = {
            'kind': 'text',
            'text': '${g['text'] ?? ''}',
            if (g['textColor'] != null)
              'textColor': _css(g['textColor'] as int),
          };
        case 'circleGlyph':
          glyph = {
            'kind': 'circle',
            'color': _css((g['color'] as num).toInt()),
          };
        case 'bitmapGlyph':
          // Nested bitmaps are resolved by the caller via [resolveNested];
          // mark it so the bridge can request it. Here: fall back to circle.
          glyph = const {'kind': 'circle', 'color': '#ffffff'};
      }
    }
    return {
      'kind': 'pin',
      if (m['backgroundColor'] != null)
        'background': _css((m['backgroundColor'] as num).toInt()),
      if (m['borderColor'] != null)
        'border': _css((m['borderColor'] as num).toInt()),
      if (glyph != null) 'glyph': glyph,
    };
  }

  /// ARGB int → `#rrggbb` CSS (alpha is applied separately via opacity).
  static String _css(int argb) {
    final int rgb = argb & 0x00FFFFFF;
    return '#${rgb.toRadixString(16).padLeft(6, '0')}';
  }

  static Uint8List _asBytes(Object? v) {
    if (v is Uint8List) return v;
    if (v is List<int>) return Uint8List.fromList(v);
    throw ArgumentError('Not byte data: $v');
  }

  static Map<String, Object?> _asMap(Object? v) =>
      Map<String, Object?>.from(v as Map);
}
