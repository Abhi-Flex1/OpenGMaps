import 'open_gmaps_types.dart';

/// Abstract controller — same surface for both native Google Maps and OHOS tile fallback.
abstract class OpenGMapsController {
  Future<void> animateCamera(OpenCameraPosition position);
  Future<OpenCameraPosition> getCameraPosition();
  Future<void> addMarker(OpenMarker marker);
  Future<void> clearMarkers();
  void dispose();
}

/// Simple ValueNotifier-based controller for OHOS tile map.
class OhosTileController implements OpenGMapsController {
  OhosTileController({required OpenCameraPosition initialPosition}) : _position = initialPosition;

  OpenCameraPosition _position;
  final List<OpenMarker> markers = [];
  final List<void Function()> _listeners = [];

  OpenCameraPosition get position => _position;

  void addListener(void Function() cb) => _listeners.add(cb);
  void removeListener(void Function() cb) => _listeners.remove(cb);
  void _notify() {
    for (final c in _listeners) {
      c();
    }
  }

  @override
  Future<void> animateCamera(OpenCameraPosition position) async {
    _position = position;
    _notify();
  }

  @override
  Future<OpenCameraPosition> getCameraPosition() async => _position;

  @override
  Future<void> addMarker(OpenMarker marker) async {
    markers.removeWhere((m) => m.markerId == marker.markerId);
    markers.add(marker);
    _notify();
  }

  @override
  Future<void> clearMarkers() async {
    markers.clear();
    _notify();
  }

  @override
  void dispose() => _listeners.clear();
}
