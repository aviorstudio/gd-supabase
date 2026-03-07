# gd-supabase

Game-agnostic Supabase auth/session primitives for Godot 4.

This addon is intentionally limited to local auth/session helper primitives.

## Installation

### Via gdpm
`gdpm install @aviorstudio/gd-supabase`

### Manual
Copy this directory into `addons/@aviorstudio_gd-supabase/` and enable the plugin.

## API Reference

- `JwtModule`: decode JWT payloads and check expiration timestamps.
- `SessionStoreModule`: save/load/clear session payloads with legacy migration support.
- `ClientIdModule`: cross-platform unique client ID retrieval with configurable web storage key.

## Scope Boundary

- In scope: JWT/session/client-id helpers.
- Out of scope: full auth flow orchestration, route guards, and network request lifecycle policy.

## Testing

`./tests/test.sh`

## License

MIT