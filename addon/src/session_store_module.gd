## Session storage with safe memory, injected native credential, and Web tab adapters.
class_name SessionStoreModule
extends RefCounted

const MAX_SESSION_BYTES := 1024 * 1024

enum StorageMode {
	MEMORY,
	NATIVE_CREDENTIAL,
	WEB_SESSION_STORAGE,
}

enum Status {
	OK,
	NOT_FOUND,
	NON_PERSISTENT,
	INVALID_DATA,
	TOO_LARGE,
	ADAPTER_ERROR,
	WRITE_VERIFY_FAILED,
	MIGRATION_FAILED,
	UNSUPPORTED,
}

enum CredentialReadStatus {
	FOUND,
	NOT_FOUND,
	ERROR,
}

class CredentialReadResult extends RefCounted:
	var status: int = CredentialReadStatus.NOT_FOUND
	var value: String = ""
	var error: String = ""

## Caller implementation backed by the target OS credential facility.
## `write_atomic` must replace the value atomically or leave the old value intact.
class NativeCredentialAdapter extends RefCounted:
	func read_value(_key: String) -> CredentialReadResult:
		var result := CredentialReadResult.new()
		result.status = CredentialReadStatus.ERROR
		result.error = "read_value is not implemented"
		return result

	func write_atomic(_key: String, _value: String) -> bool:
		return false

	func delete_value(_key: String) -> bool:
		return false

class SessionStoreConfig extends RefCounted:
	var storage_key: String = "gd_supabase_session_default"
	var mode: int = StorageMode.MEMORY
	var credential_adapter: NativeCredentialAdapter = null
	## Explicit legacy plaintext paths eligible for nondestructive migration.
	var legacy_paths: Array[String] = []

class OperationResult extends RefCounted:
	var status: int = Status.ADAPTER_ERROR
	var error: String = ""
	var persistent: bool = false

	func is_success() -> bool:
		return status == Status.OK or status == Status.NON_PERSISTENT

class LoadResult extends OperationResult:
	var data: Dictionary[String, Variant] = {}
	var migrated_from: String = ""

var _config: SessionStoreConfig = SessionStoreConfig.new()
var _memory: Dictionary[String, Variant] = {}

func _init(config: SessionStoreConfig = null) -> void:
	if config != null:
		_config = config

func configure(config: SessionStoreConfig) -> OperationResult:
	if config == null or config.storage_key.is_empty():
		return _operation(Status.INVALID_DATA, "storage config and key are required")
	_config = config
	_memory.clear()
	return _operation(Status.OK, "", _is_persistent_mode())

## Saves JSON-compatible session data. Memory mode succeeds explicitly as non-persistent.
func save(data: Dictionary[String, Variant]) -> OperationResult:
	if data.is_empty():
		return clear()
	var encoded := _encode_payload(data)
	if not bool(encoded.ok):
		return _operation(int(encoded.status), str(encoded.error), _is_persistent_mode())
	return _write_encoded(str(encoded.value))

func load_session() -> LoadResult:
	var read := _read_encoded()
	if not read.is_success() or read.status == Status.NOT_FOUND:
		return read
	var decoded := _decode_payload(str(read.data.get("encoded", "")))
	if not decoded.is_success():
		decoded.persistent = read.persistent
		return decoded
	decoded.persistent = read.persistent
	if not read.persistent:
		decoded.status = Status.NON_PERSISTENT
	return decoded

## Clears the active destination only. Legacy sources are never deleted.
func clear() -> OperationResult:
	match _config.mode:
		StorageMode.MEMORY:
			_memory.clear()
			return _operation(Status.NON_PERSISTENT, "", false)
		StorageMode.NATIVE_CREDENTIAL:
			if _config.credential_adapter == null:
				return _operation(Status.ADAPTER_ERROR, "native credential adapter is required", true)
			if not _config.credential_adapter.delete_value(_config.storage_key):
				return _operation(Status.ADAPTER_ERROR, "credential delete failed", true)
			var checked := _config.credential_adapter.read_value(_config.storage_key)
			if checked.status == CredentialReadStatus.FOUND:
				return _operation(Status.WRITE_VERIFY_FAILED, "credential delete readback failed", true)
			if checked.status == CredentialReadStatus.ERROR:
				return _operation(Status.ADAPTER_ERROR, checked.error, true)
			return _operation(Status.OK, "", true)
		StorageMode.WEB_SESSION_STORAGE:
			var storage := _web_storage()
			if storage == null:
				return _operation(Status.UNSUPPORTED, "sessionStorage requires a Web export with JavaScriptBridge", true)
			storage.call("removeItem", _config.storage_key)
			if typeof(storage.call("getItem", _config.storage_key)) != TYPE_NIL:
				return _operation(Status.WRITE_VERIFY_FAILED, "sessionStorage delete readback failed", true)
			return _operation(Status.OK, "", true)
	return _operation(Status.UNSUPPORTED, "unknown storage mode")

## Explicitly migrates one valid legacy file into a persistent destination.
## The source remains intact even after successful write/readback (D-08).
func migrate_legacy() -> LoadResult:
	if not _is_persistent_mode():
		return _load_error(Status.MIGRATION_FAILED, "migration requires a persistent destination", false)
	var destination := load_session()
	if destination.is_success() and not destination.data.is_empty():
		return destination
	if destination.status != Status.NOT_FOUND:
		return _load_error(Status.MIGRATION_FAILED, destination.error, true)
	for path: String in _config.legacy_paths:
		if path.is_empty() or not FileAccess.file_exists(path):
			continue
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			return _load_error(Status.MIGRATION_FAILED, "legacy source could not be opened", true)
		if file.get_length() > MAX_SESSION_BYTES:
			return _load_error(Status.MIGRATION_FAILED, "legacy source exceeds 1 MiB", true)
		var decoded := _decode_payload(file.get_as_text())
		if not decoded.is_success():
			return _load_error(Status.MIGRATION_FAILED, decoded.error, true)
		var saved := save(decoded.data)
		if not saved.is_success():
			return _load_error(Status.MIGRATION_FAILED, saved.error, true)
		var verified := load_session()
		if not verified.is_success() or verified.data != decoded.data:
			return _load_error(Status.MIGRATION_FAILED, "migration destination readback mismatch", true)
		verified.migrated_from = path
		return verified
	return _load_error(Status.NOT_FOUND, "", true)

func _write_encoded(encoded: String) -> OperationResult:
	match _config.mode:
		StorageMode.MEMORY:
			var decoded := _decode_payload(encoded)
			if not decoded.is_success():
				return _operation(decoded.status, decoded.error)
			_memory = decoded.data.duplicate(true)
			return _operation(Status.NON_PERSISTENT, "", false)
		StorageMode.NATIVE_CREDENTIAL:
			if _config.credential_adapter == null:
				return _operation(Status.ADAPTER_ERROR, "native credential adapter is required", true)
			if not _config.credential_adapter.write_atomic(_config.storage_key, encoded):
				return _operation(Status.ADAPTER_ERROR, "credential atomic write failed", true)
			var checked := _config.credential_adapter.read_value(_config.storage_key)
			if checked.status != CredentialReadStatus.FOUND or checked.value != encoded:
				return _operation(Status.WRITE_VERIFY_FAILED, "credential write readback mismatch", true)
			return _operation(Status.OK, "", true)
		StorageMode.WEB_SESSION_STORAGE:
			var storage := _web_storage()
			if storage == null:
				return _operation(Status.UNSUPPORTED, "sessionStorage requires a Web export with JavaScriptBridge", true)
			storage.call("setItem", _config.storage_key, encoded)
			var checked: Variant = storage.call("getItem", _config.storage_key)
			if not (checked is String) or str(checked) != encoded:
				return _operation(Status.WRITE_VERIFY_FAILED, "sessionStorage write readback mismatch", true)
			return _operation(Status.OK, "", true)
	return _operation(Status.UNSUPPORTED, "unknown storage mode")

func _read_encoded() -> LoadResult:
	match _config.mode:
		StorageMode.MEMORY:
			if _memory.is_empty():
				return _load_error(Status.NOT_FOUND, "", false)
			var encoded := _encode_payload(_memory)
			if not bool(encoded.ok):
				return _load_error(int(encoded.status), str(encoded.error), false)
			return _encoded_load(Status.NON_PERSISTENT, str(encoded.value), false)
		StorageMode.NATIVE_CREDENTIAL:
			if _config.credential_adapter == null:
				return _load_error(Status.ADAPTER_ERROR, "native credential adapter is required", true)
			var read := _config.credential_adapter.read_value(_config.storage_key)
			if read.status == CredentialReadStatus.NOT_FOUND:
				return _load_error(Status.NOT_FOUND, "", true)
			if read.status != CredentialReadStatus.FOUND:
				return _load_error(Status.ADAPTER_ERROR, read.error, true)
			return _encoded_load(Status.OK, read.value, true)
		StorageMode.WEB_SESSION_STORAGE:
			var storage := _web_storage()
			if storage == null:
				return _load_error(Status.UNSUPPORTED, "sessionStorage requires a Web export with JavaScriptBridge", true)
			var value: Variant = storage.call("getItem", _config.storage_key)
			if typeof(value) == TYPE_NIL:
				return _load_error(Status.NOT_FOUND, "", true)
			if not (value is String):
				return _load_error(Status.INVALID_DATA, "sessionStorage value is not a string", true)
			return _encoded_load(Status.OK, str(value), true)
	return _load_error(Status.UNSUPPORTED, "unknown storage mode", false)

func _encode_payload(data: Dictionary[String, Variant]) -> Dictionary:
	if not _is_json_value(data, []):
		return {"ok": false, "status": Status.INVALID_DATA, "error": "session payload must contain only acyclic JSON-compatible values"}
	var encoded := JSON.stringify(data)
	if encoded.is_empty() or encoded.to_utf8_buffer().size() > MAX_SESSION_BYTES:
		return {"ok": false, "status": Status.TOO_LARGE, "error": "session payload exceeds 1 MiB or cannot be encoded"}
	return {"ok": true, "value": encoded}

func _is_json_value(value: Variant, containers: Array[Variant]) -> bool:
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_STRING:
			return true
		TYPE_FLOAT:
			return is_finite(float(value))
		TYPE_ARRAY, TYPE_DICTIONARY:
			for existing: Variant in containers:
				if is_same(existing, value):
					return false
			containers.append(value)
			if value is Array:
				for item: Variant in value:
					if not _is_json_value(item, containers):
						containers.pop_back()
						return false
			else:
				for key: Variant in value:
					if not (key is String) or not _is_json_value(value[key], containers):
						containers.pop_back()
						return false
			containers.pop_back()
			return true
	return false

func _decode_payload(encoded: String) -> LoadResult:
	if encoded.to_utf8_buffer().size() > MAX_SESSION_BYTES:
		return _load_error(Status.TOO_LARGE, "stored session exceeds 1 MiB", _is_persistent_mode())
	var json := JSON.new()
	if json.parse(encoded) != OK or not (json.data is Dictionary):
		return _load_error(Status.INVALID_DATA, "stored session is not a JSON object", _is_persistent_mode())
	var data: Dictionary[String, Variant] = {}
	data.merge(json.data)
	var result := LoadResult.new()
	result.status = Status.OK
	result.data = data
	result.persistent = _is_persistent_mode()
	return result

func _web_storage() -> JavaScriptObject:
	if not OS.has_feature("web"):
		return null
	return JavaScriptBridge.get_interface("sessionStorage")

func _is_persistent_mode() -> bool:
	return _config.mode != StorageMode.MEMORY

func _operation(status: int, error: String = "", persistent: bool = false) -> OperationResult:
	var result := OperationResult.new()
	result.status = status
	result.error = error
	result.persistent = persistent
	return result

func _load_error(status: int, error: String, persistent: bool) -> LoadResult:
	var result := LoadResult.new()
	result.status = status
	result.error = error
	result.persistent = persistent
	return result

func _encoded_load(status: int, encoded: String, persistent: bool) -> LoadResult:
	var result := LoadResult.new()
	result.status = status
	result.persistent = persistent
	result.data = {"encoded": encoded}
	return result
