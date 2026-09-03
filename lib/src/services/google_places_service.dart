/// Official Places API over HTTPS (keyed).
///
/// Endpoints (all `maps.googleapis.com`, GET + `key`):
/// * Autocomplete — `/maps/api/place/autocomplete/json`
/// * Text Search — `/maps/api/place/textsearch/json`
/// * Details — `/maps/api/place/details/json`
///
/// Key comes from `--dart-define=GOOGLE_MAPS_API_KEY` unless overridden
/// (tests / flavors). All failures surface as [GoogleMapsApiException];
/// missing key surfaces as [MissingGoogleMapsKey].
library;

import 'dart:convert';

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import '../config/google_maps_config.dart';
import '../utils/geo.dart';

class PlacePrediction {
  const PlacePrediction({
    required this.placeId,
    required this.description,
    required this.mainText,
    required this.secondaryText,
  });

  final String placeId;
  final String description;
  final String mainText;
  final String secondaryText;

  factory PlacePrediction.fromJson(Map<String, dynamic> json) {
    final formatting =
        (json['structured_formatting'] as Map<String, dynamic>?) ?? {};
    return PlacePrediction(
      placeId: (json['place_id'] ?? '') as String,
      description: (json['description'] ?? '') as String,
      mainText: (formatting['main_text'] ?? json['description'] ?? '') as String,
      secondaryText: (formatting['secondary_text'] ?? '') as String,
    );
  }
}

class PlaceDetails {
  const PlaceDetails({
    required this.placeId,
    required this.name,
    required this.address,
    required this.latLng,
    this.rating,
    this.ratingCount = 0,
    this.types = const [],
    this.website = '',
    this.openNow,
  });

  final String placeId;
  final String name;
  final String address;
  final LatLng latLng;
  final double? rating;
  final int ratingCount;
  final List<String> types;
  final String website;
  final bool? openNow;

  factory PlaceDetails.fromJson(Map<String, dynamic> json) {
    final geometry = (json['geometry'] as Map<String, dynamic>?) ?? {};
    final loc = (geometry['location'] as Map<String, dynamic>?) ?? {};
    final hours = (json['opening_hours'] as Map<String, dynamic>?);
    return PlaceDetails(
      placeId: (json['place_id'] ?? '') as String,
      name: (json['name'] ?? '') as String,
      address: (json['formatted_address'] ?? json['vicinity'] ?? '') as String,
      latLng: LatLng(
        ((loc['lat'] ?? 0) as num).toDouble(),
        ((loc['lng'] ?? 0) as num).toDouble(),
      ),
      rating: (json['rating'] as num?)?.toDouble(),
      ratingCount: (json['user_ratings_total'] as num?)?.toInt() ?? 0,
      types: ((json['types'] as List?) ?? []).map((e) => '$e').toList(),
      website: (json['website'] ?? '') as String,
      openNow: hours == null ? null : hours['open_now'] as bool?,
    );
  }
}

class GooglePlacesService {
  GooglePlacesService({http.Client? client, String? apiKey})
      : _client = client ?? http.Client(),
        _key = (apiKey ?? GoogleMapsConfig.apiKey);

  static final GooglePlacesService instance = GooglePlacesService();

  final http.Client _client;
  final String _key;

  Future<Map<String, dynamic>> _get(
      String path, Map<String, String> params) async {
    if (_key.isEmpty) throw const MissingGoogleMapsKey();
    final uri = Uri.https('maps.googleapis.com', path,
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

  /// Type-ahead suggestions for [input].
  Future<List<PlacePrediction>> autocomplete(
    String input, {
    LatLng? near,
    String language = 'en',
  }) async {
    if (input.trim().isEmpty) return [];
    final body = await _get('/maps/api/place/autocomplete/json', {
      'input': input.trim(),
      'language': language,
      if (near != null) 'location': near.asParam,
      if (near != null) 'radius': '50000',
    });
    return parsePredictions(body);
  }

  /// Top matches for a free-text query.
  Future<List<PlaceDetails>> searchText(
    String query, {
    LatLng? near,
    String language = 'en',
  }) async {
    if (query.trim().isEmpty) return [];
    final body = await _get('/maps/api/place/textsearch/json', {
      'query': query.trim(),
      'language': language,
      if (near != null) 'location': near.asParam,
      if (near != null) 'radius': '50000',
    });
    return parseSearchResults(body);
  }

  /// Full details (rating, website, hours) for a place id.
  Future<PlaceDetails?> fetchDetails(
    String placeId, {
    String language = 'en',
  }) async {
    final body = await _get('/maps/api/place/details/json', {
      'place_id': placeId,
      'language': language,
      'fields':
          'place_id,name,formatted_address,geometry,rating,user_ratings_total,types,website,opening_hours',
    });
    final result = body['result'] as Map<String, dynamic>?;
    if (result == null) return null;
    return PlaceDetails.fromJson(result);
  }

  // -- pure parsers (unit-tested, no network) -----------------------------

  static List<PlacePrediction> parsePredictions(Map<String, dynamic> body) {
    final list = (body['predictions'] as List?) ?? [];
    return list
        .map((e) =>
            PlacePrediction.fromJson(e as Map<String, dynamic>))
        .where((p) => p.placeId.isNotEmpty)
        .toList();
  }

  static List<PlaceDetails> parseSearchResults(Map<String, dynamic> body) {
    final list = (body['results'] as List?) ?? [];
    return list
        .map((e) => PlaceDetails.fromJson(e as Map<String, dynamic>))
        .where((p) => p.name.isNotEmpty)
        .toList();
  }
}
