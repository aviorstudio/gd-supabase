# gd-supabase

Game-agnostic Supabase auth/session primitives for Godot 4.

This addon is intentionally limited to local auth/session helper primitives.

## Installation

### Via gdpm
`gdpm install @aviorstudio/gd-supabase`

### Manual
Copy `addon/` into `addons/@aviorstudio_gd-supabase/` and enable the plugin.

## API Reference

- `JwtModule`: decode JWT payloads and check expiration timestamps.
- `SessionStoreModule`: save/load/clear session payloads with legacy migration support.
- `ClientIdModule`: cross-platform unique client ID retrieval with configurable web storage key.

## Quick Start

```gdscript
const JwtModule = preload("res://addons/@aviorstudio_gd-supabase/src/jwt_module.gd")
const SessionStoreModule = preload("res://addons/@aviorstudio_gd-supabase/src/session_store_module.gd")

var store := SessionStoreModule.new()
store.save({"access_token": token})
var session := store.load_session()
var expired := JwtModule.is_expired(str(session.get("access_token", "")))
```

## Scope Boundary

- In scope: JWT/session/client-id helpers.
- Out of scope: full auth flow orchestration, route guards, and network request lifecycle policy.

## Security Boundary

`JwtModule` decodes JWT payloads but does not verify signatures. `SessionStoreModule` stores local JSON-like session payloads; games own refresh, revoke, encryption, and platform-specific credential policy.

## Testing

`./tests/test.sh`

## License

MIT
