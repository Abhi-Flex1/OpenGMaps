# OpenGMaps — Google Maps for OpenHarmony

> A complete Google Maps app for OpenHarmony/HarmonyOS, built with Flutter
> on the **stock `google_maps_flutter` widget** (`2.12.3`). Because Google
> ships no Maps SDK binary for OpenHarmony, this repo contains an in-house
> backport — **`packages/google_maps_flutter_ohos`** — that implements the
> official plugin platform interface on top of the **Maps JavaScript API**
> running in the native OHOS WebView, plus keyed **Places / Geocoding /
> Directions** clients and native OHOS Location Kit. **OHOS-only** — the
> Android/iOS shells exist but are unused.

![HarmonyOS](https://img.shields.io/badge/HarmonyOS-NEXT-0A59F7?style=flat-square)
![OpenHarmony](https://img.shields.io/badge/OpenHarmony-5.0_API12--13-00BFFF?style=flat-square)
![Flutter OHOS](https://img.shields.io/badge/Flutter-3.27.4_ohos_(Dart_3.6)-02569B?style=flat-square&logo=flutter)
![google_maps_flutter](https://img.shields.io/badge/google_maps_flutter-2.12.3-4285F4?style=flat-square)
![License](https://img.shields.io/badge/License-Apache_2.0-green?style=flat-square)

---

## Table of Contents

- [1. What you get](#1-what-you-get)
- [2. Quickstart (5 minutes)](#2-quickstart-5-minutes)
- [3. API keys — the one thing you must do](#3-api-keys--the-one-thing-you-must-do)
- [4. Project structure](#4-project-structure)
- [5. Architecture in 60 seconds](#5-architecture-in-60-seconds)
- [6. The OHOS backport (`google_maps_flutter_ohos`)](#6-the-ohos-backport-google_maps_flutter_ohos)
- [7. App user guide](#7-app-user-guide)
- [8. OHOS native layer](#8-ohos-native-layer)
- [9. Testing & verification status](#9-testing--verification-status)
- [10. Troubleshooting (quick hits)](#10-troubleshooting-quick-hits)
- [11. Configuration reference](#11-configuration-reference)
- [12. Roadmap](#12-roadmap)
- [13. Contributing](#13-contributing)
- [14. License & acknowledgements](#14-license--acknowledgements)

**Full guides live in [`docs/`](docs/README.md):**

| Guide | What it covers |
|-------|----------------|
| [`docs/getting-started.md`](docs/getting-started.md) | Toolchain install, first run, emulator + physical devices |
| [`docs/api-keys.md`](docs/api-keys.md) | Creating a key, enabling the 4 APIs, restrictions, billing, wiring it in |
| [`docs/architecture.md`](docs/architecture.md) | System design, bridge protocol, data flows |
| [`docs/backport.md`](docs/backport.md) | Backport API coverage, gaps, POI-tap extension, reuse in your own app |
| [`docs/services.md`](docs/services.md) | Places / Geocoding / Directions / Location / Storage clients |
| [`docs/native-ohos.md`](docs/native-ohos.md) | `EntryAbility` channels, permissions, OHOS project layout |
| [`docs/testing.md`](docs/testing.md) | Unit/widget tests + on-device verification playbook |
| [`docs/troubleshooting.md`](docs/troubleshooting.md) | Every known failure and its fix |
| [`docs/user-guide.md`](docs/user-guide.md) | How to use the app itself |

---

## 1. What you get

- **Real Google Maps on OHOS**: vector tiles, gestures, all 4 map types
  (default / satellite / hybrid / terrain), markers, routes — through the
  stock `GoogleMap` API, no forks in app code.
- **Search that works**: debounced Autocomplete predictions + full-text
  search, powered by the Places API.
- **Place cards**: tap any search result — or any **place icon on the map**
  itself — for name, rating, reviews, hours, website and address.
- **Directions**: origin/destination + driving/walking/cycling/transit,
  route polyline with auto-fit, distance/duration summary, turn steps, and
  one-tap turn-by-turn in Google Maps.
- **Saved places + recent searches**, persisted across restarts in OHOS
  user preferences.
- **My-location dot + recenter button** via native OHOS Location Kit.
- **Honest no-key behavior**: without an API key every surface explains
  what to do — nothing ever renders a fake or mislabeled map.

---

## 2. Quickstart (5 minutes)

Prerequisites: macOS arm64, [FVM](https://fvm.app), the OHOS Flutter SDK
(`ohos` channel) and the OpenHarmony command-line tools. Full install
steps: [`docs/getting-started.md`](docs/getting-started.md).

```bash
git clone https://github.com/Abhi-Flex1/OpenGMaps.git && cd OpenGMaps
fvm use ohos --force
fvm flutter pub get
fvm flutter analyze   # expect: No issues found!
fvm flutter test      # expect: All tests passed!
```

Run on a connected OHOS device/emulator (`hdc list targets` to find it).
The app runs **without** a key (key-required placeholders), and unlocks
fully **with** one (see §3):

```bash
# Without key (UI shell + honest placeholders):
fvm flutter run -d <ohos-device-id>

# With key (everything works):
fvm flutter run -d <ohos-device-id> --dart-define=GOOGLE_MAPS_API_KEY=YOUR_KEY

# Or build a signed HAP and install it manually:
fvm flutter build hap --debug --dart-define=GOOGLE_MAPS_API_KEY=YOUR_KEY
hdc install ohos/entry/build/default/outputs/default/entry-default-signed.hap
hdc shell aa start -a EntryAbility -b io.opengmaps.open_gmaps
```

> `fvm flutter run` can hang silently on some setups waiting for the
> observatory. If it does, use the HAP + `hdc install` + `aa start` flow
> above — it always works. Details in
> [`docs/troubleshooting.md`](docs/troubleshooting.md).

---

## 3. API keys — the one thing you must do

Everything Google-flavored needs one key, supplied **out-of-band** (never
committed) via `--dart-define`:

```bash
--dart-define=GOOGLE_MAPS_API_KEY=YOUR_KEY
```

Step-by-step (Google Cloud project → billing → enable 4 APIs → create and
optionally restrict the key): [`docs/api-keys.md`](docs/api-keys.md).

| Google Cloud API | Used for |
|------------------|----------|
| Maps JavaScript API | Map rendering in the OHOS WebView |
| Places API | Autocomplete, text search, place details |
| Geocoding API | Map-tap reverse lookup, address search |
| Directions API | Routes, distances, durations, steps |

Without a key you get the key-required state (screenshot-verified on
device). With an **invalid** key you get Google's own auth-error page plus
an in-app error banner — both verified on-device.

---

## 4. Project structure

```
.
├── lib/
│   ├── main.dart                     # register() + OpenGMapsApp → HomePage (stock GoogleMap)
│   └── src/
│       ├── config/google_maps_config.dart  # key plumbing, hasKey, typed errors
│       ├── maps/polyline_codec.dart        # overview_polyline decode/encode
│       ├── utils/geo.dart                  # LatLng.asParam helper
│       ├── services/
│       │   ├── google_places_service.dart      # Autocomplete / Text Search / Details
│       │   ├── google_geocoding_service.dart   # reverse (map tap) + forward
│       │   ├── google_directions_service.dart  # routes + TravelMode + Navigate URL
│       │   ├── location_service.dart           # OHOS Location Kit client
│       │   ├── saved_places_service.dart       # pins + recents (persisted)
│       │   └── storage_service.dart            # preferences channel client
│       ├── theme/google_maps_theme.dart    # Google Maps light/dark theme
│       └── widgets/google_brand_icons.dart # G logo, pins, GPS dot painters
├── packages/google_maps_flutter_ohos/  # OHOS backport (see §6)
│   ├── lib/google_maps_flutter_ohos.dart
│   ├── lib/src/{google_maps_flutter_ohos,ohos_map_view,map_bridge,
│   │             map_html,icon_resolver,translation}.dart
│   ├── test/google_maps_flutter_ohos_test.dart  # 21 tests
│   └── {README,CHANGELOG}.md
├── test/widget_test.dart               # 13 app tests
├── ohos/                               # OpenHarmony host app (see §8)
│   ├── AppScope/app.json5              # bundleName io.opengmaps.open_gmaps
│   ├── entry/.../EntryAbility.ets      # FlutterAbility + location/storage channels
│   ├── entry/.../module.json5          # INTERNET + LOCATION permissions
│   ├── build-profile.json5             # API 12 target + signing config
│   └── signatures/                     # signing materials (see §11)
├── docs/                               # full guides (table above)
├── android/ ios/                       # unused shells (OHOS-only project)
└── assets/{images,fonts}/              # G logo art, Google Sans
```

---

## 5. Architecture in 60 seconds

```
┌─ Flutter (Dart) ─────────────────────────────┐
│  GoogleMap (stock 2.12.3 widget)             │
│        │ GoogleMapsFlutterPlatform API       │
│  google_maps_flutter_ohos                    │
│   ├─ translation: CameraUpdate/options/      │
│   │   overlays → JSON                        │
│   ├─ icon_resolver: BitmapDescriptor → URL   │
│   └─ sessions: streams, tile fetch, errors   │
│        │ evaluateJavascript / JS handlers    │
│  InAppWebView (native OHOS ArkWeb)           │
│        │                                    │
│  OhosMaps JS bridge (map_html.dart)          │
│   └─ google.maps.Map + overlays + events     │
└──────────────────────────────────────────────┘
         HTTPS (Places / Geocoding / Directions)
                        │  keyed REST
                        ▼
               Google Maps Platform
```

There is no GMS Maps binary for OpenHarmony, so the JS API *is* the
native-supported path. Method channels to ArkTS cover only what JS can't:
device location and durable storage. Full design, protocol and data-flow
diagrams: [`docs/architecture.md`](docs/architecture.md).

---

## 6. The OHOS backport (`google_maps_flutter_ohos`)

Implements the entire `GoogleMapsFlutterPlatform` surface (platform
interface `2.12–2.13`): all 9 camera updates, markers (custom icons, info
windows, dragging, clustering), polylines, polygons, circles, heatmaps,
tile overlays (tiles pulled live from Dart `TileProvider`s), ground
overlays, styling, gestures, projections and all 15 event streams — plus
one documented extension the stock plugin lacks on *every* platform:

```dart
// Place-icon (POI) taps, with the Google placeId:
GoogleMapsFlutterOhos.poiTaps(controller.mapId).listen((tap) async {
  final details = await places.fetchDetails(tap.placeId);
});
```

Register once before `runApp` (`lib/main.dart:32`):

```dart
GoogleMapsFlutterOhos.register();
```

Known gaps (`takeSnapshot()` → null, compass/toolbar/lite-mode ignored,
best-effort dash patterns) and reuse instructions:
[`docs/backport.md`](docs/backport.md).

---

## 7. App user guide

Searching, place cards, POI taps, directions, saved places, layers,
my-location: [`docs/user-guide.md`](docs/user-guide.md).

---

## 8. OHOS native layer

`ohos/entry/src/main/ets/entryability/EntryAbility.ets` hosts two method
channels next to the plugin registrant:

| Channel | Methods | Backed by |
|---------|---------|-----------|
| `io.opengmaps/location` | `checkLocationPermission`, `requestLocationPermission`, `getCurrentLocation` | `abilityAccessCtrl`, `geoLocationManager` (FIRST_FIX, 5 s) |
| `io.opengmaps/storage` | `getString`, `setString`, `remove` | `data.preferences` store `open_gmaps` |

Permissions (`module.json5`): `INTERNET`, `LOCATION` + `APPROXIMATELY_LOCATION`
(with a user-visible reason string). Full reference:
[`docs/native-ohos.md`](docs/native-ohos.md).

---

## 9. Testing & verification status

```bash
fvm flutter analyze                                  # app: clean
fvm flutter test                                     # app: 13/13 pass
cd packages/google_maps_flutter_ohos && fvm flutter analyze  # 1 expected warning (git dep)
cd packages/google_maps_flutter_ohos && fvm flutter test     # backport: 21/21 pass
```

| Area | Status | How proven |
|------|--------|------------|
| Analyzers (app + backport) | ✅ clean | `flutter analyze` |
| 34 unit/widget tests | ✅ pass | `flutter test` (both packages) |
| Signed HAP build | ✅ | `flutter build hap --debug` |
| On-device launch, first frame | ✅ | OpenHarmony 5.0.1 emulator, hilog + screenshots |
| Location permission flow (request → system dialog → grant) | ✅ | Granted remotely via `uitest`, channel traffic in hilog |
| Storage channel round-trip | ✅ | `io.opengmaps/storage` answers in hilog, zero errors |
| WebView ↔ Dart bridge traffic | ✅ | `flutter_inappwebview` channel messages in hilog |
| Google auth-failure path | ✅ | Invalid key renders Google's error page + in-app banner (screenshot) |
| Live search / details / routes / tiles | ⏳ needs key | Implemented + fixture-tested; flip on with `--dart-define` |

On-device playbook (hdc install/launch/log/screenshot/uitest):
[`docs/testing.md`](docs/testing.md).

---

## 10. Troubleshooting (quick hits)

| Symptom | Fix |
|---------|-----|
| `SignHap 00303116` | Signing is pre-configured in `ohos/build-profile.json5`; if you changed it, see [`docs/troubleshooting.md`](docs/troubleshooting.md) |
| `ohpm ... google_maps_flutter_ohos.har does not exist` | Stale tool-generated HAR ref — remove that line from `ohos/entry/oh-package.json5` and rebuild |
| Tool crash `Cannot resolve symbolic links` in `ohos_plugins_manager` | A plugin declares an `ohos/` module it doesn't have; ours is intentionally Dart-only (see package pubspec note) |
| `flutter run` hangs with no output | Use HAP + `hdc install` + `aa start` instead |
| Emulator image download geo-blocked | CN VPN/proxy, DevEco on a CN network, or a physical device |
| App won't spawn / `get bundle info failed` | Emulator session is wedged: `hdc uninstall`, fresh emulator, reinstall |
| Blank map with valid-looking setup | Check key, enabled APIs + billing; look for the in-app red banner / `gm_authFailure` |
| `JAVA_HOME / major version` errors | OHOS needs JDK 17 |

All of these, fully explained: [`docs/troubleshooting.md`](docs/troubleshooting.md).

---

## 11. Configuration reference

| File | Purpose |
|------|---------|
| `pubspec.yaml` (`sdk >=2.19.6 <4.0.0`, `google_maps_flutter 2.12.3`, path backport, SIG WebView) | Deps, assets, Google Sans fonts |
| `.fvmrc` (`"flutter":"ohos"`) + FVM `ohos` SDK 3.27.4 / Dart 3.6.2 | Pinned toolchain |
| `lib/src/config/google_maps_config.dart` | `GOOGLE_MAPS_API_KEY` define, `hasKey`, `MissingGoogleMapsKey`, `GoogleMapsApiException` |
| `ohos/AppScope/app.json5` | `bundleName io.opengmaps.open_gmaps` |
| `ohos/build-profile.json5` | `compatibleSdkVersion 5.0.0(12)`, `runtimeOS HarmonyOS`, signing |
| `ohos/entry/src/main/module.json5` | `INTERNET`, `LOCATION`, `APPROXIMATELY_LOCATION` |
| `ohos/signatures/` | Signing materials (private — never share publicly) |
| `packages/google_maps_flutter_ohos/pubspec.yaml` | Backport deps (`platform_interface ^2.12.1`, SIG WebView) |

---

## 12. Roadmap

- [ ] Live-key pass: search → POI tap → save → restart → directions, on device
- [ ] `geolocator`-style location stream consolidation in the backport
- [ ] Advanced markers (`AdvancedMarkerElement`) behind cloud map IDs
- [ ] Offline tile cache + `mbtiles`
- [ ] CI: `analyze` + `test` matrix (app + backport), HAP smoke build
- [ ] Publish `google_maps_flutter_ohos` (needs a native shell for the federated-plugin declaration)

---

## 13. Contributing

Issues and PRs welcome. Please: keep the stock `google_maps_flutter` API
untouched (all OHOS behavior belongs in the backport package), add a test
for every new translation path, run both analyzers + both test suites, and
never commit Google API keys. (`ohos/signatures/` is committed for
out-of-the-box local builds — generate your own signing materials for any
serious release.)

---

## 14. License & Acknowledgements

Apache 2.0 — [`LICENSE`](LICENSE). Google Maps Platform data © Google;
key use is subject to Google's terms and billing.

- [Flutter OHOS (CPF-Flutter)](https://gitcode.com/CPF-Flutter/flutter_flutter) 3.27.4-ohos
- [`google_maps_flutter` 2.12.3](https://pub.dev/packages/google_maps_flutter) + platform interface
- [OpenHarmony SIG `flutter_inappwebview`](https://gitee.com/openharmony-sig/flutter_inappwebview)
- [OpenHarmony docs](https://docs.openharmony.cn) / [Huawei emulator FAQs](https://developer.huawei.com/consumer/en/doc/harmonyos-guides/ide-emulator-faqs)
