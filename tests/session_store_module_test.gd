extends SceneTree

const SessionStoreModule = preload("res://addon/src/session_store_module.gd")

class FakeCredentialAdapter extends SessionStoreModule.NativeCredentialAdapter:
	const READ_FOUND := 0
	const READ_NOT_FOUND := 1
	const READ_ERROR := 2
	var values: Dictionary[String, String] = {}
	var fail_write := false
	var fail_read := false
	var corrupt_read := false
	var fail_delete := false

	func read_value(key: String):
		var result = super.read_value(key)
		if fail_read:
			result.status = READ_ERROR
			result.error = "injected read failure"
		elif not values.has(key):
			result.status = READ_NOT_FOUND
		else:
			result.status = READ_FOUND
			result.value = "{\"corrupt\":true}" if corrupt_read else values[key]
		return result

	func write_atomic(key: String, value: String) -> bool:
		if fail_write:
			return false
		values[key] = value
		return true

	func delete_value(key: String) -> bool:
		if fail_delete:
			return false
		values.erase(key)
		return true

var _failures := 0
var _assertions := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_memory_default()
	_test_credential_roundtrip_and_logout()
	_test_atomic_failure_and_readback()
	_test_invalid_and_bounded_payloads()
	_test_nondestructive_migration()
	_test_failed_migration_retains_source()
	_test_platform_mode()
	print("TEST_REACHED:session_store_module_test:%d" % _assertions)
	quit(1 if _failures > 0 else 0)

func _test_memory_default() -> void:
	var store := SessionStoreModule.new()
	var saved := store.save({"access_token": "memory-token"})
	var loaded := store.load_session()
	_assert(saved.status == SessionStoreModule.Status.NON_PERSISTENT and saved.is_success(), "default save should explicitly report memory-only success")
	_assert(loaded.status == SessionStoreModule.Status.NON_PERSISTENT and loaded.data.access_token == "memory-token", "memory load should return typed non-persistent data")
	_assert(SessionStoreModule.new().load_session().status == SessionStoreModule.Status.NOT_FOUND, "memory sessions must not survive a new store instance")

func _test_credential_roundtrip_and_logout() -> void:
	var adapter := FakeCredentialAdapter.new()
	var store := _credential_store(adapter, "roundtrip")
	_assert(store.save({"access_token": "token-a", "refresh_token": "token-b"}).status == SessionStoreModule.Status.OK, "credential save should pass write/readback")
	var loaded := store.load_session()
	_assert(loaded.status == SessionStoreModule.Status.OK and loaded.persistent and loaded.data.refresh_token == "token-b", "credential load should be typed and persistent")
	_assert(store.save({"writer": 1}).is_success() and store.save({"writer": 2}).is_success() and store.load_session().data.writer == 2, "sequential concurrent writers should commit the last complete value")
	_assert(store.clear().status == SessionStoreModule.Status.OK, "logout clear should delete the active credential")
	_assert(store.load_session().status == SessionStoreModule.Status.NOT_FOUND, "logout clear should not leave an active session")

func _test_atomic_failure_and_readback() -> void:
	var adapter := FakeCredentialAdapter.new()
	var store := _credential_store(adapter, "atomic")
	_assert(store.save({"value": "old"}).is_success(), "control credential write should pass")
	adapter.fail_write = true
	_assert(store.save({"value": "new"}).status == SessionStoreModule.Status.ADAPTER_ERROR, "failed atomic write should be visible")
	adapter.fail_write = false
	_assert(store.load_session().data.value == "old", "failed atomic write must preserve the old value")
	adapter.corrupt_read = true
	_assert(store.save({"value": "checked"}).status == SessionStoreModule.Status.WRITE_VERIFY_FAILED, "partial/corrupt write readback should fail")

func _test_invalid_and_bounded_payloads() -> void:
	var adapter := FakeCredentialAdapter.new()
	var store := _credential_store(adapter, "bounds")
	var huge := "x".repeat(SessionStoreModule.MAX_SESSION_BYTES + 1)
	_assert(store.save({"value": huge}).status == SessionStoreModule.Status.TOO_LARGE, "serialized sessions over 1 MiB should fail")
	adapter.values["bounds"] = "not-json"
	_assert(store.load_session().status == SessionStoreModule.Status.INVALID_DATA, "malformed stored JSON should be typed invalid")
	var unsupported := Object.new()
	_assert(store.save({"unsupported": unsupported}).status == SessionStoreModule.Status.INVALID_DATA, "lossy non-JSON values should fail")
	unsupported.free()
	var cycle: Array = []
	cycle.append(cycle)
	_assert(store.save({"cycle": cycle}).status == SessionStoreModule.Status.INVALID_DATA, "cyclic session data should fail without recursive serialization")
	cycle.clear()

func _test_nondestructive_migration() -> void:
	var path := "user://gd_supabase_legacy_success_%d.json" % Time.get_ticks_msec()
	_write_legacy(path, {"access_token": "legacy-token"})
	var adapter := FakeCredentialAdapter.new()
	var store := _credential_store(adapter, "migration", [path])
	var migrated := store.migrate_legacy()
	_assert(migrated.status == SessionStoreModule.Status.OK and migrated.migrated_from == path, "migration should require committed destination readback")
	_assert(migrated.data.access_token == "legacy-token", "migration should return committed data")
	_assert(FileAccess.file_exists(path), "legacy source must remain after successful migration without destructive approval")
	store.clear()
	_assert(store.load_session().status == SessionStoreModule.Status.NOT_FOUND, "logout must not automatically resurrect retained legacy data")
	_remove(path)

func _test_failed_migration_retains_source() -> void:
	var path := "user://gd_supabase_legacy_failure_%d.json" % Time.get_ticks_msec()
	_write_legacy(path, {"access_token": "legacy-token"})
	var adapter := FakeCredentialAdapter.new()
	adapter.fail_write = true
	var migrated := _credential_store(adapter, "migration-fail", [path]).migrate_legacy()
	_assert(migrated.status == SessionStoreModule.Status.MIGRATION_FAILED, "destination failure should be typed migration failure")
	_assert(FileAccess.file_exists(path), "failed migration must never delete its source")
	_remove(path)

func _test_platform_mode() -> void:
	var native_config := SessionStoreModule.SessionStoreConfig.new()
	native_config.mode = SessionStoreModule.StorageMode.NATIVE_CREDENTIAL
	_assert(SessionStoreModule.new(native_config).save({"value": "native"}).status == SessionStoreModule.Status.ADAPTER_ERROR, "missing native credential adapter should be typed")
	var config := SessionStoreModule.SessionStoreConfig.new()
	config.mode = SessionStoreModule.StorageMode.WEB_SESSION_STORAGE
	var result := SessionStoreModule.new(config).save({"value": "native"})
	_assert(result.status == SessionStoreModule.Status.UNSUPPORTED, "sessionStorage mode should be explicitly unsupported on native")

func _credential_store(adapter: FakeCredentialAdapter, key: String, legacy: Array[String] = []) -> SessionStoreModule:
	var config := SessionStoreModule.SessionStoreConfig.new()
	config.mode = SessionStoreModule.StorageMode.NATIVE_CREDENTIAL
	config.storage_key = key
	config.credential_adapter = adapter
	config.legacy_paths = legacy
	return SessionStoreModule.new(config)

func _write_legacy(path: String, value: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	_assert(file != null, "legacy fixture should open")
	if file != null:
		file.store_string(JSON.stringify(value))

func _remove(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _assert(condition: bool, message: String) -> void:
	_assertions += 1
	if condition:
		return
	_failures += 1
	push_error(message)
