# User guide — using the app

Needs a key for anything Google-flavored
(`--dart-define=GOOGLE_MAPS_API_KEY=…`, see [`api-keys.md`](api-keys.md));
without one the map area explains itself and everything else still opens.

## Explore tab (default)

- **Search bar**: type (predictions appear as you type, powered by Places
  Autocomplete) or submit (full text search). The map jumps to the top hit
  with a marker; a bottom sheet shows the place card — name, category,
  rating stars + review count, address, coordinates, website, open status.
- **Tap the map**: reverse-resolves the spot. Named places open their card
  (Details fetched by `placeId` when available); empty land/water shows a
  coordinates sheet that says "No named place found here".
- **Tap a place icon** (restaurant, museum, hotel…): opens that place's
  full card directly — this uses the Google `placeId`, not coordinates.
- **Layers button** (right side): Default / Satellite / Hybrid / Terrain.
- **Directions** (in any place sheet): fills the Go tab and switches to it.
- **Save / Saved**: bookmark the place; it persists across restarts.
- **Close (×)**: clears the selection and its marker.

## Go tab (directions)

1. Origin (blank = your live location), destination, travel mode
   (Driving/Walking/Cycling/Transit).
2. **Show route**: draws the official route polyline with origin/destination
   markers, fits the camera to it, and shows distance, duration, both
   addresses and turn-by-turn steps.
3. **Navigate in Google Maps**: opens the universal directions URL in a
   full-height sheet for live guidance.

Failures are explicit: unknown places → "Google found no route"; no key →
a prompt to set one; API errors → Google's status text.

## Saved tab

Bookmarked places (tap to revisit, × to remove) plus the last 8 recent
searches (tap to re-run). Both survive restarts via OHOS preferences.

## My location

The blue dot (when location is available) and the floating recenter button
come from the native Location Kit flow: first launch shows the system
permission dialog with the app's reason string; denying just disables
location features, never the app. Origin-blank directions will ask you to
wait for (or grant) location first.

## Banners and empty states (by design)

- Yellow banner + map card → no API key configured.
- Red banner (tap to dismiss) → Google rejected the map load (bad key,
  disabled API, no billing) — details in the message.
- Snackbars → search/directions failures with Google's reason.
- Coordinates sheet → "No named place found here" where Google knows nothing.
