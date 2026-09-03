/// OpenHarmony (OHOS) implementation of `google_maps_flutter`.
///
/// Registers [GoogleMapsFlutterOhos] as the [GoogleMapsFlutterPlatform]
/// instance, so the stock `GoogleMap` widget and `GoogleMapController`
/// work on OHOS. Rendering is the official Maps JavaScript API inside the
/// native OHOS WebView (there is no GMS Maps SDK binary for OpenHarmony).
///
/// ```dart
/// import 'package:google_maps_flutter_ohos/google_maps_flutter_ohos.dart';
///
/// void main() {
///   GoogleMapsFlutterOhos.register();
///   runApp(const MyApp());
/// }
/// ```
///
/// The API key is read from `--dart-define=GOOGLE_MAPS_API_KEY`, or set
/// explicitly via [GoogleMapsFlutterOhos.apiKeyOverride] before `runApp`.
library google_maps_flutter_ohos;

export 'src/google_maps_flutter_ohos.dart';
export 'src/map_bridge.dart' show OhosPoiTap;
