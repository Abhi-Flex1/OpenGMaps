/// Build-time configuration for the official Google Maps Platform stack.
///
/// The API key is **never** committed. Supply it out-of-band:
///
/// ```bash
/// fvm flutter run -d <ohos-device> --dart-define=GOOGLE_MAPS_API_KEY=YOUR_KEY
/// fvm flutter build hap --debug --dart-define=GOOGLE_MAPS_API_KEY=YOUR_KEY
/// ```
///
/// Enable in Google Cloud for the owning project: Maps JavaScript API,
/// Places API, Geocoding API, Directions API (all with billing).
library;

/// API key injected at build/run time via `--dart-define`.
class GoogleMapsConfig {
  GoogleMapsConfig._();

  /// Google Cloud API key. Empty when no `--dart-define` was passed.
  static const String apiKey = String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY',
    defaultValue: '',
  );

  /// True once a key was supplied.
  static bool get hasKey => apiKey.isNotEmpty;

  /// Maps JavaScript API bootstrap URL (weekly channel + places/geometry).
  static String get mapsJsUrl =>
      'https://maps.googleapis.com/maps/api/js'
      '?key=$apiKey&libraries=places,geometry&v=weekly&callback=__ogmInit';

  /// Throws [MissingGoogleMapsKey] when no key is configured.
  static void ensureKey() {
    if (!hasKey) throw const MissingGoogleMapsKey();
  }
}

/// Thrown when a keyed Google Maps Platform call is attempted without a key.
class MissingGoogleMapsKey implements Exception {
  const MissingGoogleMapsKey();
  @override
  String toString() =>
      'MissingGoogleMapsKey: pass --dart-define=GOOGLE_MAPS_API_KEY=YOUR_KEY';
}

/// Typed failure from a Google Maps Platform REST call.
class GoogleMapsApiException implements Exception {
  const GoogleMapsApiException(this.status, [this.message = '']);

  /// Google `status` field, e.g. REQUEST_DENIED, ZERO_RESULTS.
  final String status;
  final String message;

  @override
  String toString() =>
      'GoogleMapsApiException($status${message.isEmpty ? '' : ': $message'})';
}
