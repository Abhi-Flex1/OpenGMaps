// Copyright 2026 The OpenGMaps Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license.

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter_ohos/google_maps_flutter_ohos.dart';
import 'package:google_maps_flutter_ohos/src/icon_resolver.dart';
import 'package:google_maps_flutter_ohos/src/map_bridge.dart';
import 'package:google_maps_flutter_ohos/src/translation.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';

class _FakeBundle extends AssetBundle {
  _FakeBundle(this.bytes);
  final Map<String, Uint8List> bytes;

  @override
  Future<ByteData> load(String key) async {
    final Uint8List? b = bytes[key];
    if (b == null) throw FlutterError('No asset $key');
    return ByteData.sublistView(b);
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) =>
      throw UnimplementedError();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('register() installs the OHOS platform instance', () {
    GoogleMapsFlutterOhos.register();
    expect(GoogleMapsFlutterPlatform.instance,
        isA<GoogleMapsFlutterOhos>());
  });

  group('camera ops', () {
    test('newCameraPosition carries target/zoom/tilt/bearing', () {
      final Map<String, Object?> op = ohosCameraOp(
        CameraUpdate.newCameraPosition(const CameraPosition(
          target: LatLng(48.85, 2.29),
          zoom: 14,
          tilt: 30,
          bearing: 90,
        )),
      );
      expect(op['kind'], 'newCameraPosition');
      expect(op['position'], [48.85, 2.29, 14.0, 30.0, 90.0]);
    });

    test('all update types translate', () {
      expect(ohosCameraOp(CameraUpdate.newLatLng(const LatLng(1, 2)))['kind'],
          'newLatLng');
      expect(
          ohosCameraOp(CameraUpdate.newLatLngZoom(const LatLng(1, 2), 5))['zoom'],
          5);
      expect(
          ohosCameraOp(CameraUpdate.newLatLngBounds(
                  LatLngBounds(
                      southwest: const LatLng(0, 0),
                      northeast: const LatLng(1, 1)),
                  8))['kind'],
          'newLatLngBounds');
      expect(ohosCameraOp(CameraUpdate.scrollBy(3, 4))['dx'], 3);
      expect(ohosCameraOp(CameraUpdate.zoomBy(2))['amount'], 2);
      expect(ohosCameraOp(CameraUpdate.zoomIn())['kind'], 'zoomIn');
      expect(ohosCameraOp(CameraUpdate.zoomOut())['kind'], 'zoomOut');
      expect(ohosCameraOp(CameraUpdate.zoomTo(7))['zoom'], 7);
    });
  });

  group('options', () {
    test('map types map to JS ids', () {
      expect(
          ohosMapOptions(const MapConfiguration(mapType: MapType.normal))['mapType'],
          'roadmap');
      expect(
          ohosMapOptions(const MapConfiguration(mapType: MapType.satellite))['mapType'],
          'satellite');
      expect(
          ohosMapOptions(const MapConfiguration(mapType: MapType.hybrid))['mapType'],
          'hybrid');
      expect(
          ohosMapOptions(const MapConfiguration(mapType: MapType.terrain))['mapType'],
          'terrain');
      expect(
          ohosMapOptions(const MapConfiguration(mapType: MapType.none))['mapType'],
          'none');
    });

    test('gesture policy derives from scroll/zoom flags', () {
      final Map<String, Object?> greedy =
          ohosMapOptions(const MapConfiguration());
      expect(greedy['gestureHandling'], 'greedy');

      final Map<String, Object?> none = ohosMapOptions(const MapConfiguration(
        scrollGesturesEnabled: false,
        zoomGesturesEnabled: false,
      ));
      expect(none['gestureHandling'], 'none');
    });

    test('camera bounds become a restriction', () {
      final Map<String, Object?> o = ohosMapOptions(MapConfiguration(
        cameraTargetBounds: CameraTargetBounds(LatLngBounds(
            southwest: const LatLng(0, 0), northeast: const LatLng(1, 1))),
      ));
      expect((o['restriction'] as Map)['strictBounds'], isTrue);
    });

    test('invalid style throws and records the error', () {
      String? recorded;
      expect(
        () => ohosMapOptions(
          const MapConfiguration(style: 'nope'),
          onStyleError: (String? e) => recorded = e,
        ),
        throwsA(isA<MapStyleException>()),
      );
      expect(recorded, isNotNull);
    });

    test('empty style clears', () {
      final Map<String, Object?> o =
          ohosMapOptions(const MapConfiguration(style: ''));
      expect(o['styles'], isEmpty);
    });
  });

  group('overlay payloads', () {
    test('polyline carries color/points/patterns', () {
      final Map<String, Object?> p = ohosPolylineJson(Polyline(
        polylineId: const PolylineId('r'),
        points: const [LatLng(0, 0), LatLng(1, 1)],
        patterns: [PatternItem.dash(20)],
      ));
      expect(p['id'], 'r');
      expect((p['points'] as List), hasLength(2));
      expect((p['patterns'] as List).first.first, 'dash');
    });

    test('polygon carries holes', () {
      final Map<String, Object?> p = ohosPolygonJson(const Polygon(
        polygonId: PolygonId('p'),
        points: [LatLng(0, 0), LatLng(0, 1), LatLng(1, 1)],
        holes: [
          [LatLng(0.2, 0.2), LatLng(0.2, 0.3), LatLng(0.3, 0.3)]
        ],
      ));
      expect((p['holes'] as List), hasLength(1));
    });

    test('heatmap carries weighted data + gradient', () {
      // ignore: prefer_const_constructors
      final Map<String, Object?> h = ohosHeatmapJson(Heatmap(
        heatmapId: const HeatmapId('h'),
        data: const [WeightedLatLng(LatLng(1, 2), weight: 3)],
        // ignore: prefer_const_constructors
        radius: HeatmapRadius.fromPixels(24),
        gradient: const HeatmapGradient(
            [HeatmapGradientColor(Color(0xFFFF0000), 0.2)]),
      ));
      expect(((h['data'] as List).first as List).last, 3);
      expect((h['gradient'] as Map)['colors'], hasLength(1));
      expect(h['radius'], 24);
    });
  });

  group('session events', () {
    test('JS events become typed stream events', () async {
      final OhosMapSession session = OhosMapSession(7);
      final Future<MarkerTapEvent> tap = session.markerTap.first;
      final Future<MapTapEvent> mapTap = session.tap.first;
      final Future<CameraMoveEvent> move = session.cameraMove.first;
      final Future<MarkerDragEndEvent> dragEnd = session.markerDragEnd.first;

      session.onEvent(const {'type': 'markerTap', 'id': 'a'});
      session.onEvent(const {'type': 'mapTap', 'lat': 1.5, 'lng': 2.5});
      session.onEvent(const {
        'type': 'cameraMove',
        'camera': {'lat': 1.0, 'lng': 2.0, 'zoom': 5.0}
      });
      session.onEvent(
          const {'type': 'markerDragEnd', 'id': 'a', 'lat': 3.0, 'lng': 4.0});

      expect((await tap).value.value, 'a');
      expect((await mapTap).position, const LatLng(1.5, 2.5));
      expect((await move).value.zoom, 5);
      final MarkerDragEndEvent end = await dragEnd;
      expect(end.value.value, 'a');
      expect(end.position, const LatLng(3, 4));
      session.dispose();
    });

    test('request/response correlation resolves typed getters', () async {      final OhosMapSession session = OhosMapSession(9);
      final Future<List<Object?>> pending =
          session.request<List<Object?>>("OhosMaps.getVisibleRegion('REQ');");
      session.onRequestResponse(const {
        'id': 'r0',
        'value': [
          [1.0, 2.0],
          [3.0, 4.0]
        ]
      });
      expect(await pending, [
        [1.0, 2.0],
        [3.0, 4.0]
      ]);
      session.dispose();
    });

    test('place-icon taps become OhosPoiTap with the place id', () async {
      final OhosMapSession session = OhosMapSession(11);
      final Future<OhosPoiTap> pending = session.poiTap.first;
      session.onEvent(const {
        'type': 'poiTap',
        'placeId': 'ChIJLU7jZClu5kcR4PcOOO6p3I0',
        'lat': 48.85837,
        'lng': 2.29448,
      });
      final OhosPoiTap tap = await pending;
      expect(tap.mapId, 11);
      expect(tap.placeId, 'ChIJLU7jZClu5kcR4PcOOO6p3I0');
      expect(tap.position, const LatLng(48.85837, 2.29448));
      session.dispose();
    });
  });

  group('icon resolver', () {
    test('default marker and hues', () async {
      final OhosIconResolver resolver =
          OhosIconResolver(bundle: _FakeBundle({}));
      expect(await resolver.resolve(BitmapDescriptor.defaultMarker),
          {'kind': 'default'});
      expect(
          await resolver.resolve(
              BitmapDescriptor.defaultMarkerWithHue(120)),
          {'kind': 'default', 'hue': 120.0});
    });

    test('bytes become a data URL', () async {
      final OhosIconResolver resolver =
          OhosIconResolver(bundle: _FakeBundle({}));
      final Map<String, Object?> out = await resolver.resolve(
          BitmapDescriptor.bytes(Uint8List.fromList([1, 2, 3])));
      expect(out['kind'], 'url');
      expect('${out['url']}', startsWith('data:image/png;base64,'));
    });

    test('assets load through the bundle with package keys', () async {
      final Uint8List bytes = Uint8List.fromList([9, 9, 9]);
      final OhosIconResolver resolver = OhosIconResolver(
          bundle: _FakeBundle({'packages/pk/a.png': bytes}));
      final Map<String, Object?> out = await resolver
          .resolve(const AssetBitmap(name: 'a.png', package: 'pk'));
      expect(out['kind'], 'url');
    });

    test('missing assets degrade to the default pin', () async {
      final OhosIconResolver resolver =
          OhosIconResolver(bundle: _FakeBundle({}));
      expect(
          await resolver.resolve(const AssetBitmap(name: 'nope.png')),
          {'kind': 'default'});
    });

    test('pin configs carry colors + text glyphs', () async {
      final OhosIconResolver resolver =
          OhosIconResolver(bundle: _FakeBundle({}));
      final Map<String, Object?> out = await resolver.resolve(
          BitmapDescriptor.pinConfig(
              backgroundColor: const Color(0xFF1A73E8),
              glyph: const TextGlyph(text: 'A')));
      expect(out['kind'], 'pin');
      expect(out['background'], '#1a73e8');
      expect((out['glyph'] as Map)['text'], 'A');
    });
  });

  group('platform wiring', () {
    test('updateMarkers queues versioned JS without a WebView', () async {
      final GoogleMapsFlutterOhos platform = GoogleMapsFlutterOhos();
      await platform.init(42);
      await platform.updateMarkers(
        MarkerUpdates.from(
          const {},
          {
            const Marker(
                markerId: MarkerId('m1'),
                position: LatLng(10, 20)),
          },
        ),
        mapId: 42,
      );
      platform.dispose(mapId: 42);
    });

    test('overlay updates queue without a WebView', () async {
      final GoogleMapsFlutterOhos platform = GoogleMapsFlutterOhos();
      await platform.init(43);
      await platform.updatePolylines(
        PolylineUpdates.from(
          const {},
          {
            const Polyline(
                polylineId: PolylineId('p1'),
                points: [LatLng(0, 0), LatLng(1, 1)]),
          },
        ),
        mapId: 43,
      );
      await platform.moveCamera(CameraUpdate.newLatLngZoom(
          const LatLng(1, 2), 12),
          mapId: 43);
      expect(await platform.takeSnapshot(mapId: 43), isNull);
      platform.dispose(mapId: 43);
    });
  });
}
