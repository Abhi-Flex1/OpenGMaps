# API keys — from Google Cloud to a working map

One key unlocks all four Google surfaces this project uses. It is always
supplied **out-of-band** (build flag or in-code override) and **never
committed** — the repo contains no keys, and tests assert the no-key state.

## 1. Which APIs to enable

In [Google Cloud Console](https://console.cloud.google.com/) → your
project → **APIs & Services → Enable APIs**:

| API (exact console name) | Used by | Without it |
|--------------------------|---------|------------|
| **Maps JavaScript API** | Map tiles/rendering in the OHOS WebView | Map shows Google's auth-error page + red in-app banner |
| **Places API** | Autocomplete, text search, place details | Search finds nothing; POI taps fall back to coordinates |
| **Geocoding API** | Map-tap reverse lookup, address search | Taps show raw coordinates only |
| **Directions API** | Routes, distances, durations, steps | "Google found no route" |

You also need **billing enabled** on the project (Google requires it for
Maps Platform; a recurring free-use credit applies — check Google's
current terms for amounts). Without billing, calls fail even with the
right APIs enabled.

## 2. Create the key

1. **APIs & Services → Credentials → Create credentials → API key.** Copy it.
2. (Recommended) **Restrict the key**: under *API restrictions* select the
   four APIs above, so a leaked key can't be spent on other services.
   Notes for this stack:
   - *Application restrictions* are awkward here: the map runs in an OHOS
     WebView (no stable HTTP referrer) and REST calls come from the
     device's own (often dynamic) IP. For development, API restrictions
     alone are the practical control; for production, prefer a backend
     proxy for the REST calls and rotate keys.
3. Set **budgets/alerts** (Billing → Budgets) so a runaway device fleet
   can't surprise you.

Key hygiene in this repo:

- Pass it only via `--dart-define=GOOGLE_MAPS_API_KEY=…` (run/build) or
  `GoogleMapsFlutterOhos.apiKeyOverride` (see §4).
- `git diff --cached | grep -iE "AIza"` should always print nothing — the
  test suite covers the no-key UX, so CI never needs a real key.

## 3. Use the key

```bash
# Run with everything unlocked:
fvm flutter run -d <ohos-device> --dart-define=GOOGLE_MAPS_API_KEY=YOUR_KEY

# Build a keyed debug HAP:
fvm flutter build hap --debug --dart-define=GOOGLE_MAPS_API_KEY=YOUR_KEY

# Release:
fvm flutter build hap --release --dart-define=GOOGLE_MAPS_API_KEY=YOUR_KEY
```

Different keys per environment (dev/staging/prod) is just different
`--dart-define` values in your lanes — no code changes, ever.

## 4. Alternatives to `--dart-define`

- **In code (flavors, demos):** set before `runApp` in `lib/main.dart` —
  `GoogleMapsFlutterOhos.apiKeyOverride = '…';` feeds the map; the REST
  services read the same define through `GoogleMapsConfig.apiKey`. (Don't
  commit a real value; use it for local flavors only.)
- **Per-service injection:** every service (`GooglePlacesService`,
  `GoogleGeocodingService`, `GoogleDirectionsService`) accepts an explicit
  `apiKey:` constructor parameter — handy for tests and multi-key setups.
  Their `…instance` singletons use the build define.

## 5. Failure modes (what you'll actually see)

| Situation | Map | Search / directions |
|-----------|-----|---------------------|
| No key at all | Key-required card (screenshot-verified) | Snackbar: *"Set GOOGLE_MAPS_API_KEY via --dart-define…"* |
| Invalid / unauthorized key | Google's auth-error page in the map + red banner (tap dismisses; screenshot-verified on device) | `GoogleMapsApiException(REQUEST_DENIED…)` surfaced in UI |
| API not enabled / no billing | Same auth-error surface | `REQUEST_DENIED` with Google's `error_message` |
| Zero results / no route | Map unaffected | Friendly empty states ("Google found nothing…") |
| No network | WebView error surface + banner | Timeouts (8–15 s) → snackbar |

All error types are unit-tested (`test/widget_test.dart`,
`packages/google_maps_flutter_ohos/test/google_maps_flutter_ohos_test.dart`).

## 6. FAQ

**One key or four?** One key with all four APIs enabled is the supported
setup. Separate keys per surface also work (see §4) but gain you nothing
unless you're isolating spend.

**Do I need Maps SDK for Android / iOS too?** Only if you revive those
shells — this project is OHOS-only and never touches them.

**Can I restrict the key to my app?** Not reliably on OHOS (no GMS app
identity to attest). Use API restrictions + budgets, and a server proxy
for production REST traffic.
