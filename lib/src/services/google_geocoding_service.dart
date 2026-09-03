/// Official Geocoding API over HTTPS (keyed).
///
/// * Reverse — `/maps/api/geocode/json?latlng=`
/// * Forward — `/maps/api/geocode/json?address=`
library;

import 'dart:convert';

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import '../config/google_maps_config.dart';
import '../utils/geo.dart';

class GeocodedAddress {
  const GeocodedAddress({
    required this.formatted,
    required this.latLng,
    required this.placeId,
    this.types = const [],
  });

  final String formatted;
  final LatLng latLng;
  final String placeId;
  final List<String> types;

  factory GeocodedAddress.fromJson(Map<String, dynamic> json) {
    final geometry = (json['geometry'] as Map<String, dynamic>?) ?? {};
    final loc = (geometry['location'] as Map<String, dynamic>?) ?? {};
    return GeocodedAddress(
      formatted: (json['formatted_address'] ?? '') as String,
      latLng: LatLng(
        ((loc['lat'] ?? 0) as num).toDouble(),
        ((loc['lng'] ?? 0) as num).toDouble(),
      ),
      placeId: (json['place_id'] ?? '') as String,
      types: ((json['types'] as List?) ?? []).map((e) => '$e').toList(),
    );
  }
}

class GoogleGeocodingService {
  GoogleGeocodingService({http.Client? client, String? apiKey})
      : _client = client ?? http.Client(),
        _key = (apiKey ?? GoogleMapsConfig.apiKey);

  static final GoogleGeocodingService instance = GoogleGeocodingService();

  final http.Client _client;
  final String _key;

  Future<Map<String, dynamic>> _get(Map<String, String> params) async {
    if (_key.isEmpty) throw const MissingGoogleMapsKey();
    final uri = Uri.https('maps.googleapis.com', '/maps/api/geocode/json',
        {...params, 'key': _key});
    final res = await _client.get(uri).timeout(const Duration(seconds: 12));
    if (res.statusCode != 200) {
      throw GoogleMapsApiException('HTTP_${res.statusCode}', res.body);
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final status = (body['status'] ?? 'UNKNOWN_ERROR') as String;
    if (status == 'OK' || status == 'ZERO_RESULTS') return body;
    throw GoogleMapsApiException(
        status, (body['error_message'] ?? '') as String);
  }

  /// Nearest addresses for a map tap. Empty list = nothing known there.
  Future<List<GeocodedAddress>> reverse(
    LatLng at, {
    String language = 'en',
  }) async {
    final body = await _get({'latlng': at.asParam, 'language': language});
    return parseResults(body);
  }

  /// Forward-geocode a typed origin/destination into coordinates.
  Future<List<GeocodedAddress>> forward(
    String address, {
    String language = 'en',
  }) async {
    if (address.trim().isEmpty) return [];
    final body =
        await _get({'address': address.trim(), 'language': language});
    return parseResults(body);
  }

  static List<GeocodedAddress> parseResults(Map<String, dynamic> body) {
    final list = (body['results'] as List?) ?? [];
    return list
        .map((e) => GeocodedAddress.fromJson(e as Map<String, dynamic>))
        .where((a) => a.formatted.isNotEmpty)
        .toList();
  }
}
