/// Official Directions API over HTTPS (keyed) + universal Navigate URL.
///
/// * Route — `GET /maps/api/directions/json?origin=&destination=&mode=&key=`
/// * Turn-by-turn UI — universal `https://www.google.com/maps/dir/?api=1…`
///   opened in an in-app WebView (keyless, official).
library;

import 'dart:convert';

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import '../config/google_maps_config.dart';
import '../maps/polyline_codec.dart';

/// Travel profile for the Directions API and the Navigate link.
enum TravelMode { driving, walking, bicycling, transit }

extension TravelModeX on TravelMode {
  String get label {
    switch (this) {
      case TravelMode.driving:
        return 'Driving';
      case TravelMode.walking:
        return 'Walking';
      case TravelMode.bicycling:
        return 'Cycling';
      case TravelMode.transit:
        return 'Transit';
    }
  }

  /// Lowercase token for the Directions API `mode` param.
  String get apiValue {
    switch (this) {
      case TravelMode.driving:
        return 'driving';
      case TravelMode.walking:
        return 'walking';
      case TravelMode.bicycling:
        return 'bicycling';
      case TravelMode.transit:
        return 'transit';
    }
  }
}

class DirectionStep {
  const DirectionStep({
    required this.instruction,
    required this.distanceText,
    required this.maneuver,
  });

  final String instruction;
  final String distanceText;
  final String maneuver;
}

class DirectionRoute {
  const DirectionRoute({
    required this.points,
    required this.distanceText,
    required this.distanceMeters,
    required this.durationText,
    required this.durationMeters,
    required this.startAddress,
    required this.endAddress,
    required this.startLatLng,
    required this.endLatLng,
    this.steps = const [],
  });

  final List<LatLng> points;
  final String distanceText;
  final int distanceMeters;
  final String durationText;
  final int durationMeters;
  final String startAddress;
  final String endAddress;
  final LatLng startLatLng;
  final LatLng endLatLng;
  final List<DirectionStep> steps;
}

class GoogleDirectionsService {
  GoogleDirectionsService({http.Client? client, String? apiKey})
      : _client = client ?? http.Client(),
        _key = (apiKey ?? GoogleMapsConfig.apiKey);

  static final GoogleDirectionsService instance = GoogleDirectionsService();

  final http.Client _client;
  final String _key;

  /// Route between free-text or `lat,lng` [origin]/[destination].
  Future<DirectionRoute?> getRoute({
    required String origin,
    required String destination,
    TravelMode mode = TravelMode.driving,
    String language = 'en',
  }) async {
    if (_key.isEmpty) throw const MissingGoogleMapsKey();
    if (origin.trim().isEmpty || destination.trim().isEmpty) return null;
    final uri = Uri.https('maps.googleapis.com', '/maps/api/directions/json', {
      'origin': origin.trim(),
      'destination': destination.trim(),
      'mode': mode.apiValue,
      'language': language,
      'key': _key,
    });
    final res = await _client.get(uri).timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      throw GoogleMapsApiException('HTTP_${res.statusCode}', res.body);
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return parseRoute(body);
  }

  /// Universal turn-by-turn URL (official, needs no key in the WebView).
  static String universalUrl(
    String origin,
    String destination,
    TravelMode mode,
  ) {
    String travelmode;
    switch (mode) {
      case TravelMode.walking:
        travelmode = 'walking';
        break;
      case TravelMode.bicycling:
        travelmode = 'bicycling';
        break;
      case TravelMode.transit:
        travelmode = 'transit';
        break;
      case TravelMode.driving:
        travelmode = 'driving';
        break;
    }
    final q = {
      'api': '1',
      'origin': origin,
      'destination': destination,
      'travelmode': travelmode,
    }
        .entries
        .map((e) =>
            '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');
    return 'https://www.google.com/maps/dir/?$q';
  }

  // -- pure parser (unit-tested, no network) -------------------------------

  static DirectionRoute? parseRoute(Map<String, dynamic> body) {
    final status = (body['status'] ?? 'UNKNOWN_ERROR') as String;
    if (status == 'ZERO_RESULTS' || status == 'NOT_FOUND') return null;
    if (status != 'OK') {
      throw GoogleMapsApiException(
          status, (body['error_message'] ?? '') as String);
    }
    final routes = (body['routes'] as List?) ?? [];
    if (routes.isEmpty) return null;
    final route = routes.first as Map<String, dynamic>;
    final legs = (route['legs'] as List?) ?? [];
    if (legs.isEmpty) return null;
    final leg = legs.first as Map<String, dynamic>;

    final encoded =
        ((route['overview_polyline'] as Map?)?['points'] ?? '') as String;
    final points =
        encoded.isEmpty ? <LatLng>[] : PolylineCodec.decode(encoded);

    LatLng locOf(Map<String, dynamic>? m) {
      final v = (m?['value'] ?? m) as Map<String, dynamic>?;
      final lat = ((v?['lat'] ?? 0) as num).toDouble();
      final lng = ((v?['lng'] ?? 0) as num).toDouble();
      return LatLng(lat, lng);
    }

    final dist = (leg['distance'] as Map<String, dynamic>?) ?? {};
    final dur = (leg['duration'] as Map<String, dynamic>?) ?? {};
    final rawSteps = (leg['steps'] as List?) ?? [];
    final steps = rawSteps.map((s) {
      final m = s as Map<String, dynamic>;
      final d = (m['distance'] as Map?)?['text'] ?? '';
      return DirectionStep(
        instruction: _stripHtml((m['html_instructions'] ?? '') as String),
        distanceText: '$d',
        maneuver: (m['maneuver'] ?? '') as String,
      );
    }).toList();

    return DirectionRoute(
      points: points,
      distanceText: (dist['text'] ?? '') as String,
      distanceMeters: ((dist['value'] ?? 0) as num).toInt(),
      durationText: (dur['text'] ?? '') as String,
      durationMeters: ((dur['value'] ?? 0) as num).toInt(),
      startAddress: (leg['start_address'] ?? '') as String,
      endAddress: (leg['end_address'] ?? '') as String,
      startLatLng: locOf(leg['start_location'] as Map<String, dynamic>?),
      endLatLng: locOf(leg['end_location'] as Map<String, dynamic>?),
      steps: steps,
    );
  }

  static String _stripHtml(String html) =>
      html.replaceAll(RegExp(r'<[^>]*>'), '').trim();
}
