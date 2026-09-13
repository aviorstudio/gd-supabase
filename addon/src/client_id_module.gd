## Non-authentication client ID generation with explicit Web persistence.
class_name ClientIdModule
extends RefCounted

enum WebStorageMode {
	MEMORY,
	SESSION_STORAGE,
}

class ClientIdConfig extends RefCounted:
	var storage_key: String = "app_client_id"
	var prefix: String = "web_"
	## Memory is the safe default. sessionStorage is script-accessible opt-in.
	var web_storage_mode: int = WebStorageMode.MEMORY

static var _web_memory: Dictionary[String, String] = {}

## Returns a stable ID for the current process/tab. It is never authentication.
static func get_client_id(config: ClientIdConfig = null) -> String:
	if not OS.has_feature("web"):
		return OS.get_unique_id()
	var resolved := config if config != null else ClientIdConfig.new()
	if resolved.storage_key.is_empty():
		return ""
	if resolved.web_storage_mode == WebStorageMode.SESSION_STORAGE:
		return _get_session_storage_id(resolved)
	if resolved.web_storage_mode != WebStorageMode.MEMORY:
		return ""
	if _web_memory.has(resolved.storage_key):
		return _web_memory[resolved.storage_key]
	var generated := resolved.prefix + _random_id()
	_web_memory[resolved.storage_key] = generated
	return generated

static func _get_session_storage_id(config: ClientIdConfig) -> String:
	var storage: JavaScriptObject = JavaScriptBridge.get_interface("sessionStorage")
	if storage == null:
		return ""
	var existing: Variant = storage.call("getItem", config.storage_key)
	if existing is String and not str(existing).is_empty():
		return str(existing)
	var generated := config.prefix + _random_id()
	storage.call("setItem", config.storage_key, generated)
	var checked: Variant = storage.call("getItem", config.storage_key)
	return str(checked) if checked is String and str(checked) == generated else ""

static func _random_id() -> String:
	if OS.has_feature("web"):
		var crypto_interface: JavaScriptObject = JavaScriptBridge.get_interface("crypto")
		if crypto_interface != null:
			var uuid: Variant = crypto_interface.call("randomUUID")
			if uuid is String and not str(uuid).is_empty():
				return str(uuid)
	var random_bytes := Crypto.new().generate_random_bytes(16)
	return random_bytes.hex_encode()
