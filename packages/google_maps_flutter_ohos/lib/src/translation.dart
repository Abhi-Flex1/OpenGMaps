// Copyright 2026 The OpenGMaps Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license.

import 'dart:convert';

import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';

/// ARGB int → CSS color. Alpha < 255 becomes `rgba(...)`; JS reads opacity
/// separately for strokes/fills where needed.
String ohosColorCss(int argb) {
  final int a = (argb >> 24) & 0xFF;
  final int r = (argb >> 16) & 0xFF;
  final int g = (argb >> 8) & 0xFF;
  final int b = argb & 0xFF;
  if (a == 0xFF) {
    return '#${r.toRadixString(16).padLeft(2, '0')}'
        '${g.toRadixString(16).padLeft(2, '0')}'
        '${b.toRadixString(16).padLeft(2, '0')}';
  }
  return 'rgba($r,$g,$b,${(a / 255).toStringAsFixed(3)})';
}

/// Translate a [CameraUpdate] into the `OhosMaps` op payload.
Map<String, Object?> ohosCameraOp(CameraUpdate update) {
  switch (update.updateType) {
    case CameraUpdateType.newCameraPosition:
      final CameraPosition p =
          (update as CameraUpdateNewCameraPosition).cameraPosition;
      return {
        'kind': 'newCameraPosition',
        'position': [
          p.target.latitude,
          p.target.longitude,
          p.zoom,
          p.tilt,
          p.bearing,
        ],
      };
    case CameraUpdateType.newLatLng:
      final LatLng ll = (update as CameraUpdateNewLatLng).latLng;
      return {'kind': 'newLatLng', 'lat': ll.latitude, 'lng': ll.longitude};
    case CameraUpdateType.newLatLngBounds:
      final CameraUpdateNewLatLngBounds b =
          update as CameraUpdateNewLatLngBounds;
      return {
        'kind': 'newLatLngBounds',
        'sw': [b.bounds.southwest.latitude, b.bounds.southwest.longitude],
        'ne': [b.bounds.northeast.latitude, b.bounds.northeast.longitude],
        'padding': b.padding,
      };
    case CameraUpdateType.newLatLngZoom:
      final CameraUpdateNewLatLngZoom z =
          update as CameraUpdateNewLatLngZoom;
      return {
        'kind': 'newLatLngZoom',
        'lat': z.latLng.latitude,
        'lng': z.latLng.longitude,
        'zoom': z.zoom,
      };
    case CameraUpdateType.scrollBy:
      final CameraUpdateScrollBy s = update as CameraUpdateScrollBy;
      return {'kind': 'scrollBy', 'dx': s.dx, 'dy': s.dy};
    case CameraUpdateType.zoomBy:
      final CameraUpdateZoomBy z = update as CameraUpdateZoomBy;
      return {
        'kind': 'zoomBy',
        'amount': z.amount,
        if (z.focus != null)
          'focus': [z.focus!.dx, z.focus!.dy],
      };
    case CameraUpdateType.zoomIn:
      return const {'kind': 'zoomIn'};
    case CameraUpdateType.zoomOut:
      return const {'kind': 'zoomOut'};
    case CameraUpdateType.zoomTo:
      return {'kind': 'zoomTo', 'zoom': (update as CameraUpdateZoomTo).zoom};
  }
}

/// JS `MapTypeId` for a plugin [MapType]. `none` blanks the base map via a
/// hide-everything style applied on the JS side.
String ohosMapTypeId(MapType type) {
  switch (type) {
    case MapType.none:
      return 'none';
    case MapType.normal:
      return 'roadmap';
    case MapType.satellite:
      return 'satellite';
    case MapType.terrain:
      return 'terrain';
    case MapType.hybrid:
      return 'hybrid';
  }
}

/// Validate a `GoogleMap.style` JSON string. Returns the decoded style list
/// (empty string clears), recording failures for [getStyleError].
Object? ohosValidateStyle(String? style, void Function(String?) setError) {
  if (style == null) return null; // absent: leave unchanged
  if (style.isEmpty) {
    setError(null);
    return <Object?>[]; // clear
  }
  try {
    final Object? decoded = jsonDecode(style);
    if (decoded is! List) {
      throw const FormatException('Map style must be a JSON array');
    }
    setError(null);
    return decoded;
  } catch (e) {
    final String message = 'Invalid map style: $e';
    setError(message);
    throw MapStyleException(message);
  }
}

/// Translate [MapConfiguration] (only non-null fields are applied) into the
/// `OhosMaps.setOptions` payload. Location + button flags are handled
/// Dart-side and excluded here. [onStyleError] records style failures for
/// `getStyleError`; invalid styles still throw [MapStyleException].
Map<String, Object?> ohosMapOptions(
  MapConfiguration c, {
  void Function(String?)? onStyleError,
}) {
  final Map<String, Object?> o = {};
  if (c.mapType != null) o['mapType'] = ohosMapTypeId(c.mapType!);
  if (c.style != null) {
    o['styles'] = ohosValidateStyle(c.style, onStyleError ?? (_) {});
  }
  if (c.mapId != null) o['cloudMapId'] = c.mapId!;
  if (c.minMaxZoomPreference != null) {
    o['minZoom'] = c.minMaxZoomPreference!.minZoom;
    o['maxZoom'] = c.minMaxZoomPreference!.maxZoom;
  }
  if (c.cameraTargetBounds != null) {
    final LatLngBounds? b = c.cameraTargetBounds!.bounds;
    o['restriction'] = b == null
        ? null
        : {
            'latLngBounds': {
              'south': b.southwest.latitude,
              'west': b.southwest.longitude,
              'north': b.northeast.latitude,
              'east': b.northeast.longitude,
            },
            'strictBounds': true,
          };
  }
  if (c.zoomControlsEnabled != null) o['zoomControl'] = c.zoomControlsEnabled!;
  if (c.webGestureHandling != null) {
    o['gestureHandling'] = c.webGestureHandling!.name;
  } else {
    final bool scroll = c.scrollGesturesEnabled ?? true;
    final bool zoom = c.zoomGesturesEnabled ?? true;
    o['gestureHandling'] = (!scroll && !zoom) ? 'none' : 'greedy';
    o['scrollwheel'] = scroll;
    o['draggable'] = scroll;
    o['disableDoubleClickZoom'] = !zoom;
  }
  if (c.fortyFiveDegreeImageryEnabled != null) {
    o['tilt'] = c.fortyFiveDegreeImageryEnabled! ? 45 : 0;
  }
  if (c.trafficEnabled != null) o['traffic'] = c.trafficEnabled!;
  if (c.trackCameraPosition != null) o['trackCamera'] = c.trackCameraPosition!;
  return o;
}

Map<String, Object?> ohosMarkerJson(
  Marker m,
  Map<String, Object?> icon, {
  required bool advanced,
}) =>
    {
      'id': m.markerId.value,
      'lat': m.position.latitude,
      'lng': m.position.longitude,
      'title': m.infoWindow.title,
      'snippet': m.infoWindow.snippet,
      'draggable': m.draggable,
      'visible': m.visible,
      'opacity': m.alpha,
      'zIndex': m.zIndexInt,
      'anchor': [m.anchor.dx, m.anchor.dy],
      'icon': icon,
      'advanced': advanced,
      if (m.clusterManagerId != null) 'cluster': m.clusterManagerId!.value,
    };

Map<String, Object?> ohosPolylineJson(Polyline p) => {
      'id': p.polylineId.value,
      'points': p.points
          .map((LatLng e) => [e.latitude, e.longitude])
          .toList(),
      'color': p.color.value,
      'width': p.width,
      'visible': p.visible,
      'zIndex': p.zIndex,
      'geodesic': p.geodesic,
      'clickable': p.consumeTapEvents,
      'patterns': p.patterns.map((PatternItem e) {
        final Object j = e.toJson();
        return j is List ? j : [j];
      }).toList(),
    };

Map<String, Object?> ohosPolygonJson(Polygon p) => {
      'id': p.polygonId.value,
      'points': p.points
          .map((LatLng e) => [e.latitude, e.longitude])
          .toList(),
      'holes': p.holes
          .map((List<LatLng> ring) => ring
              .map((LatLng e) => [e.latitude, e.longitude])
              .toList())
          .toList(),
      'fillColor': p.fillColor.value,
      'strokeColor': p.strokeColor.value,
      'strokeWidth': p.strokeWidth,
      'visible': p.visible,
      'zIndex': p.zIndex,
      'geodesic': p.geodesic,
      'clickable': p.consumeTapEvents,
    };

Map<String, Object?> ohosCircleJson(Circle c) => {
      'id': c.circleId.value,
      'lat': c.center.latitude,
      'lng': c.center.longitude,
      'radius': c.radius,
      'fillColor': c.fillColor.value,
      'strokeColor': c.strokeColor.value,
      'strokeWidth': c.strokeWidth,
      'visible': c.visible,
      'zIndex': c.zIndex,
      'clickable': c.consumeTapEvents,
    };

Map<String, Object?> ohosHeatmapJson(Heatmap h) => {
      'id': h.heatmapId.value,
      'data': h.data
          .map((WeightedLatLng e) => [
                [e.point.latitude, e.point.longitude],
                e.weight,
              ])
          .toList(),
      'dissipating': h.dissipating,
      'gradient': h.gradient == null
          ? null
          : {
              'colors': h.gradient!.colors
                  .map((HeatmapGradientColor e) =>
                      ohosColorCss(e.color.value))
                  .toList(),
              'starts': h.gradient!.colors
                  .map((HeatmapGradientColor e) => e.startPoint)
                  .toList(),
            },
      'maxIntensity': h.maxIntensity,
      'opacity': h.opacity,
      'radius': h.radius.radius,
      'minZ': h.minimumZoomIntensity,
      'maxZ': h.maximumZoomIntensity,
    };

Map<String, Object?> ohosTileOverlayJson(TileOverlay t) => {
      'id': t.tileOverlayId.value,
      'tileSize': t.tileSize,
      'transparency': t.transparency,
      'zIndex': t.zIndex,
      'visible': t.visible,
      'fadeIn': t.fadeIn,
    };

Map<String, Object?> ohosGroundOverlayJson(
  GroundOverlay g,
  Map<String, Object?> image,
) {
  String? url;
  final Object? kind = image['kind'];
  if (kind == 'url') {
    url = image['url'] as String?;
  }
  return {
    'id': g.groundOverlayId.value,
    'url': url,
    'bounds': g.bounds == null
        ? null
        : [
            [g.bounds!.southwest.latitude, g.bounds!.southwest.longitude],
            [g.bounds!.northeast.latitude, g.bounds!.northeast.longitude],
          ],
    'position': g.position == null
        ? null
        : [g.position!.latitude, g.position!.longitude],
    'width': g.width,
    'height': g.height,
    'transparency': g.transparency,
    'zIndex': g.zIndex,
    'visible': g.visible,
    'clickable': g.clickable,
  };
}
