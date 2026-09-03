# OpenGMaps — Google Maps for OpenHarmony

> Flutter Google Maps app for OpenHarmony/HarmonyOS using the **stock
> `google_maps_flutter` widget** (`2.12.3`). OHOS rendering comes from the
> in-repo backport **`packages/google_maps_flutter_ohos`**, which implements
> `GoogleMapsFlutterPlatform` on the official Maps JavaScript API inside the
> native OHOS WebView — plus keyed **Places / Geocoding / Directions** REST
> clients and native OHOS Location Kit. **OHOS-only** — Android/iOS shells
> remain but are unused.

![HarmonyOS](https://img.shields.io/badge/HarmonyOS-NEXT-0A59F7?style=flat-square)
![OpenHarmony](https://img.shields.io/badge/OpenHarmony-5.0%20API12-00BFFF?style=flat-square)
![Flutter OHOS](https://img.shields.io/badge/Flutter-3.7.12_ohos_(Dart_2.19)-02569B?style=flat-square&logo=flutter)
![Apple Silicon](https://img.shields.io/badge/macOS-arm64_(M1--M4)-000000?style=flat-square&logo=apple)
![License](https://img.shields.io/badge/License-Apache_2.0-green?style=flat-square)

---

## Table of Contents
- [1. TL;DR for Humans](#1-tldr-for-humans)
- [2. TL;DR for AI Agents](#2-tldr-for-ai-agents)
- [3. Architecture](#3-architecture)
- [4. HarmonyOS Design (HMOS NEXT)](#4-harmonyos-design-hmos-next)
- [5. Maps — Proper Google Maps on OHOS](#5-maps--proper-google-maps-on-ohos)
- [6. Project Structure](#6-project-structure)
- [7. Prerequisites](#7-prerequisites)
- [8. Setup & Verify](#8-setup--verify)
- [9. Emulator (Apple Silicon) — Known Geo-Lock](#9-emulator-apple-silicon--known-geo-lock)
- [10. Build & Run (OHOS-only)](#10-build--run-ohos-only)
- [11. Testing](#11-testing)
- [12. Configuration Reference](#12-configuration-reference)
- [13. Troubleshooting](#13-troubleshooting)
- [14. Roadmap](#14-roadmap)
- [15. License & Acknowledgements](#15-license--acknowledgements)

---

## 1. TL;DR for Humans

```bash
git clone <this-repo> OpenGMaps && cd OpenGMaps
fvm use ohos --force && fvm flutter pub get
fvm flutter analyze # No issues on ohos
fvm flutter test    # 1 passed
# Emulator image download requires CN IP (see §9) — then:
fvm flutter run -d <ohos-device> # or: fvm flutter build hap --debug
```

What you get: pill search bar (48dp), `HmosChip` filters, floating pill bottom bar, `DraggableScrollableSheet` with `HmosCard`/`HmosListTile`, map-type sheet, and Google Maps Embed in an OHOS WebView. Configure `GOOGLE_MAPS_API_KEY` to load the supported Google Embed surface; without it, OHOS shows a key-required state instead of a misleading map.

---

## 2. TL;DR for AI Agents

> Copy-paste this block to reproduce. All paths are repo-relative. Assumes `fvm` + `ohos` SDK at `~/Library/OpenHarmony/command-line-tools`.

```json
{
  "goal": "Run OpenGMaps on OHOS (Flutter OHOS 3.7.12, Dart 2.19, API12, arm64)",
  "fvm_pin": "ohos",
  "sdk_constraint": ">=2.19.6 <4.0.0",
  "key_deps": { "google_maps_flutter": "2.3.0", "flutter_inappwebview": "6.0.0 (OHOS SIG fork)" },
  "entry": "lib/main.dart:15 OpenGMapsApp -> HomePage:55",
  "map_dispatch": "lib/src/maps/open_gmaps_widget.dart:46 OHOS -> GoogleEmbedMap (InAppWebView), other targets -> GoogleMap",
  "embed_url": "lib/src/maps/google_embed_map.dart https://www.google.com/maps/embed/v1/view",
  "theme": "lib/src/harmony/harmony_theme.dart:19 HmosTheme.light()/dark()",
  "bundle": "ohos/AppScope/app.json5:1 io.opengmaps.open_gmaps",
  "hvigor_product": "ohos/build-profile.json5:1 compatibleSdkVersion 5.0.0(12) runtimeOS HarmonyOS",
  "verify": [
    "fvm use ohos --force",
    "fvm flutter pub get",
    "fvm flutter analyze # expect No issues",
    "fvm flutter test # expect 1 passed"
  ],
  "build": "fvm flutter build hap --debug # PackageHap ok, SignHap needs DevEco auto-sign (§10)",
  "emulator": {
    "binary": "~/Library/OpenHarmony/command-line-tools/emulator/Emulator:1 arm64 6.1.1.200",
    "image": "HarmonyOS 6.1.1(24) phone",
    "install_cmd": "Emulator -install -deviceType phone -osVersion \"HarmonyOS 6.1.1(24)\"",
    "known_failure": "Currently, this capability is available only in the Chinese mainland. (IP 151.18.7.63 IT) — needs CN VPN/proxy via Emulator -config -http_proxy",
    "workarounds": ["CN VPN then Emulator -install", "DevEco Studio on CN network", "Physical OHOS device via hdc"]
  }
}
```

**Steps for an agent:**

1. `fvm use ohos --force` — writes `.fvm/fvm_config.json:2` + `.fvmrc:1` (`"flutter":"ohos"`), `flutter --version` → `3.7.12` + `Dart 2.19.6` (patched `version:1`/`flutter.version.json` from `0.0.0-unknown`).
2. `fvm flutter pub get` — resolves `google_maps_flutter:2.3.0` (`pubspec.yaml:15`, `>=2.14 <4` satisfies both `2.19` and `3.13`). No `flutter_map` (avoids `4.0 <3` vs `8.x >=3.6` split).
3. `fvm flutter analyze` / `test` — must be `No issues` / `All tests passed`.
4. For HAP: see §10 (signing). For emulator: see §9 (geo-lock) — do **not** attempt Android/iOS.

---

## 3. Architecture

```
lib/
├── main.dart                         # OpenGMapsApp → HomePage (stock GoogleMap + Google UI)
└── src/
    ├── config/
    │   └── google_maps_config.dart   # GOOGLE_MAPS_API_KEY (--dart-define), hasKey, typed errors
    ├── maps/
    │   └── polyline_codec.dart       # overview_polyline decode/encode (tested)
    ├── utils/
    │   └── geo.dart                  # LatLng.asParam for REST calls
    └── services/
        ├── google_places_service.dart    # Autocomplete / Text Search / Details (keyed REST)
        ├── google_geocoding_service.dart # reverse (map tap) + forward (keyed REST)
        ├── google_directions_service.dart# Directions API + TravelMode + universal Navigate URL
        ├── location_service.dart         # OHOS Location Kit via io.opengmaps/location
        └── saved_places_service.dart     # saved pins + recent searches
packages/google_maps_flutter_ohos/    # OHOS backport of google_maps_flutter
ohos/  # EntryAbility.ets: check/request permission + getCurrentLocation, API12
```

---

## 4. HarmonyOS Design (HMOS NEXT)

- **Colors** `harmony_colors.dart:1`: `primary #0A59F7`, `background #F1F3F5`, `surface #FFFFFF`, `surfaceVariant #F5F7FA`, `textPrimary #000000`, `textSecondary #5A5A5A`, `textTertiary #8E8E93`, `divider #E5E5EA`, `success/warning/error`, dark `darkBackground #0A0A0A` etc.
- **Typography** `harmony_typography.dart:1`: `family HarmonyOS_Sans`, `displayLarge 28/700`, `titleLarge 22/600`, `bodyLarge 16/400`, `labelLarge 14/500` etc. Falls back to system sans if font asset missing.
- **Shape**: `HmosTheme:13` `radiusSmall 12, Medium 16, Large 20, XLarge 24, Full 999`; shadows `blur 16 y4 6%` + `blur 4 y1 3%`, `divider 0.5dp`.
- **Components**: `HmosCard` (20dp + soft shadow), `HmosSearchBar` (pill, `surfaceVariant`, `divider 0`), `HmosChip` (`primary` when selected), `HmosBottomSheet` (24dp top, handle `36×4`), `HmosBottomBar` pill (`surface` + `divider 0.5`).
- **Theme** `harmony_theme.dart:19`: `useMaterial3:true`, `ColorScheme.light/dark`, `AppBar 0 elevation centerTitle`, `ChipTheme/InputDecoration pill`, `CardTheme` omitted (Flutter 3.7 `CardTheme` vs 3.16+ `CardThemeData`).

---

## 5. Maps — `google_maps_flutter` backported to OHOS

**There is no GMS / native Maps SDK binary for OpenHarmony**, so the
backport renders the official **Maps JavaScript API** (weekly channel,
vector rendering, gestures, controls) inside the GPU-composited OHOS
WebView and translates the whole stock plugin surface to it:
`GoogleMap`/`GoogleMapController`, all 9 `CameraUpdate` types, markers
(custom icons, info windows, dragging, clustering), polylines, polygons,
circles, heatmaps, tile overlays (tiles pulled from Dart `TileProvider`s),
ground overlays, map styling, all map types, gestures, projections and
every event stream. Place data, geocoding and routes come from the keyed
**Places / Geocoding / Directions** REST APIs.

```
packages/google_maps_flutter_ohos/
├── lib/google_maps_flutter_ohos.dart  # register() entry point
└── lib/src/
    ├── google_maps_flutter_ohos.dart  # GoogleMapsFlutterPlatform impl
    ├── ohos_map_view.dart             # WebView host widget
    ├── map_bridge.dart                # sessions, events, tile fetching
    ├── map_html.dart                  # OhosMaps JS bridge
    ├── icon_resolver.dart             # BitmapDescriptor → data URLs
    └── translation.dart               # camera/options/overlay mapping
```

The app registers it in `main()` (`lib/main.dart:24`) and then uses the
stock API unchanged — no platform fork in app code. The package is
consumed as a Dart package with an explicit `register()` call (the OHOS
flutter tool crashes on Dart-only `flutter.plugin` declarations, so the
`implements:` block is intentionally omitted; see the package pubspec).

Build/run with a key supplied out-of-band:

```bash
fvm flutter run -d <ohos-device> --dart-define=GOOGLE_MAPS_API_KEY=YOUR_KEY
fvm flutter build hap --debug --dart-define=GOOGLE_MAPS_API_KEY=YOUR_KEY
```

Enable Maps JavaScript API, Places API, Geocoding API and Directions API
with billing for the owning Google Cloud project. Without a key, the map
shows an honest key-required state — never a third-party map mislabeled
as Google. Verified on-device (OpenHarmony 5.0.1): launch, location
channel, WebView bridge traffic and the Google auth error path, with zero
Dart errors; full map rendering unlocks with a valid key.

---

## 6. Project Structure

```
.
├── lib/main.dart
├── lib/src/harmony/...
├── lib/src/maps/...
├── ohos/
│   ├── AppScope/app.json5          # bundleName io.opengmaps.open_gmaps
│   ├── entry/src/main/ets/entryability/EntryAbility.ets # FlutterAbility
│   ├── entry/src/main/module.json5 # ohos.permission.INTERNET
│   ├── build-profile.json5         # 5.0.0(12) HarmonyOS
│   └── hvigorfile.ts / oh-package.json5
├── android/ ios/                   # shells (unused, OHOS-only)
├── assets/images/.gitkeep
├── test/widget_test.dart           # OpenGMapsApp smoke
├── pubspec.yaml                    # sdk >=2.19.6 <4.0.0, Embed WebView + google_maps_flutter
├── .fvm/fvm_config.json + .fvmrc  # flutterSdkVersion ohos
└── README.md (this file)
```

---

## 7. Prerequisites

- **macOS arm64** (M1–M4, tested M4 `arm64` `Apple M4`)
- **FVM** `brew install fvm` (`fvm --version 4.3.0`)
- **OHOS Flutter SDK** `3.7.12` (Dart `2.19.6`, Engine `1a65d409c7`): `fvm install ohos` or `git clone https://gitcode.com/CPF-Flutter/flutter_flutter` → `~/development/flutter_ohos` → `fvm use ohos`. Patched `version:1`/`bin/cache/flutter.version.json` from `0.0.0-unknown` via `git tag 3.7.12`.
- **OpenHarmony SDK 5.0 API12** at `~/Library/OpenHarmony/command-line-tools/sdk` (`ohpm 6.1.2.268`, `hvigorw 6.24.2`, `hdc Ver:3.2.0d`, `Emulator 6.1.1.200 arm64`).
- **Google Maps**: for production OHOS builds, supply `GOOGLE_MAPS_API_KEY` with `--dart-define` and enable the Maps Embed API in Google Cloud. Native Android/iOS builds also need their normal SDK key configuration.

Check:

```bash
fvm list # stable 3.47.2 + ohos 0.0.0-unknown → 3.7.12 after tag
/Users/abhi/fvm/versions/ohos/bin/flutter --version # 3.7.12 + Dart 2.19.6
~/Library/OpenHarmony/command-line-tools/emulator/Emulator -version # 6.1.1.200
file ~/Library/OpenHarmony/command-line-tools/emulator/Emulator # arm64
```

---

## 8. Setup & Verify

```bash
git clone <this-repo> OpenGMaps && cd OpenGMaps
fvm use ohos --force
fvm flutter pub get          # OHOS SIG InAppWebView + google_maps_flutter transitives
fvm flutter analyze          # → No issues found!
fvm flutter test             # → 00:01 +1 All tests passed!
```

For AI agents: run exactly the `verify` array in §2. Lockfile is `ohos`-pinned (`pubspec.lock` from `2.19`); stable will diverge (`meta 1.19` etc.) — both valid, do not commit stable lock when testing OHOS.

---

## 9. Emulator (Apple Silicon) — Known Geo-Lock

**Status: binary ready, image blocked outside CN.**

```bash
Emulator -license accept                # 4/4 Huawei agreements
Emulator -imageList                     # HarmonyOS 6.1.1(24) phone/foldable/tablet downloaded:false
Emulator -list                          # empty
hdc list targets -v                     # empty
Emulator -install -deviceType phone -osVersion "HarmonyOS 6.1.1(24)"
# Currently, this capability is available only in the Chinese mainland.
# IP 151.18.7.63 (IT) via https://devecostudio-drcn.deveco.dbankcloud.com
curl -x http://42.2.156.79:80 https://devecostudio-drcn.deveco.dbankcloud.com # timeout after 75s (free CN proxies unreliable)
```

**Why:** Huawei `drcn` image server geo-fences to CN IPs.

**Fixes (pick one):**

1. **CN VPN** (recommended) → `Emulator -config -http_proxy http://<cn-proxy>:port` → `Emulator -install ...` → `Emulator -create -deviceType phone -osVersion "HarmonyOS 6.1.1(24)"` → `Emulator -start <name>` → `hdc list targets` → `fvm flutter run -d <id>`.
2. **DevEco Studio on CN network** (mac-arm64): SDK Manager → Emulator → Download `Phone 6.1.1(24)` → `~/Library/OpenHarmony/emulator_images` then `Emulator -create ...` on this Mac.
3. **Physical OHOS device** (Dayu210/HiHope): USB → `hdc list targets` → `fvm flutter run`.

Previewer (`sdk/default/openharmony/previewer`) is arm64 but is ArkUI-only, not a full `flutter run` target.

---

## 10. Build & Run (OHOS-only)

```bash
fvm use ohos --force
fvm flutter pub get

# 1. Verify
fvm flutter analyze && fvm flutter test

# 2. Build HAP (needs signing — see below)
fvm flutter build hap --debug   # PackageHap ok, SignHap needs auto-sign
fvm flutter build hap --release

# 3. Run (after emulator/device + signing)
fvm flutter devices # or hdc list targets
fvm flutter run -d <ohos-id>
hdc install ohos/entry/build/default/outputs/default/entry-default-signed.hap
hdc shell aa start -a EntryAbility -b io.opengmaps.open_gmaps
```

**Signing (API24 requires 32-char passwords):**

- DevEco: Open `ohos/` → File → Project Structure → Signing Configs → ✅ Automatically generate signature → writes `build-profile.json5` `signingConfigs` (`storeFile` + `storePassword>=32` etc.) → `fvm flutter build hap` succeeds.
- Manual: `hap-sign-tool.jar generate-keypair -keyAlias debugkey -keyPwd 12345678901234567890123456789012 -keyAlg ECC -keySize NIST-P-256 -keystoreFile /tmp/debugKey.p12 -keystorePwd ...` + `generate-profile-cert`/`sign-profile` to produce `debug-profile.p7b`, then `build-profile.json5` `material{storeFile,storePassword,keyAlias,signAlg,profile,certpath}`.

Without signing, `hvigor` stops at `:entry:default@SignHap 00303116 Configuration Error`.

---

## 11. Testing

```bash
fvm flutter test          # lib/main.dart OpenGMapsApp smoke
fvm flutter analyze       # ohos No issues; stable shows 22 withOpacity infos (ignore)
```

`test/widget_test.dart:1` pumps `OpenGMapsApp` and verifies the Google-branded shell, navigation, and strict no-fake-data service behavior.

---

## 12. Configuration Reference

| File | Purpose |
|------|---------|
| `pubspec.yaml:7` `sdk >=2.19.6 <4.0.0`, `15` `google_maps_flutter:2.3.0` | Only dep, assets `assets/images/` |
| `.fvm/fvm_config.json:2` + `.fvmrc:1` | `flutterSdkVersion: ohos` |
| `ohos/build-profile.json5:1` | `compatibleSdkVersion 5.0.0(12)` `runtimeOS HarmonyOS` |
| `ohos/entry/src/main/module.json5:1` | `requestPermissions [INTERNET]` |
| `ohos/AppScope/app.json5:1` | `bundleName io.opengmaps.open_gmaps` `vendor example` |
| `ohos/entry/src/main/ets/entryability/EntryAbility.ets:1` | `extends FlutterAbility` + `GeneratedPluginRegistrant` |
| `lib/src/maps/google_embed_map.dart` | Google Maps Embed API WebView surface on OHOS |
| `lib/src/maps/ohos_tile_map.dart` | Legacy development renderer retained for reference, not selected on OHOS |
| `ohos/.hvigor/` + `oh_modules/` | hvigor cache (gitignored) |

---

## 13. Troubleshooting

- `0.0.0-unknown` → `git -C /Users/abhi/development/flutter_ohos tag 3.7.12` + `echo 3.7.12 > version` + `flutter.version.json` `frameworkVersion 3.7.12`.
- `Emulator -install` → `Chinese mainland only` → CN VPN / DevEco on CN / physical device (§9).
- `SignHap 00303116` / `storePassword <32` → DevEco auto-sign or 32-char `generate-keypair`.
- `GOOGLE_MAPS_API_KEY` — supply it with `--dart-define` for the OHOS Google Maps Embed API path. Android/iOS native maps still need their platform-specific SDK key configuration.
- `major version 70` → `JAVA_HOME` mismatch; OHOS needs `17` (`/opt/homebrew/opt/openjdk@17/...`), `7.5` supports `<=18`. `fvm flutter config` unavailable on `3.7` — use `JAVA_HOME=/opt/homebrew/opt/openjdk@17/...`.

---

## 14. Roadmap

- [ ] Native OHOS map provider if a Google-compatible OHOS SDK becomes available (current production path is Google Maps Embed in WebView)
- [ ] Tile cache `flutter_cache_manager` + offline `mbtiles`
- [ ] Unified `geolocator` ↔ `@ohos.geoLocationManager`
- [ ] Map style JSON parity
- [ ] CI `fvm` matrix `ohos` (hap) + stable, `hvigor --analyze`

---

## 15. License & Acknowledgements

Apache 2.0 — `LICENSE`.

- [Flutter OHOS (CPF-Flutter) 3.7.12](https://gitcode.com/CPF-Flutter/flutter_flutter)
- [google_maps_flutter 2.3.0](https://pub.dev/packages/google_maps_flutter) (Dart 2.19 compat)
- [HarmonyOS Design](https://developer.harmonyos.com/cn/design) / [Emulator FAQs](https://developer.huawei.com/consumer/en/doc/harmonyos-guides/ide-emulator-faqs)
- Google Maps Embed API and Google Maps Platform © Google

> Humans: open `lib/main.dart:15` and run. Agents: follow §2 JSON and §8 commands byte-for-byte.
