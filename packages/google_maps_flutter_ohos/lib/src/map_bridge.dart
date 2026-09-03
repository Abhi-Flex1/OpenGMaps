// Copyright 2026 The OpenGMaps Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';

import 'icon_resolver.dart';

/// A tap on a Google place icon (POI symbol) on the map.
///
/// The stock `google_maps_flutter` API (like the plugin on Android/iOS)
/// does not surface POI taps — plain taps arrive as [MapTapEvent]. This
/// OHOS extension carries the tapped place's id plus its location so apps
/// can resolve the full place card via the Places Details API.
class OhosPoiTap {
  const OhosPoiTap({required this.mapId, required this.placeId, required this.position});

  final int mapId;
  final String placeId;
  final LatLng position;
}

/// One live map instance: owns the WebView controller, the JS call queue,
/// request/response correlation, tile fetching and the typed event streams.
class OhosMapSession {
  OhosMapSession(this.mapId, {OhosIconResolver? icons})
      : icons = icons ?? OhosIconResolver();

  final int mapId;
  final OhosIconResolver icons;

  InAppWebViewController? web;
  bool jsReady = false;
  final List<String> _pendingJs = [];
  int _reqSeq = 0;
  final Map<String, Completer<Object?>> _requests = {};

  /// Last camera reported by the map (best effort; refreshed on demand).
  CameraPosition lastCamera = const CameraPosition(
    target: LatLng(0, 0),
    zoom: 2,
  );

  bool trackCamera = true;
  String? styleError;
  String? lastError;
  final ValueNotifier<String?> errorNotice = ValueNotifier<String?>(null);

  bool myLocationEnabled = false;

  /// True when the widget requested `MarkerType.advancedMarker`.
  bool useAdvancedMarkers = false;

  /// Cloud map id (`GoogleMap.mapId`), when set.
  String? cloudMapId;

  /// Known cluster-manager ids (membership is tracked marker-side).
  final Set<String> clusterManagerIds = {};

  /// Tile providers by overlay id (kept Dart-side; tiles are pulled by JS).
  final Map<String, TileOverlay> tileOverlays = {};

  // -- event streams (all broadcast; guarded against post-dispose emits) --
  final StreamController<CameraMoveStartedEvent> _cameraMoveStarted =
      StreamController<CameraMoveStartedEvent>.broadcast();
  final StreamController<CameraMoveEvent> _cameraMove =
      StreamController<CameraMoveEvent>.broadcast();
  final StreamController<CameraIdleEvent> _cameraIdle =
      StreamController<CameraIdleEvent>.broadcast();
  final StreamController<MarkerTapEvent> _markerTap =
      StreamController<MarkerTapEvent>.broadcast();
  final StreamController<InfoWindowTapEvent> _infoWindowTap =
      StreamController<InfoWindowTapEvent>.broadcast();
  final StreamController<MarkerDragStartEvent> _markerDragStart =
      StreamController<MarkerDragStartEvent>.broadcast();
  final StreamController<MarkerDragEvent> _markerDrag =
      StreamController<MarkerDragEvent>.broadcast();
  final StreamController<MarkerDragEndEvent> _markerDragEnd =
      StreamController<MarkerDragEndEvent>.broadcast();
  final StreamController<PolylineTapEvent> _polylineTap =
      StreamController<PolylineTapEvent>.broadcast();
  final StreamController<PolygonTapEvent> _polygonTap =
      StreamController<PolygonTapEvent>.broadcast();
  final StreamController<CircleTapEvent> _circleTap =
      StreamController<CircleTapEvent>.broadcast();
  final StreamController<MapTapEvent> _tap =
      StreamController<MapTapEvent>.broadcast();
  final StreamController<MapLongPressEvent> _longPress =
      StreamController<MapLongPressEvent>.broadcast();
  final StreamController<ClusterTapEvent> _clusterTap =
      StreamController<ClusterTapEvent>.broadcast();
  final StreamController<GroundOverlayTapEvent> _groundOverlayTap =
      StreamController<GroundOverlayTapEvent>.broadcast();
  final StreamController<OhosPoiTap> _poiTap =
      StreamController<OhosPoiTap>.broadcast();

  Stream<CameraMoveStartedEvent> get cameraMoveStarted =>
      _cameraMoveStarted.stream;
  Stream<CameraMoveEvent> get cameraMove => _cameraMove.stream;
  Stream<CameraIdleEvent> get cameraIdle => _cameraIdle.stream;
  Stream<MarkerTapEvent> get markerTap => _markerTap.stream;
  Stream<InfoWindowTapEvent> get infoWindowTap => _infoWindowTap.stream;
  Stream<MarkerDragStartEvent> get markerDragStart => _markerDragStart.stream;
  Stream<MarkerDragEvent> get markerDrag => _markerDrag.stream;
  Stream<MarkerDragEndEvent> get markerDragEnd => _markerDragEnd.stream;
  Stream<PolylineTapEvent> get polylineTap => _polylineTap.stream;
  Stream<PolygonTapEvent> get polygonTap => _polygonTap.stream;
  Stream<CircleTapEvent> get circleTap => _circleTap.stream;
  Stream<MapTapEvent> get tap => _tap.stream;
  Stream<MapLongPressEvent> get longPress => _longPress.stream;
  Stream<ClusterTapEvent> get clusterTap => _clusterTap.stream;
  Stream<GroundOverlayTapEvent> get groundOverlayTap =>
      _groundOverlayTap.stream;

  /// Taps on Google place icons. OHOS extension (see [OhosPoiTap]).
  Stream<OhosPoiTap> get poiTap => _poiTap.stream;

  void _emit<T>(StreamController<T> c, T event) {
    if (!c.isClosed) c.add(event);
  }

  /// Queue JS until the bridge reports ready, then run in order.
  void eval(String js) {
    if (jsReady && web != null) {
      web!.evaluateJavascript(source: js);
    } else {
      _pendingJs.add(js);
    }
  }

  void onJsReady() {
    jsReady = true;
    final List<String> queued = List<String>.of(_pendingJs);
    _pendingJs.clear();
    for (final String js in queued) {
      web?.evaluateJavascript(source: js);
    }
  }

  /// Request/response call into JS (`OhosMaps.<method>(..., reqId)`).
  Future<T> request<T>(String call) {
    final String id = 'r${_reqSeq++}';
    final Completer<Object?> completer = Completer<Object?>();
    _requests[id] = completer;
    eval(call.replaceFirst('REQ', id));
    return completer.future
        .timeout(const Duration(seconds: 10))
        .then((Object? v) => v as T);
  }

  void onRequestResponse(Map<Object?, Object?> res) {
    final Object? id = res['id'];
    final Completer<Object?>? c =
        id is String ? _requests.remove(id) : null;
    if (c == null || c.isCompleted) return;
    if (res.containsKey('error')) {
      c.completeError(StateError('${res['error']}'));
    } else {
      c.complete(res['value']);
    }
  }

  void onMapError(String message) {
    lastError = message;
    errorNotice.value = message;
  }

  /// Route one `ohosEvent` payload to the typed streams.
  void onEvent(Map<Object?, Object?> ev) {
    final String type = '${ev['type']}';
    switch (type) {
      case 'cameraMoveStarted':
        _emit(_cameraMoveStarted, CameraMoveStartedEvent(mapId));
      case 'cameraMove':
        final CameraPosition cam = _cameraOf(ev['camera']);
        lastCamera = cam;
        _emit(_cameraMove, CameraMoveEvent(mapId, cam));
      case 'cameraIdle':
        _emit(_cameraIdle, CameraIdleEvent(mapId));
      case 'markerTap':
        _emit(_markerTap, MarkerTapEvent(mapId, MarkerId('${ev['id']}')));
      case 'infoWindowTap':
        _emit(
            _infoWindowTap, InfoWindowTapEvent(mapId, MarkerId('${ev['id']}')));
      case 'markerDragStart':
        _emit(
            _markerDragStart,
            MarkerDragStartEvent(
                mapId, _latLngOf(ev), MarkerId('${ev['id']}')));
      case 'markerDrag':
        _emit(_markerDrag,
            MarkerDragEvent(mapId, _latLngOf(ev), MarkerId('${ev['id']}')));
      case 'markerDragEnd':
        _emit(_markerDragEnd,
            MarkerDragEndEvent(mapId, _latLngOf(ev), MarkerId('${ev['id']}')));
      case 'polylineTap':
        _emit(_polylineTap,
            PolylineTapEvent(mapId, PolylineId('${ev['id']}')));
      case 'polygonTap':
        _emit(_polygonTap, PolygonTapEvent(mapId, PolygonId('${ev['id']}')));
      case 'circleTap':
        _emit(_circleTap, CircleTapEvent(mapId, CircleId('${ev['id']}')));
      case 'mapTap':
        _emit(_tap, MapTapEvent(mapId, _latLngOf(ev)));
      case 'mapLongPress':
        _emit(_longPress, MapLongPressEvent(mapId, _latLngOf(ev)));
      case 'clusterTap':
        _emit(_clusterTap, _clusterOf(ev));
      case 'groundOverlayTap':
        _emit(_groundOverlayTap,
            GroundOverlayTapEvent(mapId, GroundOverlayId('${ev['id']}')));
      case 'poiTap':
        _emit(
            _poiTap,
            OhosPoiTap(
              mapId: mapId,
              placeId: '${ev['placeId']}',
              position: _latLngOf(ev),
            ));
    }
  }

  static LatLng _latLngOf(Map<Object?, Object?> ev) => LatLng(
        (ev['lat'] as num).toDouble(),
        (ev['lng'] as num).toDouble(),
      );

  static CameraPosition _cameraOf(Object? raw) {
    final Map<Object?, Object?> m =
        Map<Object?, Object?>.from(raw as Map? ?? {});
    final Object? target = m['target'];
    LatLng ll;
    if (target is Map) {
      final Map<Object?, Object?> t = Map<Object?, Object?>.from(target);
      ll = LatLng((t['lat'] as num).toDouble(), (t['lng'] as num).toDouble());
    } else {
      ll = LatLng(
        (m['lat'] as num).toDouble(),
        (m['lng'] as num).toDouble(),
      );
    }
    return CameraPosition(
      target: ll,
      zoom: (m['zoom'] as num?)?.toDouble() ?? 0,
      tilt: (m['tilt'] as num?)?.toDouble() ?? 0,
      bearing: (m['bearing'] as num?)?.toDouble() ?? 0,
    );
  }

  ClusterTapEvent _clusterOf(Map<Object?, Object?> ev) {
    final LatLng pos = ev['position'] is Map
        ? _latLngOf(Map<Object?, Object?>.from(ev['position'] as Map))
        : const LatLng(0, 0);
    LatLngBounds bounds;
    if (ev['bounds'] is List && (ev['bounds'] as List).length == 2) {
      final List<Object?> b = List<Object?>.from(ev['bounds'] as List);
      LatLng sw = pos, ne = pos;
      if (b[0] is List) {
        final List<Object?> s = List<Object?>.from(b[0] as List);
        sw = LatLng((s[0] as num).toDouble(), (s[1] as num).toDouble());
      }
      if (b[1] is List) {
        final List<Object?> n = List<Object?>.from(b[1] as List);
        ne = LatLng((n[0] as num).toDouble(), (n[1] as num).toDouble());
      }
      bounds = LatLngBounds(southwest: sw, northeast: ne);
    } else {
      bounds = LatLngBounds(southwest: pos, northeast: pos);
    }
    final List<Object?> ids =
        ev['markerIds'] is List ? List<Object?>.from(ev['markerIds'] as List) : [];
    return ClusterTapEvent(
      mapId,
      Cluster(
        ClusterManagerId('${ev['managerId']}'),
        ids.map((Object? e) => MarkerId('$e')).toList(),
        position: pos,
        bounds: bounds,
      ),
    );
  }

  /// Serve one `ohosTile` request from the overlay's [TileProvider].
  Future<void> onTileRequest(Map<Object?, Object?> req) async {
    final String overlayId = '${req['overlayId']}';
    final String token = '${req['token']}';
    String? dataUrl;
    try {
      final TileOverlay? overlay = tileOverlays[overlayId];
      final TileProvider? provider = overlay?.tileProvider;
      if (provider != null) {
        final Tile tile = await provider
            .getTile((req['x'] as num).toInt(), (req['y'] as num).toInt(),
                (req['zoom'] as num?)?.toInt())
            .timeout(const Duration(seconds: 8));
        if (tile.data != null && tile.data!.isNotEmpty) {
          dataUrl =
              'data:image/png;base64,${base64Encode(tile.data!)}';
        }
      }
    } catch (_) {
      dataUrl = null;
    }
    eval('__ohosTileResponse(${jsonEncode(token)},'
        ' ${dataUrl == null ? 'null' : jsonEncode(dataUrl)});');
  }

  void dispose() {
    for (final Completer<Object?> c in _requests.values) {
      if (!c.isCompleted) c.completeError(StateError('Map disposed'));
    }
    _requests.clear();
    _cameraMoveStarted.close();
    _cameraMove.close();
    _cameraIdle.close();
    _markerTap.close();
    _infoWindowTap.close();
    _markerDragStart.close();
    _markerDrag.close();
    _markerDragEnd.close();
    _polylineTap.close();
    _polygonTap.close();
    _circleTap.close();
    _tap.close();
    _longPress.close();
    _clusterTap.close();
    _groundOverlayTap.close();
    _poiTap.close();
    errorNotice.dispose();
  }
}
