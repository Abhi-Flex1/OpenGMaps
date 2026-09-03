# google_maps_flutter_ohos

OpenHarmony (OHOS) implementation of
[`google_maps_flutter`](https://pub.dev/packages/google_maps_flutter)
(aligned with app-facing `2.12.3` / platform interface `2.12–2.13`).

There is no GMS Maps SDK binary for OpenHarmony, so this implementation
renders the official **Maps JavaScript API** inside the native OHOS WebView
(`flutter_inappwebview`) and translates the whole stock plugin surface to
it: camera updates, markers (custom icons, info windows, dragging,
clustering), polylines, polygons, circles, heatmaps, tile overlays (tiles
pulled from Dart `TileProvider`s), ground overlays, map styling, all map
types, gestures, projections and every map event stream.

## Use

```dart
import 'package:google_maps_flutter_ohos/google_maps_flutter_ohos.dart';

void main() {
  GoogleMapsFlutterOhos.register();
  runApp(const MyApp());
}
```

Then use the stock API unchanged:

```dart
GoogleMap(
  initialCameraPosition: const CameraPosition(
    target: LatLng(48.85837, 2.29448),
    zoom: 12,
  ),
  markers: {Marker(markerId: MarkerId('eiffel'), position: LatLng(...))},
  onMapCreated: (controller) => _controller.complete(controller),
)
```

## Place-icon (POI) taps

The stock plugin drops place-icon taps. Like the native SDKs, this
implementation reports them separately — without also firing the plain
map-tap stream:

```dart
GoogleMapsFlutterOhos.poiTaps(controller.mapId).listen((tap) async {
  final details = await places.fetchDetails(tap.placeId);
  // ... show the place card at tap.position
});
```

## API key

Set it before `runApp`, or pass `--dart-define=GOOGLE_MAPS_API_KEY=…`:

```dart
GoogleMapsFlutterOhos.apiKeyOverride = 'YOUR_KEY';
```

Enable **Maps JavaScript API** (plus Places/Geocoding/Directions if you use
the REST clients) in Google Cloud. Without a key the map shows an honest
key-required state instead of a misleading third-party map.

## My-location layer

`myLocationEnabled` / `myLocationButtonEnabled` are served through the
`io.opengmaps/location` method channel (`getCurrentLocation`, OHOS
Location Kit). Hosts without that channel simply keep the layer off.

## Platform notes / gaps

- `takeSnapshot()` returns `null` (the JS API exposes no raster snapshot).
- `liteModeEnabled`, `mapToolbarEnabled`, compass, `padding`, indoor view,
  3D buildings and marker `rotation`/`flat` have no JS equivalent and are
  ignored.
- `scrollBy`/`zoomBy` focus handling, dashed patterns and heatmap zoom
  gating are best-effort approximations of native behavior.
- Cluster rendering needs network access to the markerclusterer CDN;
  without it, clustered markers render unclustered.
