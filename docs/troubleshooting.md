# Troubleshooting

## Emulator image downloads are geo-fenced

`Emulator -install` fails with *"Currently, this capability is available
only in the Chinese mainland."* Huawei's `drcn` image server filters by
IP. Options: CN VPN/proxy (`Emulator -config -http_proxy …`), DevEco
Studio on a CN network, or a physical OHOS device over USB. The SDK
previewer is ArkUI-only, not a Flutter target.

## `hdc` can't see the device

- `hdc list targets` empty after a server restart → `hdc tconn 127.0.0.1:5555`
  (emulator default), then re-list.
- Stale `Offline` entries → `hdc kill`, wait, re-list/reconnect.

## Tool crash: `Cannot resolve symbolic links` (`ohos_plugins_manager`)

A dependency declares an `ohos` plugin module whose directory doesn't
exist. Our backport is intentionally **Dart-only** (no `ohos/` dir, no
`flutter.plugin` block — see its pubspec note); if you re-add a federated
declaration, you must also ship the native shell.

## `ohpm … google_maps_flutter_ohos.har does not exist`

Stale tool-generated line in `ohos/entry/oh-package.json5` (the tool adds
HAR refs on `pub get` and doesn't clean them). Delete the
`google_maps_flutter_ohos` line and rebuild. Treat both `oh-package.json5`
files and `har/` as tool-owned; hand-edit only when they go stale like this.

## `hvigorw` exit 255 / `CompileArkTS` failure

Read past the third-party WARN noise: the real error is the
`ArkTS Compiler Error` line naming your file. The classic self-inflicted
one is **`arkts-no-nested-funcs`** — function declarations inside methods
are illegal; hoist helpers to class methods (we hit this in
`EntryAbility.ets`).

## `SignHap 00303116` / signing errors

Signing ships pre-configured (`ohos/build-profile.json5` +
`ohos/signatures/`). If you regenerate materials, API-level passwords must
be ≥ 32 chars, and DevEco's auto-sign remains the easy path (open `ohos/`
→ Project Structure → Signing Configs).

## App won't spawn / `get bundle info failed`

The emulator session is wedged (we watched AMS accept starts while forking
nothing). `hdc uninstall io.opengmaps.open_gmaps`; if that fails too,
make a fresh emulator — the old one was unrecoverable in our case.

## `flutter run` hangs with no output

Known flakiness waiting on the observatory. Use the deterministic flow:
`flutter build hap` → `hdc install` → `aa start` (see
[`getting-started.md`](getting-started.md)).

## Blank/grey map with a key set

1. Confirm the define reached the build (typo in `GOOGLE_MAPS_API_KEY=`).
2. Confirm the 4 APIs + billing in Cloud Console ([`api-keys.md`](api-keys.md)).
3. Look for the red in-app banner (tap dismisses) — auth failures
   (`gm_authFailure`) land there with Google's reason.
4. `hilog`: `ohosError` / `flutter_inappwebview` traffic tells you whether
   the page, the key, or the network is at fault.

## `JAVA_HOME` / major-version errors

OHOS builds need JDK 17 (`/opt/homebrew/opt/openjdk@17`); other majors
break `hvigor`.

## `0.0.0-unknown` Flutter version

Old FVM quirk (`git tag` the ohos SDK). Harmless if `flutter --version`
already reports `3.27.4`.

## Lockfile churn between `ohos` and stable Flutter

Expected — different resolvers. Keep the `ohos`-pinned `pubspec.lock`
committed; don't commit a stable-resolved one.
