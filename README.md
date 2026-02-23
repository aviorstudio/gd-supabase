# gd-supabase

Game-agnostic Supabase auth/session primitives for Godot 4.

## Installation

### Via gdpm
`gdpm install @aviorstudio/gd-supabase`

### Manual
Copy this directory into `addons/@aviorstudio_gd-supabase/` and enable the plugin.

## API Reference

- `JwtModule`: decode JWT payloads and check expiration timestamps.
- `SessionStoreModule`: save/load/clear session payloads with legacy migration support.

## Status

Scaffolded in Phase 3 with JWT module extraction. Session/client ID modules and tests are added in subsequent steps.

## License

MIT