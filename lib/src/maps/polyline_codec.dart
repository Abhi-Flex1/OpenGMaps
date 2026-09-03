/// Google encoded-polyline codec (overview_polyline from Directions API).
///
/// Pure Dart, fully unit-tested. See
/// https://developers.google.com/maps/documentation/utilities/polylinealgorithm
library;

import 'package:google_maps_flutter/google_maps_flutter.dart';

class PolylineCodec {
  PolylineCodec._();

  /// Decodes an encoded polyline string into coordinates.
  static List<LatLng> decode(String encoded) {
    final points = <LatLng>[];
    var index = 0;
    var lat = 0;
    var lng = 0;
    while (index < encoded.length) {
      var shift = 0;
      var result = 0;
      int b;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dLat = ((result & 1) != 0) ? ~(result >> 1) : (result >> 1);
      lat += dLat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dLng = ((result & 1) != 0) ? ~(result >> 1) : (result >> 1);
      lng += dLng;

      points.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return points;
  }

  /// Encodes coordinates (used in tests + fit-bounds payloads).
  static String encode(List<LatLng> points) {
    var lastLat = 0;
    var lastLng = 0;
    final buffer = StringBuffer();
    for (final p in points) {
      final lat = (p.latitude * 1e5).round();
      final lng = (p.longitude * 1e5).round();
      buffer.write(_encodeSigned(lat - lastLat));
      buffer.write(_encodeSigned(lng - lastLng));
      lastLat = lat;
      lastLng = lng;
    }
    return buffer.toString();
  }

  static String _encodeSigned(int v) {
    var s = v < 0 ? ~(v << 1) : (v << 1);
    final out = StringBuffer();
    while (s >= 0x20) {
      out.writeCharCode((0x20 | (s & 0x1f)) + 63);
      s >>= 5;
    }
    out.writeCharCode(s + 63);
    return out.toString();
  }
}
