# OHOS native layer

The ArkTS host is small on purpose: two method channels next to the
generated plugin registrant. Everything else is Dart + WebView.

## `EntryAbility.ets`

`ohos/entry/src/main/ets/entryability/EntryAbility.ets` (128 lines):
`FlutterAbility` subclass that registers plugins, then adds:

### `io.opengmaps/location` — Location Kit

| Method | Args | Returns | Notes |
|--------|------|---------|-------|
| `checkLocationPermission` | — | `bool` | `checkAccessTokenSync` for `LOCATION` / `APPROXIMATELY_LOCATION` |
| `requestLocationPermission` | — | `bool` | System dialog (`true` if any grant); our reason string comes from `string.json: location_reason` |
| `getCurrentLocation` | — | `{latitude, longitude, altitude, accuracy, speed, bearing}` | `geoLocationManager.getCurrentLocation`, `FIRST_FIX`, `maxAccuracy 0`, 5 s timeout |

Errors use codes `LOCATION_PERMISSION_ERROR`, `LOCATION_UNAVAILABLE`,
`LOCATION_ERROR` (Dart maps them to `locationError`, never throws to UI).

### `io.opengmaps/storage` — user preferences

| Method | Args (Map) | Returns |
|--------|------------|---------|
| `getString` | `{key}` | `String?` (`null` when absent) |
| `setString` | `{key, value}` | `true` |
| `remove` | `{key}` | `true` |

Backed by `data.preferences` store `open_gmaps`, flushed on every write.
ArkTS constraint learned the hard way: **no nested functions**
(`arkts-no-nested-funcs`) — helpers are class methods with captured `self`.

## Permissions — `ohos/entry/src/main/module.json5`

`INTERNET` (maps + REST), `LOCATION` and `APPROXIMATELY_LOCATION` with
`usedScene: {abilities: [EntryAbility], when: inuse}` and the
`$string:location_reason` rationale (shown verbatim in the system dialog —
verified on-device with a screenshot).

## OHOS project layout (what matters)

```
ohos/
├── AppScope/app.json5        # bundleName io.opengmaps.open_gmaps
├── build-profile.json5       # compatibleSdkVersion 5.0.0(12), HarmonyOS, signing
├── signatures/               # committed for out-of-box builds; replace for releases
├── entry/src/main/
│   ├── module.json5          # permissions above
│   ├── ets/entryability/EntryAbility.ets
│   ├── ets/pages/Index.ets   # FlutterPage host
│   └── ets/plugins/GeneratedPluginRegistrant.ets  # InAppWebView plugin (tool-managed)
├── entry/oh-package.json5    # tool-managed native deps (inappwebview HAR)
├── oh-package.json5          # root overrides (flutter.har, entry module)
└── har/                      # flutter.har (+inappwebview HAR), toolchain-managed
```

Rules of engagement: hand-edit `EntryAbility.ets`, `module.json5`,
`AppScope/app.json5` and signing freely; treat `GeneratedPluginRegistrant`,
both `oh-package.json5` files and `har/` as **tool-owned** (the flutter
tool rewrites them on `pub get`/build — e.g. it once injected a phantom
`google_maps_flutter_ohos.har` line that had to be removed by hand; see
[`troubleshooting.md`](troubleshooting.md)). `ohos/build/`,
`ohos/oh_modules/`, `ohos/.hvigor/` are caches, git-ignored.
