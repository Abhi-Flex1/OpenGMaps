# Backport reference — `google_maps_flutter_ohos`

`packages/google_maps_flutter_ohos/` implements `GoogleMapsFlutterPlatform`
(platform interface `2.12–2.13`, app-facing `2.12.3`) on the Maps
JavaScript API in the native OHOS WebView. 21 unit tests live in
`packages/google_maps_flutter_ohos/test/`.

## Use it (your own app or this one)

```dart
import 'package:google_maps_flutter_ohos/google_maps_flutter_ohos.dart';

void main() {
  GoogleMapsFlutterOhos.register(); // before runApp
  runApp(const MyApp());
}
```

Then use the stock API unchanged (`GoogleMap`, `GoogleMapController`,
`Marker`, `Polyline`, `CameraUpdate`, …). The key comes from
`--dart-define=GOOGLE_MAPS_API_KEY=…`, or set
`GoogleMapsFlutterOhos.apiKeyOverride` before `runApp`.

## Coverage

Everything below is implemented and bridged; only the noted gaps remain.

| Surface | Status |
|---------|--------|
| All 9 `CameraUpdate` kinds (+ `animateCameraWithConfiguration` durations) | ✅ |
| `MapType` normal/satellite/hybrid/terrain/**none** (none = hide-everything style) | ✅ |
| Markers: hue pins, byte/asset icons, `PinConfig`, anchor, alpha, z-index, visibility, draggable + drag events, info windows + tap, show/hide/query | ✅ |
| `AdvancedMarker` (`markerType: advancedMarker`, `AdvancedMarkerElement`/`PinElement`) | ✅ best-effort (`isAdvancedMarkersAvailable` ⇔ cloud map ID set) |
| Polylines (color/width/geodesic/z-index, dash/gap/dot patterns, tap gating via `consumeTapEvents`) | ✅ |
| Polygons (+ holes), circles, heatmaps (gradient sampling, zoom gating) | ✅ |
| Tile overlays (live Dart `TileProvider` fetch, cache, fade-in, `clearTileCache`) | ✅ |
| Ground overlays (bounds or position+size, transparency, click) | ✅ |
| Clustering (`ClusterManager`, member taps, cluster tap with bounds + ids) | ✅ (needs markerclusterer CDN; offline → unclustered) |
| Styling (`GoogleMap.style`, `setMapStyle`, `getStyleError`, `MapStyleException`) | ✅ |
| Gestures/controls mapping, camera bounds restriction, zoom limits, traffic, 45° imagery | ✅ |
| Projections (`getVisibleRegion`, `getScreenCoordinate`, `getLatLng`, `getZoomLevel`) | ✅ |
| All 15 stock event streams | ✅ |
| **POI taps** (`OhosPoiTap{placeId, position}`, poi-only like native SDKs) | ✅ extension |
| My-location dot + recenter button via `io.opengmaps/location` | ✅ (quietly off without that host channel) |
| `takeSnapshot()` | ➖ returns `null` (JS exposes none; contract allows it) |
| Compass, map toolbar, lite mode, padding, indoor view, 3D buildings, marker rotation/flat, caps/joint types | ➖ no JS equivalent, ignored |

## Files (paths relative to `packages/google_maps_flutter_ohos/`)

| File | Role |
|------|------|
| `lib/google_maps_flutter_ohos.dart` | Barrel: platform class + `OhosPoiTap` |
| `lib/src/google_maps_flutter_ohos.dart` | The platform implementation (all overrides, sessions registry) |
| `lib/src/ohos_map_view.dart` | `InAppWebView` host, key-required view, error banner, location button |
| `lib/src/map_bridge.dart` | `OhosMapSession`: eval queue, `REQ` correlation, tile serving, typed streams, `OhosPoiTap` |
| `lib/src/map_html.dart` | The `OhosMaps` JS bootstrap + full protocol (~700 lines JS) |
| `lib/src/icon_resolver.dart` | Every `BitmapDescriptor` kind → bridge payload (never throws) |
| `lib/src/translation.dart` | Pure camera/options/overlay mappers (heavily unit-tested) |

## Notes for reusers and publishers

- **Consumption**: path/git dependency + explicit `register()`. The package
  intentionally omits the federated `flutter.plugin` block: the OHOS
  flutter tool crashes resolving Dart-only `ohos` plugins and injects a
  phantom native HAR dependency (documented in the pubspec and in
  [`troubleshooting.md`](troubleshooting.md)). Re-add the block when
  publishing alongside a native shell.
- **My-location dependency**: the dot/button call
  `io.opengmaps/location → getCurrentLocation`. Provide that channel in
  your host (copy `EntryAbility.ets`) or the layer stays off — no crash.
- **Key plumbing**: `GoogleMapsFlutterOhos.apiKeyOverride` →
  `--dart-define=GOOGLE_MAPS_API_KEY` fallback → key-required view.
  Without a key the widget never creates the WebView (safe in tests).
- **Tests run headless**: sessions queue JS with no `WebViewController`,
  so `updateMarkers`/camera/overlay calls are all exercisable in
  `flutter test` (see the "platform wiring" tests).
