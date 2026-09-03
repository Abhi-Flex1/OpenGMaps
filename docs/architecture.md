# Architecture

## Big picture

Google ships no Maps SDK for OpenHarmony, and `google_maps_flutter` has
no OHOS platform implementation. So this project keeps the **stock**
`google_maps_flutter` Dart API untouched and implements its platform
interface on the only official Google surface that runs on OHOS: the
**Maps JavaScript API** inside the native OHOS WebView (ArkWeb).

```
┌──────────────────────── Flutter (Dart) ────────────────────────┐
│                                                                │
│  lib/main.dart ── stock GoogleMap / GoogleMapController,       │
│                   Marker, Polyline, CameraUpdate …             │
│                         │                                      │
│  packages/google_maps_flutter_ohos                             │
│   ├─ GoogleMapsFlutterOhos (platform interface impl)           │
│   ├─ translation.dart ─ CameraUpdate / MapConfiguration /      │
│   │                     overlays → JSON payloads                │
│   ├─ icon_resolver.dart ─ BitmapDescriptor → data-URL icons    │
│   ├─ map_bridge.dart ── per-map sessions, event streams,       │
│   │                     request/response, tile fetching        │
│   └─ ohos_map_view.dart ─ InAppWebView host + error banner +   │
│                           my-location button                   │
│                         │ evaluateJavascript                   │
│                         │ addJavaScriptHandler                 │
│  flutter_inappwebview (OHOS SIG, native ArkWeb view)           │
│                         │                                      │
│  map_html.dart ── window.OhosMaps JS bridge                    │
│   └─ google.maps.Map + markers/polylines/polygons/circles/     │
│      heatmaps/tile overlays/ground overlays/clusters,          │
│      info windows, camera tweens, long-press synthesis         │
└──────────────────────────────────────────────────────────────┘
                         │ HTTPS (keyed REST, --dart-define key)
                         ▼
   Places API · Geocoding API · Directions API ── lib/src/services/
   (Autocomplete/Text/Details, reverse+forward, routes+polylines)

Method channels to ArkTS cover only what JS cannot do:
   io.opengmaps/location ── permission + Location Kit fixes
   io.opengmaps/storage ── durable string KV (user preferences)
```

## The bridge protocol

Two directions, both JSON:

**Dart → JS** (`evaluateJavascript`, queued until `ohosReady`):

- `OhosMaps.setOptions({...})` — map type, styles, zoom limits,
  restrictions, controls, gesture policy, traffic, tilt, camera tracking
- `OhosMaps.setMarkers/polylines/polygons/circles/heatmaps/
  tileOverlays/groundOverlays({add, change, remove})`
- `OhosMaps.setClusterManagers([ids])`
- `OhosMaps.moveCamera(op)` / `OhosMaps.animateCamera(op, durationMs)` —
  all 9 `CameraUpdate` kinds, incl. focus-stable `zoomBy` (pure Mercator
  math, no projection races) and eased tweens
- `OhosMaps.showInfoWindow/hideInfoWindow/isInfoWindowShown`,
  `getVisibleRegion/getScreenCoordinate/getLatLng/getZoom/getCamera`
  (request/response with `REQ` correlation ids),
  `setMyLocation`, `clearTileCache`

**JS → Dart** (handlers):

- `ohosReady` — flush queue, apply initial objects, fire
  `onPlatformViewCreated` (this ordering is what makes the stock
  `GoogleMapController.init` work)
- `ohosEvent {type, …}` — `cameraMove(Started)/cameraIdle` (move stream is
  throttled ~120 ms and gated by `trackCameraPosition`), `mapTap`,
  `mapLongPress` (synthesized 550 ms press), `markerTap`,
  `infoWindowTap`, marker drag start/move/end, polyline/polygon/circle/
  ground-overlay taps, `clusterTap` (with member ids + bounds), `poiTap`
  (`placeId` for place-icon taps — an OHOS extension, see below)
- `ohosRequest {id, value|error}` — getter responses
- `ohosTile {overlayId, x, y, zoom, token}` — tile pulls; Dart answers via
  `__ohosTileResponse(token, dataUrl|null)` because `ImageMapType.getTile`
  must return synchronously (placeholder div is filled in async)
- `ohosError` — auth failures (`gm_authFailure`), load failures, init
  timeout → red dismissible banner in the map view

## Key design decisions

1. **Stock API purity.** App code imports only `package:google_maps_flutter`
   (+ services). Every OHOS behavior lives in the backport package, so the
   app would also compile against Android/iOS implementations.
2. **Explicit registration.** `GoogleMapsFlutterOhos.register()` in
   `main()` sets the platform instance (the documented pattern). The
   package is deliberately *not* declared as a federated `flutter.plugin`:
   the OHOS flutter tool crashes on Dart-only plugin declarations and
   injects a bogus native HAR dependency (see
   [`troubleshooting.md`](troubleshooting.md)).
3. **POI taps are separate, like native SDKs.** A place-icon tap emits
   `poiTap` only — never a duplicate map tap — mirroring Android
   `onPoiClick` / iOS `didTapPOI` (the stock Flutter plugin drops these
   everywhere).
4. **No fake data, ever.** No key → key-required card. No fix → no dot, no
   IP-geolocation masquerading as GPS. No place → coordinates fallback
   sheet that says so.
5. **Degrade in layers.** Missing icon bytes → default pin. Dead
   clusterer CDN → unclustered markers. Dead tile → blank tile, not a
   crash. Corrupt persisted pins → skipped entry / clean start.

## Data flows (by feature)

- **Search**: `TextField` → debounce 400 ms → Places Autocomplete →
  predictions dropdown → Details → stock `Marker` + `animateCamera` +
  place sheet. Submit → Text Search → first hit.
- **Map tap**: stock `onTap(LatLng)` → Geocoding reverse → Details by
  `placeId` when available → sheet; empty areas → coordinates sheet.
- **POI tap**: `poiTaps(mapId)` → Details by `placeId` → sheet; Details
  failure → falls back to the map-tap flow at the same coords.
- **Directions**: origin/dest/mode → Directions API → decode
  `overview_polyline` → stock `Polyline` + endpoint markers +
  `newLatLngBounds` fit → summary + steps; Navigate opens the universal
  `google.com/maps/dir/?api=1…` URL in an in-app WebView (keyless,
  official).
- **Saved**: `SavedPin` toggle → memory + `io.opengmaps/storage` persist;
  `init()` rehydrates on launch.
- **My location**: `myLocationEnabled` → Location Kit fix → JS blue dot;
  the recenter button recenters via the platform's own `moveCamera`.

## Where things live (map of maps)

| Layer | Files |
|-------|-------|
| Stock API surface | `google_maps_flutter` 2.12.3 (pub cache, unmodified) |
| Platform contract | `google_maps_flutter_platform_interface` 2.13.0 (unmodified) |
| OHOS implementation | `packages/google_maps_flutter_ohos/lib/src/*.dart` |
| App UI | `lib/main.dart` (~1300 lines: Explore/Go/Saved tabs) |
| REST clients | `lib/src/services/google_{places,geocoding,directions}_service.dart` |
| Device clients | `lib/src/services/{location,saved_places,storage}_service.dart` |
| ArkTS host | `ohos/entry/…/EntryAbility.ets` (128 lines, 2 channels) |
