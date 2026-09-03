// Copyright 2026 The OpenGMaps Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';

import 'map_bridge.dart';
import 'ohos_map_view.dart';
import 'translation.dart';

/// OpenHarmony implementation of `google_maps_flutter`.
///
/// Rendering is the official Maps JavaScript API inside the native OHOS
/// WebView (there is no GMS Maps SDK binary for OpenHarmony); every
/// `GoogleMap` widget option, overlay type, camera call and event in the
/// stock API is translated to it. Register before `runApp`:
///
/// ```dart
/// GoogleMapsFlutterOhos.register();
/// ```
class GoogleMapsFlutterOhos extends GoogleMapsFlutterPlatform {
  /// Registers this implementation as the [GoogleMapsFlutterPlatform].
  static void register() {
    GoogleMapsFlutterPlatform.instance = GoogleMapsFlutterOhos();
  }

  /// Entry point used by the generated plugin registrant (`dartPluginClass`).
  static void registerWith() => register();

  /// Explicit API key. When null, `--dart-define=GOOGLE_MAPS_API_KEY` is
  /// used; with neither set, maps render an honest key-required state.
  static String? apiKeyOverride;

  /// Active API key (override first, build-time define second).
  static String get apiKey =>
      apiKeyOverride ??
      const String.fromEnvironment('GOOGLE_MAPS_API_KEY');

  /// Device-location channel (OHOS Location Kit via the host app). Absent
  /// outside OHOS hosts — location features then stay quietly disabled.
  static const MethodChannel _locationChannel =
      MethodChannel('io.opengmaps/location');

  final Map<int, OhosMapSession> _sessions = {};

  OhosMapSession _session(int mapId) {
    final OhosMapSession? session = _sessions[mapId];
    if (session == null) {
      throw StateError('No OHOS map with id $mapId (disposed?)');
    }
    return session;
  }

  // -- lifecycle -----------------------------------------------------------

  @override
  Future<void> init(int mapId) async {
    _sessions.putIfAbsent(mapId, () => OhosMapSession(mapId));
  }

  @override
  void dispose({required int mapId}) {
    _sessions.remove(mapId)?.dispose();
  }

  // -- view ------------------------------------------------------------------

  @override
  Widget buildViewWithConfiguration(
    int creationId,
    PlatformViewCreatedCallback onPlatformViewCreated, {
    required MapWidgetConfiguration widgetConfiguration,
    MapConfiguration mapConfiguration = const MapConfiguration(),
    MapObjects mapObjects = const MapObjects(),
  }) {
    final OhosMapSession session =
        _sessions.putIfAbsent(creationId, () => OhosMapSession(creationId));
    session.useAdvancedMarkers =
        mapConfiguration.markerType == MarkerType.advancedMarker;
    session.cloudMapId = mapConfiguration.mapId;
    session.trackCamera = mapConfiguration.trackCameraPosition ?? true;
    session.lastCamera = CameraPosition(
      target: widgetConfiguration.initialCameraPosition.target,
      zoom: widgetConfiguration.initialCameraPosition.zoom,
      tilt: widgetConfiguration.initialCameraPosition.tilt,
      bearing: widgetConfiguration.initialCameraPosition.bearing,
    );
    Map<String, Object?> options;
    try {
      options = ohosMapOptions(
        mapConfiguration,
        onStyleError: (String? e) => session.styleError = e,
      );
    } on MapStyleException catch (e) {
      session.styleError = e.cause;
      options = ohosMapOptions(
        const MapConfiguration(),
        onStyleError: (String? err) => session.styleError = err,
      );
    }
    session.myLocationEnabled = mapConfiguration.myLocationEnabled ?? false;
    if (session.myLocationEnabled) {
      unawaited(_refreshMyLocation(session));
    }
    return OhosMapView(
      session: session,
      apiKey: apiKey,
      initialCamera: widgetConfiguration.initialCameraPosition,
      initialOptions: options,
      initialObjects: mapObjects,
      initialManagers: mapObjects.clusterManagers,
      useAdvancedMarkers: session.useAdvancedMarkers,
      myLocationButton:
          mapConfiguration.myLocationButtonEnabled == true
              ? () => _onMyLocationButton(session)
              : null,
      onViewCreated: onPlatformViewCreated,
      gestureRecognizers: widgetConfiguration.gestureRecognizers,
    );
  }

  @override
  @Deprecated('Use buildViewWithConfiguration instead.')
  Widget buildView(
    int creationId,
    PlatformViewCreatedCallback onPlatformViewCreated, {
    required CameraPosition initialCameraPosition,
    Set<Marker> markers = const <Marker>{},
    Set<Polygon> polygons = const <Polygon>{},
    Set<Polyline> polylines = const <Polyline>{},
    Set<Circle> circles = const <Circle>{},
    Set<TileOverlay> tileOverlays = const <TileOverlay>{},
    Set<Factory<OneSequenceGestureRecognizer>>? gestureRecognizers =
        const <Factory<OneSequenceGestureRecognizer>>{},
    Map<String, dynamic> mapOptions = const <String, dynamic>{},
  }) {
    return buildViewWithConfiguration(
      creationId,
      onPlatformViewCreated,
      widgetConfiguration: MapWidgetConfiguration(
        initialCameraPosition: initialCameraPosition,
        textDirection: TextDirection.ltr,
        gestureRecognizers: gestureRecognizers ?? const {},
      ),
      mapObjects: MapObjects(
        markers: markers,
        polygons: polygons,
        polylines: polylines,
        circles: circles,
        tileOverlays: tileOverlays,
      ),
    );
  }

  // -- configuration -----------------------------------------------------------

  @override
  Future<void> updateMapConfiguration(
    MapConfiguration configuration, {
    required int mapId,
  }) async {
    final OhosMapSession session = _session(mapId);
    late final Map<String, Object?> options;
    try {
      options = ohosMapOptions(
        configuration,
        onStyleError: (String? e) => session.styleError = e,
      );
    } on MapStyleException {
      rethrow;
    }
    session
      ..trackCamera = configuration.trackCameraPosition ?? session.trackCamera
      ..cloudMapId = configuration.mapId ?? session.cloudMapId;
    if (configuration.markerType != null) {
      session.useAdvancedMarkers =
          configuration.markerType == MarkerType.advancedMarker;
    }
    session.eval('OhosMaps.setOptions(${jsonEncode(options)});');
    final bool? myLocation = configuration.myLocationEnabled;
    if (myLocation != null && myLocation != session.myLocationEnabled) {
      session.myLocationEnabled = myLocation;
      await _refreshMyLocation(session);
    }
  }

  // -- overlays ------------------------------------------------------------------

  @override
  Future<void> updateMarkers(
    MarkerUpdates markerUpdates, {
    required int mapId,
  }) async {
    final OhosMapSession session = _session(mapId);
    Future<Map<String, Object?>> one(Marker m) async => ohosMarkerJson(
          m,
          await session.icons.resolve(m.icon),
          advanced: session.useAdvancedMarkers,
        );
    final List<Map<String, Object?>> add = await Future.wait(
        markerUpdates.markersToAdd.map(one));
    final List<Map<String, Object?>> change = await Future.wait(
        markerUpdates.markersToChange.map(one));
    session.eval('OhosMaps.setMarkers(${jsonEncode({
      'add': add,
      'change': change,
      'remove': markerUpdates.markerIdsToRemove
          .map((MarkerId e) => e.value)
          .toList(),
    })});');
  }

  @override
  Future<void> updatePolylines(
    PolylineUpdates polylineUpdates, {
    required int mapId,
  }) async {
    _session(mapId).eval('OhosMaps.setPolylines(${jsonEncode({
      'add': polylineUpdates.polylinesToAdd.map(ohosPolylineJson).toList(),
      'change':
          polylineUpdates.polylinesToChange.map(ohosPolylineJson).toList(),
      'remove': polylineUpdates.polylineIdsToRemove
          .map((PolylineId e) => e.value)
          .toList(),
    })});');
  }

  @override
  Future<void> updatePolygons(
    PolygonUpdates polygonUpdates, {
    required int mapId,
  }) async {
    _session(mapId).eval('OhosMaps.setPolygons(${jsonEncode({
      'add': polygonUpdates.polygonsToAdd.map(ohosPolygonJson).toList(),
      'change': polygonUpdates.polygonsToChange.map(ohosPolygonJson).toList(),
      'remove': polygonUpdates.polygonIdsToRemove
          .map((PolygonId e) => e.value)
          .toList(),
    })});');
  }

  @override
  Future<void> updateCircles(
    CircleUpdates circleUpdates, {
    required int mapId,
  }) async {
    _session(mapId).eval('OhosMaps.setCircles(${jsonEncode({
      'add': circleUpdates.circlesToAdd.map(ohosCircleJson).toList(),
      'change': circleUpdates.circlesToChange.map(ohosCircleJson).toList(),
      'remove': circleUpdates.circleIdsToRemove
          .map((CircleId e) => e.value)
          .toList(),
    })});');
  }

  @override
  Future<void> updateHeatmaps(
    HeatmapUpdates heatmapUpdates, {
    required int mapId,
  }) async {
    _session(mapId).eval('OhosMaps.setHeatmaps(${jsonEncode({
      'add': heatmapUpdates.heatmapsToAdd.map(ohosHeatmapJson).toList(),
      'change':
          heatmapUpdates.heatmapsToChange.map(ohosHeatmapJson).toList(),
      'remove': heatmapUpdates.heatmapIdsToRemove
          .map((HeatmapId e) => e.value)
          .toList(),
    })});');
  }

  @override
  Future<void> updateTileOverlays({
    required Set<TileOverlay> newTileOverlays,
    required int mapId,
  }) async {
    final OhosMapSession session = _session(mapId);
    session.tileOverlays
      ..clear()
      ..addEntries(newTileOverlays
          .map((TileOverlay t) => MapEntry(t.tileOverlayId.value, t)));
    session.eval('OhosMaps.setTileOverlays('
        '${jsonEncode(newTileOverlays.map(ohosTileOverlayJson).toList())});');
  }

  @override
  Future<void> updateClusterManagers(
    ClusterManagerUpdates clusterManagerUpdates, {
    required int mapId,
  }) async {
    final OhosMapSession session = _session(mapId);
    final Set<String> ids = {
      ...session.clusterManagerIds,
      ...clusterManagerUpdates.clusterManagersToAdd
          .map((ClusterManager e) => e.clusterManagerId.value),
    }..removeAll(clusterManagerUpdates.clusterManagerIdsToRemove
        .map((ClusterManagerId e) => e.value));
    // Changes carry no payload beyond the id; full membership wins.
    session.clusterManagerIds
      ..clear()
      ..addAll(ids);
    session.eval(
        'OhosMaps.setClusterManagers(${jsonEncode(ids.toList())});');
  }

  @override
  Future<void> updateGroundOverlays(
    GroundOverlayUpdates groundOverlayUpdates, {
    required int mapId,
  }) async {
    final OhosMapSession session = _session(mapId);
    Future<Map<String, Object?>> one(GroundOverlay g) async =>
        ohosGroundOverlayJson(g, await session.icons.resolve(g.image));
    final List<Map<String, Object?>> add =
        await Future.wait(groundOverlayUpdates.groundOverlaysToAdd.map(one));
    final List<Map<String, Object?>> change =
        await Future.wait(groundOverlayUpdates.groundOverlaysToChange.map(one));
    final List<Map<String, Object?>> filteredAdd =
        add.where((Map<String, Object?> e) => e['url'] != null).toList();
    final List<Map<String, Object?>> filteredChange =
        change.where((Map<String, Object?> e) => e['url'] != null).toList();
    session.eval('OhosMaps.setGroundOverlays(${jsonEncode({
      'add': filteredAdd,
      'change': filteredChange,
      'remove': groundOverlayUpdates.groundOverlayIdsToRemove
          .map((GroundOverlayId e) => e.value)
          .toList(),
    })});');
  }

  @override
  Future<void> clearTileCache(
    TileOverlayId tileOverlayId, {
    required int mapId,
  }) async {
    _session(mapId)
        .eval('OhosMaps.clearTileCache(${jsonEncode(tileOverlayId.value)});');
  }

  // -- camera --------------------------------------------------------------------

  @override
  Future<void> animateCamera(
    CameraUpdate cameraUpdate, {
    required int mapId,
  }) async {
    _session(mapId).eval(
        'OhosMaps.animateCamera(${jsonEncode(ohosCameraOp(cameraUpdate))}, null);');
  }

  @override
  Future<void> animateCameraWithConfiguration(
    CameraUpdate cameraUpdate,
    CameraUpdateAnimationConfiguration configuration, {
    required int mapId,
  }) async {
    _session(mapId).eval('OhosMaps.animateCamera('
        '${jsonEncode(ohosCameraOp(cameraUpdate))}, '
        '${configuration.duration?.inMilliseconds});');
  }

  @override
  Future<void> moveCamera(
    CameraUpdate cameraUpdate, {
    required int mapId,
  }) async {
    _session(mapId).eval(
        'OhosMaps.moveCamera(${jsonEncode(ohosCameraOp(cameraUpdate))});');
  }

  // -- style ---------------------------------------------------------------------

  @override
  Future<void> setMapStyle(
    String? mapStyle, {
    required int mapId,
  }) async {
    final OhosMapSession session = _session(mapId);
    final Object? styles = ohosValidateStyle(
      mapStyle,
      (String? e) => session.styleError = e,
    );
    if (mapStyle == null) return; // absent: leave unchanged
    session.eval('OhosMaps.setOptions(${jsonEncode({'styles': styles})});');
  }

  @override
  Future<String?> getStyleError({required int mapId}) async =>
      _session(mapId).styleError;

  @override
  Future<bool> isAdvancedMarkersAvailable({required int mapId}) async =>
      _session(mapId).cloudMapId != null;

  // -- projection ------------------------------------------------------------------

  @override
  Future<LatLngBounds> getVisibleRegion({required int mapId}) async {
    final List<Object?> v = await _session(mapId)
        .request<List<Object?>>("OhosMaps.getVisibleRegion('REQ');");
    LatLng pair(Object? e) {
      final List<Object?> l = List<Object?>.from(e as List);
      return LatLng((l[0] as num).toDouble(), (l[1] as num).toDouble());
    }

    return LatLngBounds(southwest: pair(v[0]), northeast: pair(v[1]));
  }

  @override
  Future<ScreenCoordinate> getScreenCoordinate(
    LatLng latLng, {
    required int mapId,
  }) async {
    final Map<Object?, Object?> v = await _session(mapId)
        .request<Map<Object?, Object?>>(
            'OhosMaps.getScreenCoordinate(${latLng.latitude},'
            ' ${latLng.longitude}, \'REQ\');');
    return ScreenCoordinate(
      x: (v['x'] as num).toInt(),
      y: (v['y'] as num).toInt(),
    );
  }

  @override
  Future<LatLng> getLatLng(
    ScreenCoordinate screenCoordinate, {
    required int mapId,
  }) async {
    final List<Object?> v = await _session(mapId).request<List<Object?>>(
        'OhosMaps.getLatLng(${screenCoordinate.x},'
        ' ${screenCoordinate.y}, \'REQ\');');
    return LatLng((v[0] as num).toDouble(), (v[1] as num).toDouble());
  }

  // -- info windows ------------------------------------------------------------------

  @override
  Future<void> showMarkerInfoWindow(
    MarkerId markerId, {
    required int mapId,
  }) async {
    _session(mapId).eval(
        'OhosMaps.showInfoWindow(${jsonEncode(markerId.value)});');
  }

  @override
  Future<void> hideMarkerInfoWindow(
    MarkerId markerId, {
    required int mapId,
  }) async {
    _session(mapId).eval(
        'OhosMaps.hideInfoWindow(${jsonEncode(markerId.value)});');
  }

  @override
  Future<bool> isMarkerInfoWindowShown(
    MarkerId markerId, {
    required int mapId,
  }) async {
    return _session(mapId).request<bool>(
        'OhosMaps.isInfoWindowShown(${jsonEncode(markerId.value)}, \'REQ\');');
  }

  @override
  Future<double> getZoomLevel({required int mapId}) async {
    final Object? v =
        await _session(mapId).request<Object?>("OhosMaps.getZoom('REQ');");
    return (v as num).toDouble();
  }

  @override
  Future<Uint8List?> takeSnapshot({required int mapId}) async {
    // The JS API exposes no raster snapshot; the contract allows null.
    return null;
  }

  // -- events ------------------------------------------------------------------------

  @override
  Stream<CameraMoveStartedEvent> onCameraMoveStarted({required int mapId}) =>
      _session(mapId).cameraMoveStarted;

  @override
  Stream<CameraMoveEvent> onCameraMove({required int mapId}) =>
      _session(mapId).cameraMove;

  @override
  Stream<CameraIdleEvent> onCameraIdle({required int mapId}) =>
      _session(mapId).cameraIdle;

  @override
  Stream<MarkerTapEvent> onMarkerTap({required int mapId}) =>
      _session(mapId).markerTap;

  @override
  Stream<InfoWindowTapEvent> onInfoWindowTap({required int mapId}) =>
      _session(mapId).infoWindowTap;

  @override
  Stream<MarkerDragStartEvent> onMarkerDragStart({required int mapId}) =>
      _session(mapId).markerDragStart;

  @override
  Stream<MarkerDragEvent> onMarkerDrag({required int mapId}) =>
      _session(mapId).markerDrag;

  @override
  Stream<MarkerDragEndEvent> onMarkerDragEnd({required int mapId}) =>
      _session(mapId).markerDragEnd;

  @override
  Stream<PolylineTapEvent> onPolylineTap({required int mapId}) =>
      _session(mapId).polylineTap;

  @override
  Stream<PolygonTapEvent> onPolygonTap({required int mapId}) =>
      _session(mapId).polygonTap;

  @override
  Stream<CircleTapEvent> onCircleTap({required int mapId}) =>
      _session(mapId).circleTap;

  @override
  Stream<MapTapEvent> onTap({required int mapId}) => _session(mapId).tap;

  @override
  Stream<MapLongPressEvent> onLongPress({required int mapId}) =>
      _session(mapId).longPress;

  @override
  Stream<ClusterTapEvent> onClusterTap({required int mapId}) =>
      _session(mapId).clusterTap;

  @override
  Stream<GroundOverlayTapEvent> onGroundOverlayTap({required int mapId}) =>
      _session(mapId).groundOverlayTap;

  /// OHOS extension: taps on Google place icons (POI symbols).
  ///
  /// The stock plugin (on every platform) drops these; here they arrive as
  /// [OhosPoiTap] with the Google `placeId`, and — like the native SDKs —
  /// they do *not* also fire the plain map-tap stream.
  Stream<OhosPoiTap> onPoiTap({required int mapId}) =>
      _session(mapId).poiTap;

  /// Static convenience for apps holding a stock `GoogleMapController`:
  /// `GoogleMapsFlutterOhos.poiTaps(controller.mapId).listen(...)`.
  static Stream<OhosPoiTap> poiTaps(int mapId) =>
      (GoogleMapsFlutterPlatform.instance as GoogleMapsFlutterOhos)
          .onPoiTap(mapId: mapId);

  // -- my location ---------------------------------------------------------------------

  Future<LatLng?> _deviceFix() async {
    try {
      final Map<dynamic, dynamic>? res = await _locationChannel
          .invokeMethod<Map<dynamic, dynamic>>('getCurrentLocation');
      final double? lat = (res?['latitude'] as num?)?.toDouble();
      final double? lng = (res?['longitude'] as num?)?.toDouble();
      if (lat == null || lng == null) return null;
      if (lat < -90 || lat > 90 || lng < -180 || lng > 180) return null;
      return LatLng(lat, lng);
    } catch (_) {
      return null; // No host location service (tests, other platforms).
    }
  }

  Future<void> _refreshMyLocation(OhosMapSession session) async {
    if (!session.myLocationEnabled) {
      session.eval('OhosMaps.setMyLocation(null, null);');
      return;
    }
    final LatLng? fix = await _deviceFix();
    if (fix == null) {
      session.onMapError(
          'My-location layer is on, but no device fix is available.');
      return;
    }
    session.eval(
        'OhosMaps.setMyLocation(${fix.latitude}, ${fix.longitude});');
  }

  Future<void> _onMyLocationButton(OhosMapSession session) async {
    final LatLng? fix = await _deviceFix();
    if (fix == null) {
      session.onMapError('Location unavailable.');
      return;
    }
    session.eval('OhosMaps.setMyLocation(${fix.latitude}, ${fix.longitude});');
    await moveCamera(CameraUpdate.newLatLngZoom(fix, 15), mapId: session.mapId);
  }
}
