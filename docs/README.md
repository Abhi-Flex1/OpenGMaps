# OpenGMaps documentation

Start here if you're new; each guide is self-contained.

| Guide | Read it when you want to… |
|-------|---------------------------|
| [`getting-started.md`](getting-started.md) | Install the toolchain and run the app for the first time |
| [`api-keys.md`](api-keys.md) | Create a Google Maps key, enable APIs, wire it into builds |
| [`architecture.md`](architecture.md) | Understand how the whole thing fits together |
| [`backport.md`](backport.md) | Learn or reuse the `google_maps_flutter` OHOS implementation |
| [`services.md`](services.md) | Use/extend the Places, Geocoding, Directions, Location, Storage clients |
| [`native-ohos.md`](native-ohos.md) | Work with the ArkTS side: channels, permissions, project layout |
| [`testing.md`](testing.md) | Run tests and verify on a real device like a maintainer |
| [`troubleshooting.md`](troubleshooting.md) | Fix anything that breaks |
| [`user-guide.md`](user-guide.md) | Actually use the app (search, places, directions, saved) |

Conventions used throughout:

- All paths are relative to the repo root unless stated otherwise.
- `fvm flutter …` means the **ohos** Flutter SDK (`fvm use ohos --force`
  selects it; check with `fvm flutter --version` → `3.27.4`, Dart `3.6.2`).
- `<ohos-device>` is a target from `hdc list targets` (emulator or USB device).
- `YOUR_KEY` is your Google Maps API key (see [`api-keys.md`](api-keys.md)).
