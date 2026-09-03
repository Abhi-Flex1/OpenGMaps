# Testing

## Unit + widget tests (no device, no key)

```bash
# App (13 tests): smoke, codec, REST parsers, storage, saved logic, URLs
fvm flutter test

# Backport (21 tests): registration, camera/options/overlay translation,
# style validation, event routing, icon resolving, headless platform wiring
cd packages/google_maps_flutter_ohos && fvm flutter test
```

Design rules: everything network- or JS-shaped is tested through **pure
parsers/builders** (`parsePredictions`, `parseRoute`, `ohosCameraOp`,
`ohosMapOptions`, …) and **headless sessions** (the bridge queues JS with
no WebView, so `updateMarkers`/camera/overlay calls run in `flutter
test`). No test needs a key, a device, or the network; without a key the
map widget renders the key-required view instead of a WebView, keeping
widget tests hermetic. Native channels (`location`, `storage`) fall back
to memory/denied on `MissingPluginException`.

```bash
fvm flutter analyze                                  # must be clean
cd packages/google_maps_flutter_ohos && fvm flutter analyze  # one expected warning (git dep, publish-only)
```

## On-device verification playbook (what maintainers actually ran)

Target: OpenHarmony 5.0.1 (API 13) emulator via `hdc`. All commands from
the repo root.

```bash
hdc list targets -v                      # find the device
fvm flutter build hap --debug [--dart-define=GOOGLE_MAPS_API_KEY=...]
hdc install ohos/entry/build/default/outputs/default/entry-default-signed.hap
hdc shell aa start -a EntryAbility -b io.opengmaps.open_gmaps
hdc shell "ps -ef | grep -i gmaps"       # process alive?
hdc shell "hilog -x | grep -E 'io.opengmaps/(storage|location)'"   # channels live?
hdc shell "hilog -x | grep -iE 'STORAGE_ERROR|Unhandled|FATAL'"     # should be empty
hdc shell "snapshot_display -f /data/local/tmp/x.jpeg"             # screenshot…
hdc file recv /data/local/tmp/x.jpeg /tmp/x.jpeg                   # …to your Mac
```

Remote UI interaction (granting the location dialog, etc.):

```bash
hdc shell "uitest dumpLayout -p /data/local/tmp/l.json"  # inspect…
hdc file recv /data/local/tmp/l.json /tmp/l.json
hdc shell "uitest uiInput click 660 1850"                 # …tap by coordinates
```

(`screencap` doesn't exist on OHOS — use `snapshot_display -f ….jpeg`.
`flutter run` may hang silently — prefer the HAP flow above.)

## Verification matrix (honest)

| Check | Result | Evidence |
|-------|--------|----------|
| Launch + first frame | ✅ | hilog `onFirstFrame`, process alive |
| Location permission dialog with our reason string | ✅ | screenshot; granted remotely via `uitest` |
| Location + storage channel traffic | ✅ | hilog `io.opengmaps/*` messages |
| WebView ↔ Dart bridge traffic | ✅ | `flutter_inappwebview_*` channel messages |
| Google auth-failure path (invalid key) | ✅ | Google's error page + red in-app banner, screenshot |
| Key-required state (no key) | ✅ | screenshot |
| Zero Dart errors across all runs | ✅ | hilog greps |
| Live search/details/routes/tiles with a valid key | ⏳ | Implemented + fixture-tested; run the playbook with `--dart-define` and walk [`user-guide.md`](user-guide.md) |

## When you get a key: acceptance walk

1. Map renders Paris (default camera) → pinch/drag works.
2. Search "Eiffel Tower" → predictions → card with rating/website.
3. Tap a museum/restaurant **icon** → its card (POI path), not coordinates.
4. Go tab: current location → "Louvre" → route polyline + summary + steps.
5. Save the place → kill app → relaunch → still in Saved.
6. Layers → satellite/hybrid/terrain all render.
7. My-location button recenters on the blue dot.
