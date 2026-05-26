# gd-supabase

Use Supabase-friendly session helpers in Godot 4.

This addon gives you JWT decoding, local session storage, and stable client IDs. It does not force a specific auth UI or HTTP client.

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
store.save({"access_token": token, "refresh_token": refresh_token})

var session := store.load_session()
var access_token := str(session.get("access_token", ""))

if JwtModule.is_expired(access_token):
	_refresh_session()
```

## Client ID Example

```gdscript
const ClientIdModule = preload("res://addons/@aviorstudio_gd-supabase/src/client_id_module.gd")

var client_id := ClientIdModule.get_or_create_client_id()
```

## What You Get

- `JwtModule`: decode JWT payloads and check expiration timestamps.
- `SessionStoreModule`: save, load, and clear local session dictionaries.
- `ClientIdModule`: get or create a stable client ID across supported platforms.

## Security Notes

- `JwtModule` decodes JWT payloads but does not verify signatures.
- `SessionStoreModule` stores local JSON-like session data.
- Your game owns refresh, revoke, encryption, platform credential storage, and server trust decisions.

## Testing

`./tests/test.sh`

## License

MIT
