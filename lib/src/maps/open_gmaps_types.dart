import 'package:flutter/material.dart';

/// Common types for OpenGMaps — mirrors google_maps_flutter API for portability.

class OpenLatLng {
  const OpenLatLng(this.latitude, this.longitude);
  final double latitude;
  final double longitude;

  @override
  bool operator ==(Object other) => other is OpenLatLng && other.latitude == latitude && other.longitude == longitude;
  @override
  int get hashCode => Object.hash(latitude, longitude);
  @override
  String toString() => 'OpenLatLng($latitude, $longitude)';
}

class OpenCameraPosition {
  const OpenCameraPosition({required this.target, this.zoom = 14, this.bearing = 0, this.tilt = 0});
  final OpenLatLng target;
  final double zoom;
  final double bearing;
  final double tilt;

  OpenCameraPosition copyWith({OpenLatLng? target, double? zoom}) =>
      OpenCameraPosition(target: target ?? this.target, zoom: zoom ?? this.zoom, bearing: bearing, tilt: tilt);
}

class OpenMarker {
  const OpenMarker({
    required this.markerId,
    required this.position,
    this.title,
    this.snippet,
    this.icon,
    this.onTap,
  });
  final String markerId;
  final OpenLatLng position;
  final String? title;
  final String? snippet;
  final Widget? icon;
  final VoidCallback? onTap;
}

class OpenCircle {
  const OpenCircle({required this.circleId, required this.center, required this.radius, this.fillColor, this.strokeColor, this.strokeWidth = 1});
  final String circleId;
  final OpenLatLng center;
  final double radius; // meters
  final Color? fillColor;
  final Color? strokeColor;
  final double strokeWidth;
}

class OpenPolyline {
  const OpenPolyline({required this.polylineId, required this.points, this.color = Colors.blue, this.width = 4});
  final String polylineId;
  final List<OpenLatLng> points;
  final Color color;
  final double width;
}

enum OpenMapType { normal, satellite, terrain, hybrid }

extension OpenMapTypeX on OpenMapType {
  String get label {
    switch (this) {
      case OpenMapType.normal:
        return 'Normal';
      case OpenMapType.satellite:
        return 'Satellite';
      case OpenMapType.terrain:
        return 'Terrain';
      case OpenMapType.hybrid:
        return 'Hybrid';
    }
  }

  IconData get icon {
    switch (this) {
      case OpenMapType.normal:
        return Icons.map_outlined;
      case OpenMapType.satellite:
        return Icons.satellite_alt_outlined;
      case OpenMapType.terrain:
        return Icons.terrain_outlined;
      case OpenMapType.hybrid:
        return Icons.layers_outlined;
    }
  }
}
