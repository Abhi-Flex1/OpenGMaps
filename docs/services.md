# Services reference

All Google REST clients take the key from `--dart-define` by default, accept
an explicit `apiKey:` for tests/flavors, throw `MissingGoogleMapsKey`
without one, and throw `GoogleMapsApiException(status, message)` on Google
errors (`REQUEST_DENIED`, `ZERO_RESULTS`, `OVER_QUERY_LIMIT`, …).
Timeouts are 8–15 s. Device clients degrade gracefully (memory fallback /
nulls, never exceptions to the UI layer).

## `google_places_service.dart` — Places API

Endpoints: `Autocomplete /maps/api/place/autocomplete/json`, Text Search
`/maps/api/place/textsearch/json`, Details
`/maps/api/place/details/json` (all `maps.googleapis.com`, `key` param).

| Method | Purpose |
|--------|---------|
| `autocomplete(input, {near, language})` | Type-ahead → `PlacePrediction{placeId, description, mainText, secondaryText}` (biased 50 km around `near`) |
| `searchText(query, {near, language})` | Free text → `List<PlaceDetails>` (name, address, coords, rating, count, types) |
| `fetchDetails(placeId, {language})` | Full card → `PlaceDetails` (+ website, `openNow`) |
| `parsePredictions / parseSearchResults` | Pure JSON parsers — unit-tested, no network |

## `google_geocoding_service.dart` — Geocoding API

`GET /maps/api/geocode/json` with `latlng=` (reverse) or `address=`
(forward) → `GeocodedAddress{formatted, latLng, placeId, types}`.
`reverse()` powers map taps; empty list means "Google knows nothing here"
and the app shows the coordinates fallback. Pure `parseResults` tested.

## `google_directions_service.dart` — Directions API

`GET /maps/api/directions/json?origin=&destination=&mode=&language=en` →
`DirectionRoute{points (decoded overview polyline), distanceText/Meters,
durationText/Meters, start/endAddress, start/endLatLng, steps[]}` with
HTML instructions stripped. `ZERO_RESULTS`/`NOT_FOUND` → `null` (not an
exception); other failures throw. `TravelMode{driving,walking,bicycling,
transit}` (`.label`, `.apiValue`).

`universalUrl(origin, destination, mode)` builds the official keyless
`https://www.google.com/maps/dir/?api=1…` turn-by-turn link opened in the
in-app WebView sheet. Polyline encode/decode lives in
`lib/src/maps/polyline_codec.dart` (reference-vector tested).

## `location_service.dart` — device location

Singleton `ChangeNotifier` over `io.opengmaps/location` (see
[`native-ohos.md`](native-ohos.md)):

- `initLiveLocation()` — check → request permission → Location Kit fix;
  concurrent callers share the in-flight future; never throws (surfaces
  `locationError` instead).
- `ensurePermission()`, `permission` (`unknown/granted/denied`),
  `currentLocation`, `accuracyMeters`, `currentBearing`, `isLocating`.
- `startTracking()/stopTracking()` — 8 s fix polling for navigation-style
  updates. `setUserLocation()` — manual override (debug/tests).
- Deliberately **no IP fallback**: an IP address is not a device fix.

## `saved_places_service.dart` — pins + recents (persisted)

`SavedPin{name, address, latLng, placeId}` (`fromDetails`/`fromJson`/
`toJson`, stable `id`). `toggle()`, `isSaved()`, `addSearch()` (cap 8).
`init()` rehydrates from `PreferencesStorage` (`saved_pins_v1`,
`recent_searches_v1`); every mutation re-persists best-effort. Corrupt
entries are skipped, a corrupt store starts clean.

## `storage_service.dart` — preferences channel client

`PreferencesStorage.instance.{getString,setString,remove}` over
`io.opengmaps/storage`. First `MissingPluginException` flips it to an
in-memory map permanently — tests and non-OHOS hosts just work.

## `google_maps_config.dart` — key plumbing

`GoogleMapsConfig.apiKey` (the define), `hasKey`, `ensureKey()`,
`MissingGoogleMapsKey`, `GoogleMapsApiException`. The app gates keyed
calls behind `hasKey` for UI state and lets services throw for logic.
`lib/src/utils/geo.dart` adds `LatLng.asParam` (`"lat,lng"`) for REST
params.
