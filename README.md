<!-- Generated from private documentation source. Do not edit directly. Source SHA256: b7ce90c835863605ba43ba2346dfd0f0368419b2d669a82dd0d4dc00ab2658b5 -->

# gd-supabase

> **Deprecated.** The session store, client ID and JWT helpers this addon
> carried were a copy of a backend-neutral core that now lives in
> [`@aviorstudio/gd-session`](https://github.com/aviorstudio/gd-session).
> Nothing Supabase-specific remains here, so no further releases are planned:
> install `gd-session` instead (`gdam add @aviorstudio/gd-session`). The
> releases below stay published for projects that pin them.

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

**Usage note:** the earlier example called nonexistent `get_or_create_client_id()`. The compiling API is `get_client_id()`. Native uses `OS.get_unique_id()`; Web defaults to process memory and allows explicit `sessionStorage` opt-in through `ClientIdConfig.web_storage_mode`.

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


## License

See `LICENSE`.

## Contributor commands

Install [mise](https://mise.jdx.dev/), then run:

```sh
mise run setup
mise run build
mise run test
```

`mise run help` lists the implemented commands offline. Mise pins SDK versions; the canonical generated Mise task block pins the shared cookbook. `mise run build` packages and verifies outputs, and `mise run test` runs the declared checks without rebuilding. Run `mise run build` again after changing source before packaged integration or browser tests. `mise run fmt` formats addon and test source; intentional invalid fixtures remain unchanged. `mise run clean` removes declared generated outputs.
