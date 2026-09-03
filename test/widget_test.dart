import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_maps_flutter_ohos/google_maps_flutter_ohos.dart';
import 'package:open_gmaps/main.dart';
import 'package:open_gmaps/src/config/google_maps_config.dart';
import 'package:open_gmaps/src/maps/polyline_codec.dart';
import 'package:open_gmaps/src/services/google_directions_service.dart';
import 'package:open_gmaps/src/services/google_geocoding_service.dart';
import 'package:open_gmaps/src/services/google_places_service.dart';
import 'package:open_gmaps/src/services/saved_places_service.dart';
import 'package:open_gmaps/src/services/storage_service.dart';
import 'package:open_gmaps/src/widgets/google_brand_icons.dart';

void main() {
  setUp(() {
    GoogleMapsFlutterOhos.register();
  });

  testWidgets('Stock GoogleMap widget builds on OHOS', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: GoogleMap(
          initialCameraPosition: CameraPosition(
            target: LatLng(48.85837, 2.29448),
            zoom: 12,
          ),
        ),
      ),
    ));
    await tester.pump();

    // No --dart-define in tests: honest key-required state, never a fake map.
    expect(find.text('Google Maps API key required'), findsOneWidget);
  });

  testWidgets('Google Platform app smoke test (no key in tests)', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const OpenGMapsApp());
    await tester.pump();

    expect(find.byType(GoogleGLogo), findsOneWidget);
    expect(find.text('Search Google'), findsOneWidget);
    expect(find.text('Explore'), findsOneWidget);
    expect(find.text('Go'), findsOneWidget);
    expect(find.text('Saved'), findsOneWidget);
    expect(find.text('Google Maps API key required'), findsWidgets);
  });

  test('Polyline codec decodes the reference example', () {
    // Reference from the Google polyline algorithm docs.
    const String encoded = '_p~iF~ps|U_ulLnnqC_mqNvxq`@';
    final List<LatLng> pts = PolylineCodec.decode(encoded);
    expect(pts, hasLength(3));
    expect(pts[0].latitude, closeTo(38.5, 1e-5));
    expect(pts[0].longitude, closeTo(-120.2, 1e-5));
    expect(pts[1].latitude, closeTo(40.7, 1e-5));
    expect(pts[1].longitude, closeTo(-120.95, 1e-5));
    expect(pts[2].latitude, closeTo(43.252, 1e-5));
    expect(pts[2].longitude, closeTo(-126.453, 1e-5));
  });

  test('Polyline codec round-trips', () {
    const List<LatLng> pts = [
      LatLng(48.85837, 2.29448),
      LatLng(48.86061, 2.33764),
    ];
    final List<LatLng> decoded =
        PolylineCodec.decode(PolylineCodec.encode(pts));
    expect(decoded, hasLength(2));
    expect(decoded[0].latitude, closeTo(48.85837, 1e-5));
    expect(decoded[1].longitude, closeTo(2.33764, 1e-5));
  });

  test('Parses Places autocomplete predictions', () {
    final List<PlacePrediction> preds =
        GooglePlacesService.parsePredictions({
      'status': 'OK',
      'predictions': [
        {
          'place_id': 'ChIJLU7jZClu5kcR4PcOOO6p3I0',
          'description': 'Eiffel Tower, Paris, France',
          'structured_formatting': {
            'main_text': 'Eiffel Tower',
            'secondary_text': 'Paris, France',
          },
        },
      ],
    });
    expect(preds, hasLength(1));
    expect(preds.first.placeId, startsWith('ChIJ'));
    expect(preds.first.mainText, 'Eiffel Tower');
  });

  test('Parses Places text-search results', () {
    final List<PlaceDetails> hits =
        GooglePlacesService.parseSearchResults({
      'status': 'OK',
      'results': [
        {
          'place_id': 'ChIJLU7jZClu5kcR4PcOOO6p3I0',
          'name': 'Eiffel Tower',
          'formatted_address': 'Av. Gustave Eiffel, 75007 Paris, France',
          'geometry': {
            'location': {'lat': 48.85837, 'lng': 2.29448},
          },
          'rating': 4.7,
          'user_ratings_total': 494891,
          'types': ['tourist_attraction'],
        },
      ],
    });
    expect(hits, hasLength(1));
    expect(hits.first.name, 'Eiffel Tower');
    expect(hits.first.latLng.latitude, closeTo(48.85837, 1e-5));
    expect(hits.first.rating, closeTo(4.7, 1e-9));
  });

  test('Parses geocoding results', () {
    final List<GeocodedAddress> hits =
        GoogleGeocodingService.parseResults({
      'status': 'OK',
      'results': [
        {
          'formatted_address': 'Eiffel Tower, Paris, France',
          'place_id': 'ChIJLU7jZClu5kcR4PcOOO6p3I0',
          'geometry': {
            'location': {'lat': 48.85837, 'lng': 2.29448},
          },
          'types': ['tourist_attraction'],
        },
      ],
    });
    expect(hits, hasLength(1));
    expect(hits.first.formatted, contains('Eiffel'));
  });

  test('Parses Directions route + decodes polyline', () {
    final String points = PolylineCodec.encode(const [
      LatLng(48.85837, 2.29448),
      LatLng(48.86061, 2.33764),
    ]);
    final DirectionRoute? route = GoogleDirectionsService.parseRoute({
      'status': 'OK',
      'routes': [
        {
          'overview_polyline': {'points': points},
          'legs': [
            {
              'distance': {'text': '4.1 km', 'value': 4100},
              'duration': {'text': '15 mins', 'value': 900},
              'start_address': 'Eiffel Tower',
              'end_address': 'Louvre Museum',
              'start_location': {'lat': 48.85837, 'lng': 2.29448},
              'end_location': {'lat': 48.86061, 'lng': 2.33764},
              'steps': [
                {
                  'html_instructions': 'Head <b>north</b>',
                  'distance': {'text': '200 m'},
                  'maneuver': 'straight',
                },
              ],
            },
          ],
        },
      ],
    });
    expect(route, isNotNull);
    expect(route!.points, hasLength(2));
    expect(route.distanceText, '4.1 km');
    expect(route.steps.first.instruction, 'Head north');
  });

  test('Directions failures surface typed status', () {
    expect(
      () => GoogleDirectionsService.parseRoute({
        'status': 'REQUEST_DENIED',
        'error_message': 'API key not valid.',
      }),
      throwsA(isA<GoogleMapsApiException>().having(
          (GoogleMapsApiException e) => e.status, 'status', 'REQUEST_DENIED')),
    );
    expect(
      GoogleDirectionsService.parseRoute({'status': 'ZERO_RESULTS'}),
      isNull,
    );
  });

  test('Navigate URL is the official universal link', () {
    final String url = GoogleDirectionsService.universalUrl(
      'Paris',
      'Lyon',
      TravelMode.driving,
    );
    expect(url, contains('google.com/maps/dir/'));
    expect(url, contains('travelmode=driving'));
    expect(url, isNot(contains('key=')));
  });

  test('Saved pins round-trip through JSON storage form', () {
    const SavedPin pin = SavedPin(
      name: 'Eiffel Tower',
      address: 'Av. Gustave Eiffel, Paris',
      latLng: LatLng(48.85837, 2.29448),
      placeId: 'ChIJLU7jZClu5kcR4PcOOO6p3I0',
    );
    final SavedPin back =
        SavedPin.fromJson(Map<String, dynamic>.from(pin.toJson()));
    expect(back.id, pin.id);
    expect(back.name, 'Eiffel Tower');
    expect(back.latLng.latitude, closeTo(48.85837, 1e-9));
    expect(back.placeId, startsWith('ChIJ'));
  });

  test('Storage falls back to memory without a native host', () async {
    const String key = 'test_probe_${12345}';
    await PreferencesStorage.instance.setString(key, 'v1');
    expect(await PreferencesStorage.instance.getString(key), 'v1');
    await PreferencesStorage.instance.remove(key);
    expect(await PreferencesStorage.instance.getString(key), isNull);
  });

  test('Saved service toggles and caps recent searches', () {
    final SavedPlacesService svc = SavedPlacesService.instance;
    const SavedPin pin = SavedPin(
      name: 'Probe Place 12345',
      address: 'Nowhere',
      latLng: LatLng(1, 2),
    );
    if (svc.isSaved(pin)) svc.toggle(pin);
    expect(svc.isSaved(pin), isFalse);
    svc.toggle(pin);
    expect(svc.isSaved(pin), isTrue);
    svc.toggle(pin);
    expect(svc.isSaved(pin), isFalse);

    for (var i = 0; i < 10; i++) {
      svc.addSearch('probe q $i');
    }
    expect(svc.recentSearches, hasLength(8));
    expect(svc.recentSearches.first, 'probe q 9');
  });
}
