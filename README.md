# OpenGMaps — Google Maps for OpenHarmony

> Flutter backport of `google_maps_flutter` to OpenHarmony/HarmonyOS with **HMOS NEXT** design. One codebase: **native `google_maps_flutter` on Android/iOS/Web**, **pure-Dart Google raster tiles on OHOS** (`mt*.google.com`) behind an identical `OpenGMaps` API. **OHOS-only** — Android/iOS shells remain but are unused.

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

What you get: pill search bar (48dp), `HmosChip` filters, floating pill bottom bar, `DraggableScrollableSheet` with `HmosCard`/`HmosListTile`, map-type sheet, **Google raster tiles on OHOS** — no OSM.

---

## 2. TL;DR for AI Agents

> Copy-paste this block to reproduce. All paths are repo-relative. Assumes `fvm` + `ohos` SDK at `~/Library/OpenHarmony/command-line-tools`.

```json
{
  "goal": "Run OpenGMaps on OHOS (Flutter OHOS 3.7.12, Dart 2.19, API12, arm64)",
  "fvm_pin": "ohos",
  "sdk_constraint": ">=2.19.6 <4.0.0",
  "key_deps": { "google_maps_flutter": "2.3.0" },
  "entry": "lib/main.dart:15 OpenGMapsApp -> HomePage:55",
  "map_dispatch": "lib/src/maps/open_gmaps_widget.dart:46 defaultTargetPlatform.toString().contains('ohos') ? OhosTileMap : GoogleMap",
  "tile_url": "lib/src/maps/ohos_tile_map.dart:85 https://mt{sub}.google.com/vt/lyrs={m|s|y|p}&hl=en&x={x}&y={y}&z={z}&s=Ga",
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
├── main.dart                         # OpenGMapsApp (HmosTheme) → HomePage (Stack: map + HMOS overlays)
└── src/
    ├── harmony/
    │   ├── harmony_colors.dart       # HmosColors tokens
    │   ├── harmony_typography.dart   # HmosTypography (HarmonyOS Sans)
    │   ├── harmony_theme.dart        # HmosTheme.light()/dark()
    │   └── widgets/
    │       ├── hmos_card.dart        # soft 20dp card
    │       ├── hmos_search_bar.dart  # pill 48dp + mic
    │       ├── hmos_app_bar.dart     # + pill HmosBottomBar
    │       ├── hmos_button.dart      # primary/secondary/ghost
    │       ├── hmos_chip.dart        # HmosFilter + HmosFilterChips
    │       ├── hmos_list_tile.dart
    │       └── hmos_bottom_sheet.dart
    └── maps/
        ├── open_gmaps_types.dart         # OpenLatLng:5, OpenCameraPosition:18, OpenMarker:29, OpenMapType:64
        ├── open_gmaps_controller.dart    # OpenGMapsController:4 + OhosTileController:13
        ├── ohos_tile_map.dart            # pure-Dart tile grid (Mercator) — OHOS
        └── open_gmaps_widget.dart        # OpenGMaps:12 — dispatch _isOhos:46
ohos/  # EntryAbility.ets:1 FlutterAbility, hvigor, 5.0(12)
```

Dispatch:

```dart
// lib/src/maps/open_gmaps_widget.dart:46
bool get _isOhos => !kIsWeb && defaultTargetPlatform.toString().contains('ohos');
// avoids TargetPlatform.ohos missing on stable (Dart 2.19 compat, no switch-expr)
if (_isOhos) return OhosTileMap(...);
else return GoogleMap(...); // google_maps_flutter
```

`OhosTileMap` (`ohos_tile_map.dart:34`): Mercator `_lngToX/_latToY`, `tileCount=2^z`, `cols/rows` buffer, `GestureDetector` pan → `center`, `Positioned` `Image.network` tiles + `Positioned` markers.

---

## 4. HarmonyOS Design (HMOS NEXT)

- **Colors** `harmony_colors.dart:1`: `primary #0A59F7`, `background #F1F3F5`, `surface #FFFFFF`, `surfaceVariant #F5F7FA`, `textPrimary #000000`, `textSecondary #5A5A5A`, `textTertiary #8E8E93`, `divider #E5E5EA`, `success/warning/error`, dark `darkBackground #0A0A0A` etc.
- **Typography** `harmony_typography.dart:1`: `family HarmonyOS_Sans`, `displayLarge 28/700`, `titleLarge 22/600`, `bodyLarge 16/400`, `labelLarge 14/500` etc. Falls back to system sans if font asset missing.
- **Shape**: `HmosTheme:13` `radiusSmall 12, Medium 16, Large 20, XLarge 24, Full 999`; shadows `blur 16 y4 6%` + `blur 4 y1 3%`, `divider 0.5dp`.
- **Components**: `HmosCard` (20dp + soft shadow), `HmosSearchBar` (pill, `surfaceVariant`, `divider 0`), `HmosChip` (`primary` when selected), `HmosBottomSheet` (24dp top, handle `36×4`), `HmosBottomBar` pill (`surface` + `divider 0.5`).
- **Theme** `harmony_theme.dart:19`: `useMaterial3:true`, `ColorScheme.light/dark`, `AppBar 0 elevation centerTitle`, `ChipTheme/InputDecoration pill`, `CardTheme` omitted (Flutter 3.7 `CardTheme` vs 3.16+ `CardThemeData`).

---

## 5. Maps — Proper Google Maps on OHOS

**OHOS = pure Google raster tiles, no OSM.** `ohos_tile_map.dart:85`:

```dart
String lyrs; switch(mapType){
  case satellite: lyrs='s'; break; // satellite
  case hybrid:    lyrs='y'; break; // hybrid
  case terrain:   lyrs='p'; break; // terrain
  default:        lyrs='m'; break; // roadmap
}
final sub=(x+y)%4; // mt0..3 load balancing
return 'https://mt$sub.google.com/vt/lyrs=$lyrs&hl=en&x=$x&y=$y&z=$z&s=Ga';
```

`mt*.google.com/vt` serves without API key for demo (add `&key=YOUR_KEY` for production). `OpenMapType` (`open_gmaps_types.dart:64`) `normal/satellite/terrain/hybrid` → `label/icon` via `OpenMapTypeX`. Native `google_maps_flutter` (`open_gmaps_widget.dart:110` `GoogleMap`) used elsewhere, but **this repo is OHOS-only** — `OhosTileMap` is the tested path.

Why `2.3.0`? (`pubspec.yaml:15`) Latest `google_maps_flutter 2.12` needs Dart `^3.6` → breaks OHOS `2.19`. `2.3.0` (`>=2.14 <4`) satisfies both. `flutter_map` intentionally not depended — would need `4.0 <3` vs `8.x >=3.6` and diverge lockfiles.

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
├── pubspec.yaml                    # sdk >=2.19.6 <4.0.0, google_maps_flutter 2.3.0
├── .fvm/fvm_config.json + .fvmrc  # flutterSdkVersion ohos
└── README.md (this file)
```

---

## 7. Prerequisites

- **macOS arm64** (M1–M4, tested M4 `arm64` `Apple M4`)
- **FVM** `brew install fvm` (`fvm --version 4.3.0`)
- **OHOS Flutter SDK** `3.7.12` (Dart `2.19.6`, Engine `1a65d409c7`): `fvm install ohos` or `git clone https://gitcode.com/CPF-Flutter/flutter_flutter` → `~/development/flutter_ohos` → `fvm use ohos`. Patched `version:1`/`bin/cache/flutter.version.json` from `0.0.0-unknown` via `git tag 3.7.12`.
- **OpenHarmony SDK 5.0 API12** at `~/Library/OpenHarmony/command-line-tools/sdk` (`ohpm 6.1.2.268`, `hvigorw 6.24.2`, `hdc Ver:3.2.0d`, `Emulator 6.1.1.200 arm64`).
- **Google Maps**: no key for OHOS `mt` tiles; native would need `com.google.android.geo.API_KEY` (not used here).

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
fvm flutter pub get          # ohos: google_maps_flutter 2.3.0 + transitives (meta 1.8 etc.)
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

`test/widget_test.dart:1` pumps `OpenGMapsApp` and expects `Search places, food, hotels`.

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
| `lib/src/maps/ohos_tile_map.dart:85` | Google `mt*.google.com/vt` tile URL |
| `ohos/.hvigor/` + `oh_modules/` | hvigor cache (gitignored) |

---

## 13. Troubleshooting

- `0.0.0-unknown` → `git -C /Users/abhi/development/flutter_ohos tag 3.7.12` + `echo 3.7.12 > version` + `flutter.version.json` `frameworkVersion 3.7.12`.
- `Emulator -install` → `Chinese mainland only` → CN VPN / DevEco on CN / physical device (§9).
- `SignHap 00303116` / `storePassword <32` → DevEco auto-sign or 32-char `generate-keypair`.
- `minSdkVersion 16 <20` / `GOOGLE_MAPS_API_KEY` — Android only, ignore for OHOS; if building Android, `minSdk 20` + dummy `AIzaSyDummyKeyForDebug_OpenGMaps` in `AndroidManifest.xml:36`.
- `major version 70` → `JAVA_HOME` mismatch; OHOS needs `17` (`/opt/homebrew/opt/openjdk@17/...`), `7.5` supports `<=18`. `fvm flutter config` unavailable on `3.7` — use `JAVA_HOME=/opt/homebrew/opt/openjdk@17/...`.

---

## 14. Roadmap

- [ ] OHOS Map Kit `@ohos.geoLocationManager` + `@ohos.map` via `MethodChannel`/`PlatformView` (current pure-Dart tiles)
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
- Google raster tiles `mt*.google.com` © Google, preview OSM © OSM

> Humans: open `lib/main.dart:15` and run. Agents: follow §2 JSON and §8 commands byte-for-byte.
