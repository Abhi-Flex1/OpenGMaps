# Getting started

From zero to the app running on an OHOS target. (For the API key that
unlocks maps/search/directions, see [`api-keys.md`](api-keys.md) — the app
runs without one, with honest placeholders.)

## 1. Prerequisites

| Tool | Version used | Notes |
|------|--------------|-------|
| macOS | arm64 (M1–M4) | Only tested platform |
| FVM | 4.x (`brew install fvm`) | Manages the OHOS Flutter SDK |
| Flutter OHOS SDK | `3.27.4` channel `oh-3.27.4-dev`, Dart `3.6.2`, Engine `e672b006cb` | `fvm install ohos`, then `fvm use ohos --force` in the repo (writes `.fvmrc`) |
| OpenHarmony command-line tools | `~/Library/OpenHarmony/command-line-tools` (`ohpm 6.1.2.268`, `hvigorw`, `hdc`) | Provides SDK 5.0 (API 12), the emulator and `hdc` |
| JDK | 17 (`/opt/homebrew/opt/openjdk@17`) | OHOS builds fail on other majors — set `JAVA_HOME` |
| Google account | — | Only needed when you want live maps/data (the key) |

Check your setup:

```bash
fvm flutter --version   # Flutter 3.27.4 • channel oh-3.27.4-dev • Dart 3.6.2
hdc version             # hdc Ver:3.2.0d or similar
hdc list targets -v     # your emulator / USB device, once available
```

## 2. Clone, resolve, verify

```bash
git clone https://github.com/Abhi-Flex1/OpenGMaps.git && cd OpenGMaps
fvm use ohos --force
fvm flutter pub get
fvm flutter analyze   # → No issues found!
fvm flutter test      # → All tests passed! (13 tests)

cd packages/google_maps_flutter_ohos
fvm flutter pub get
fvm flutter analyze   # → 1 publish warning about the git dep (expected, harmless)
fvm flutter test      # → All tests passed! (21 tests)
cd ../..
```

> `pubspec.lock` is pinned for the `ohos` SDK. Resolving with stable
> Flutter produces a different (also valid) lockfile — don't commit that
> one if you switch back and forth.

## 3. Get a target

**Emulator.** The stock image server is geo-fenced to mainland China, so on
most networks `Emulator -install` fails with *"Currently, this capability
is available only in the Chinese mainland."* Workarounds that people
actually use: a CN VPN/proxy (`Emulator -config -http_proxy …`), DevEco
Studio on a CN network, or — simplest — a physical OHOS device over USB.
Full details and commands:
[`troubleshooting.md#emulator`](troubleshooting.md#emulator-image-downloads-are-geo-fenced).

Once anything appears in `hdc list targets`, you're good:

```bash
hdc list targets -v
# 127.0.0.1:5555  TCP  Connected  localhost   ← emulator, or a USB device
```

If a stale server hides your device: `hdc kill`, then
`hdc tconn 127.0.0.1:5555` (emulator default).

## 4. Run it

```bash
# UI shell without a key (placeholders where Google data goes):
fvm flutter run -d <ohos-device>

# Everything, with a key:
fvm flutter run -d <ohos-device> --dart-define=GOOGLE_MAPS_API_KEY=YOUR_KEY
```

If `flutter run` hangs with no output (known flakiness), use the manual
flow — it always works:

```bash
fvm flutter build hap --debug --dart-define=GOOGLE_MAPS_API_KEY=YOUR_KEY
hdc install ohos/entry/build/default/outputs/default/entry-default-signed.hap
hdc shell aa start -a EntryAbility -b io.opengmaps.open_gmaps
```

Signing is pre-configured (`ohos/build-profile.json5` + `ohos/signatures/`),
so debug builds sign out of the box. Release builds:
`fvm flutter build hap --release`.

## 5. What you should see

- **Without a key**: search bar, layers button, bottom nav
  (Explore/Go/Saved), a key banner on top and a "Google Maps API key
  required" card where the map goes. A system dialog asks for location
  permission on first launch — allow it to enable the my-location flow.
- **With a valid key**: the real Google map, blue-dot location, working
  search/directions/saved (see [`user-guide.md`](user-guide.md)).
- **With an invalid key**: Google's own auth-error page inside the map
  plus a red in-app error banner (tap to dismiss). This is the designed
  failure mode — proof the bridge reached Google and got rejected.

Next: [`api-keys.md`](api-keys.md) to unlock everything, or
[`architecture.md`](architecture.md) to understand the machine.
