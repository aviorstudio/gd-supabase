## Cross-platform client ID generation and persistence helper.
class_name ClientIdModule
extends RefCounted

## Runtime configuration for web storage behavior.
class ClientIdConfig extends RefCounted:
	## localStorage key used on web platforms.
	var storage_key: String = "app_client_id"
	## Prefix applied to generated web IDs.
	var prefix: String = "web_"

## Returns a stable client ID for current platform.
static func get_client_id(config: ClientIdConfig = null) -> String:
	if OS.has_feature("web"):
		return _get_web_client_id(_resolve_config(config))
	return OS.get_unique_id()

static func _resolve_config(config: ClientIdConfig) -> ClientIdConfig:
	if config != null:
		return config
	return ClientIdConfig.new()

static func _get_web_client_id(config: ClientIdConfig) -> String:
	var existing_value: String = str(JavaScriptBridge.eval("localStorage.getItem('%s')" % config.storage_key, true))
	if existing_value != "null" and not existing_value.is_empty():
		return existing_value
	var new_id: String = _generate_web_id(config.prefix)
	JavaScriptBridge.eval("localStorage.setItem('%s', '%s')" % [config.storage_key, new_id], true)
	return new_id

static func _generate_web_id(prefix: String) -> String:
	var uuid: String = str(JavaScriptBridge.eval("(typeof crypto !== 'undefined' && crypto.randomUUID) ? crypto.randomUUID() : ''", true))
	if uuid != "null" and not uuid.is_empty():
		return prefix + uuid
	return prefix + str(Time.get_ticks_msec()) + "_" + str(randi()) + "_" + str(randi())
