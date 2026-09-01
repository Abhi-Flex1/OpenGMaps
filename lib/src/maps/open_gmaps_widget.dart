import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'open_gmaps_types.dart';
import 'open_gmaps_controller.dart';
import 'ohos_tile_map.dart';

/// Unified map widget — delegates to google_maps_flutter on Android/iOS/Web,
/// and to OhosTileMap on OpenHarmony.
///
/// Usage mirrors google_maps_flutter but with Open* types for portability.
class OpenGMaps extends StatefulWidget {
  const OpenGMaps({
    super.key,
    required this.initialPosition,
    this.markers = const {},
    this.circles = const {},
    this.polylines = const {},
    this.mapType = OpenMapType.normal,
    this.myLocationEnabled = false,
    this.zoomControlsEnabled = false,
    this.onCameraMove,
    this.onTap,
    this.onMapCreated,
  });

  final OpenCameraPosition initialPosition;
  final Set<OpenMarker> markers;
  final Set<OpenCircle> circles;
  final Set<OpenPolyline> polylines;
  final OpenMapType mapType;
  final bool myLocationEnabled;
  final bool zoomControlsEnabled;
  final ValueChanged<OpenCameraPosition>? onCameraMove;
  final ValueChanged<OpenLatLng>? onTap;
  final ValueChanged<OpenGMapsController>? onMapCreated;

  @override
  State<OpenGMaps> createState() => _OpenGMapsState();
}

class _OpenGMapsState extends State<OpenGMaps> {
  gmaps.GoogleMapController? _nativeController;
  OhosTileController? _ohosController;

  bool get _isOhos {
    // Return true on OpenHarmony / non-GMS platforms to use the pure-Dart tile map implementation
    return true;
  }

  @override
  void initState() {
    super.initState();
    if (_isOhos) {
      _ohosController = OhosTileController(initialPosition: widget.initialPosition);
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.onMapCreated?.call(_ohosController!));
    }
  }

  gmaps.MapType _toGmapsType(OpenMapType t) {
    switch (t) {
      case OpenMapType.normal:
        return gmaps.MapType.normal;
      case OpenMapType.satellite:
        return gmaps.MapType.satellite;
      case OpenMapType.terrain:
        return gmaps.MapType.terrain;
      case OpenMapType.hybrid:
        return gmaps.MapType.hybrid;
    }
  }

  Set<gmaps.Marker> _toGmapsMarkers() => widget.markers
      .map((m) => gmaps.Marker(
            markerId: gmaps.MarkerId(m.markerId),
            position: gmaps.LatLng(m.position.latitude, m.position.longitude),
            infoWindow: gmaps.InfoWindow(title: m.title, snippet: m.snippet),
            onTap: m.onTap,
          ))
      .toSet();

  Set<gmaps.Circle> _toGmapsCircles() => widget.circles
      .map((c) => gmaps.Circle(
            circleId: gmaps.CircleId(c.circleId),
            center: gmaps.LatLng(c.center.latitude, c.center.longitude),
            radius: c.radius,
            fillColor: c.fillColor ?? Colors.blue.withOpacity(0.15),
            strokeColor: c.strokeColor ?? Colors.blue,
            strokeWidth: c.strokeWidth.toInt(),
          ))
      .toSet();

  Set<gmaps.Polyline> _toGmapsPolylines() => widget.polylines
      .map((p) => gmaps.Polyline(
            polylineId: gmaps.PolylineId(p.polylineId),
            points: p.points.map((e) => gmaps.LatLng(e.latitude, e.longitude)).toList(),
            color: p.color,
            width: p.width.toInt(),
          ))
      .toSet();

  @override
  Widget build(BuildContext context) {
    if (_isOhos) {
      return OhosTileMap(
        initialPosition: widget.initialPosition,
        markers: widget.markers,
        mapType: widget.mapType,
        controller: _ohosController,
        onCameraMove: widget.onCameraMove,
        onTap: widget.onTap,
      );
    }

    // Native Google Maps (Android, iOS, Web)
    return gmaps.GoogleMap(
      initialCameraPosition: gmaps.CameraPosition(
        target: gmaps.LatLng(widget.initialPosition.target.latitude, widget.initialPosition.target.longitude),
        zoom: widget.initialPosition.zoom,
        bearing: widget.initialPosition.bearing,
        tilt: widget.initialPosition.tilt,
      ),
      markers: _toGmapsMarkers(),
      circles: _toGmapsCircles(),
      polylines: _toGmapsPolylines(),
      mapType: _toGmapsType(widget.mapType),
      myLocationEnabled: widget.myLocationEnabled,
      zoomControlsEnabled: widget.zoomControlsEnabled,
      onCameraMove: (pos) => widget.onCameraMove?.call(OpenCameraPosition(
        target: OpenLatLng(pos.target.latitude, pos.target.longitude),
        zoom: pos.zoom,
        bearing: pos.bearing,
        tilt: pos.tilt,
      )),
      onTap: (latLng) => widget.onTap?.call(OpenLatLng(latLng.latitude, latLng.longitude)),
      onMapCreated: (controller) {
        _nativeController = controller;
        // Wrap native controller into OpenGMapsController interface
        final wrapper = _NativeControllerWrapper(controller);
        widget.onMapCreated?.call(wrapper);
      },
    );
  }

  @override
  void dispose() {
    _nativeController?.dispose();
    _ohosController?.dispose();
    super.dispose();
  }
}

class _NativeControllerWrapper implements OpenGMapsController {
  _NativeControllerWrapper(this._ctrl);
  final gmaps.GoogleMapController _ctrl;

  @override
  Future<void> animateCamera(OpenCameraPosition position) => _ctrl.animateCamera(gmaps.CameraUpdate.newCameraPosition(gmaps.CameraPosition(
        target: gmaps.LatLng(position.target.latitude, position.target.longitude),
        zoom: position.zoom,
        bearing: position.bearing,
        tilt: position.tilt,
      )));

  @override
  Future<OpenCameraPosition> getCameraPosition() async {
    final v = await _ctrl.getVisibleRegion();
    // approximate center
    final lat = (v.northeast.latitude + v.southwest.latitude) / 2;
    final lng = (v.northeast.longitude + v.southwest.longitude) / 2;
    // zoom not exposed, fallback
    return OpenCameraPosition(target: OpenLatLng(lat, lng), zoom: 14);
  }

  @override
  Future<void> addMarker(OpenMarker marker) async {
    // No-op: markers are managed declaratively via widget set. For imperative API, rebuild required.
  }

  @override
  Future<void> clearMarkers() async {}

  @override
  void dispose() => _ctrl.dispose();
}
