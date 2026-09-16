# gd-supabase

Use Supabase-friendly session helpers in Godot 4.

This addon gives you explicitly unverified JWT metadata, adapter-based session storage, and non-authentication client IDs. It does not force a specific auth UI or HTTP client.

## Installation

### Via gdam

`gdam install @aviorstudio/gd-supabase`

### Manual

Copy `addon/` into `res://addons/@aviorstudio_gd-supabase/` and enable the plugin.

## Quick Start

```gdscript
const JwtModule = preload("res://addons/@aviorstudio_gd-supabase/src/jwt_module.gd")
const SessionStoreModule = preload("res://addons/@aviorstudio_gd-supabase/src/session_store_module.gd")

var store := SessionStoreModule.new()
var saved: SessionStoreModule.OperationResult = store.save({
	"access_token": token,
	"refresh_token": refresh_token,
})
if not saved.is_success():
	push_error(saved.error)

var loaded: SessionStoreModule.LoadResult = store.load_session()
var access_token := str(loaded.data.get("access_token", ""))

var expiry: JwtModule.ExpiryResult = JwtModule.get_expiry_hint(access_token)
if expiry.status == JwtModule.ExpiryStatus.EXPIRED:
	_refresh_session()
```

The default session store is memory-only and reports `NON_PERSISTENT`. For native persistence, inject a `SessionStoreModule.NativeCredentialAdapter` implemented with the target OS credential facility and select `NATIVE_CREDENTIAL`. For Web persistence, explicitly select `WEB_SESSION_STORAGE`; browser `sessionStorage` is script-accessible and is not a secure keystore.

## Client ID Example

```gdscript
const ClientIdModule = preload("res://addons/@aviorstudio_gd-supabase/src/client_id_module.gd")

var client_id := ClientIdModule.get_client_id()
```

**Correction ([fieldsofrevik#155](https://github.com/aviorstudio/fieldsofrevik/issues/155)):** the earlier example called nonexistent `get_or_create_client_id()`. The compiling API is `get_client_id()`. Native uses `OS.get_unique_id()`; Web defaults to process memory and allows explicit `sessionStorage` opt-in through `ClientIdConfig.web_storage_mode`.

## What You Get

- `JwtModule`: structurally inspect unverified JWT metadata and return typed expiry hints.
- `SessionStoreModule`: typed memory, injected native credential, and explicit Web tab storage.
- `ClientIdModule`: non-authentication client IDs with explicit Web persistence.

## Security Notes

- `JwtModule` does not verify signatures. Its claims and expiry are untrusted scheduling/display hints and must never establish identity or authorization.
- Native persistence exists only through a caller-injected OS credential adapter. There is no plaintext or bundled-key encryption fallback.
- Web defaults to memory. Explicit `sessionStorage` is accessible to page scripts and is not a secure keystore; sessions do not use `localStorage`.
- Session payloads are lossless JSON objects bounded to 1 MiB; JWT inputs are bounded to 64 KiB. The caller owns refresh, revoke, server verification, and trust decisions.
- Legacy plaintext migration is explicit, requires destination write/readback success, and never deletes the source in this release.

## Repository Layout

- `addon/`: Godot plugin source packaged for GDAM and manual installation.
- `addon/plugin.cfg`: plugin name, version, description, and entry script.
- `addon/src/`: reusable GDScript modules.
- `tests/`: Godot test project/scripts for addon behavior.
- `.github/workflows/ci.yml`: validates package shape and runs tests.
- `.github/workflows/release.yml`: creates GitHub release ZIPs and publishes to GDAM.

## Versioning And Releases

The version in `addon/plugin.cfg` is the addon package version. Releases are created from `main` with the manual release workflow and plain semver tags like `v0.0.1`; the workflow verifies `plugin.cfg`, builds `@aviorstudio_gd-supabase.zip`, and publishes `@aviorstudio/gd-supabase` to GDAM.

## Testing

Run locally with:

```sh
./tests/test.sh
```

**Correction ([fieldsofrevik#155](https://github.com/aviorstudio/fieldsofrevik/issues/155)):** the earlier “when available” wording overstated a skippable gate. CI and release now require the same Godot 4.7.2 suite, negative/restored gate controls, a closed-manifest ZIP, installed-package editor lifecycle checks, and a packaged Web smoke test. Release uploads the exact tested ZIP plus its SHA-256 rather than rebuilding it.

## License

MIT

### Publication contract gate

`npm ci && npm run test:publish` checks the release workflow against immutable
GDAM action metadata, including failing/restored unsupported-input controls and
an offline CLI-stub publication test. CI and release run this before the existing
package/native/Web gates and before the publication job receives registry
credentials. `publish.version` is not an action input: registry release identity
comes from the exact `tag`. The valid `install.version` is pinned to GDAM v0.0.8,
and the Linux executable checksum is verified before publishing. The ZIP asset
is explicit because releases also include checksum and browser evidence assets.
Upgrading either contract requires updating its versioned fixtures and pins.
