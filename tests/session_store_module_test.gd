extends SceneTree

const SessionStoreModule = preload("res://src/session_store_module.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_save_and_load_roundtrip()
	_test_legacy_migration()
	_test_clear_removes_files()
	quit()

func _test_save_and_load_roundtrip() -> void:
	var store: SessionStoreModule = _build_store("roundtrip")
	store.clear()
	var payload: Dictionary[String, Variant] = {
		"access_token": "token-a",
		"user_id": "user-1"
	}
	_assert(store.save(payload), "save should return true for valid payload")
	var loaded: Dictionary[String, Variant] = store.load_session()
	_assert(str(loaded.get("access_token", "")) == "token-a", "load should restore access_token")
	_assert(str(loaded.get("user_id", "")) == "user-1", "load should restore user_id")
	store.clear()

func _test_legacy_migration() -> void:
	var timestamp: int = Time.get_ticks_msec()
	var legacy_path: String = "user://legacy_session_%d.dat" % timestamp
	var config: SessionStoreModule.SessionStoreConfig = SessionStoreModule.SessionStoreConfig.new()
	config.file_path_template = "user://session_%s.dat"
	config.store_id = "legacy_%d" % timestamp
	config.legacy_paths = [legacy_path]
	var store: SessionStoreModule = SessionStoreModule.new(config)
	store.clear()

	var legacy_file: FileAccess = FileAccess.open(legacy_path, FileAccess.WRITE)
	_assert(legacy_file != null, "legacy path should open for migration test")
	if legacy_file != null:
		legacy_file.store_string(JSON.stringify({"access_token": "legacy-token"}))
	legacy_file = null

	var loaded: Dictionary[String, Variant] = store.load_session()
	_assert(str(loaded.get("access_token", "")) == "legacy-token", "load should read legacy payload")
	_assert(not FileAccess.file_exists(legacy_path), "legacy file should be deleted after migration")
	store.clear()

func _test_clear_removes_files() -> void:
	var store: SessionStoreModule = _build_store("clear")
	store.save({"access_token": "token-clear"})
	_assert(store.exists(), "exists should be true after save")
	store.clear()
	_assert(not store.exists(), "exists should be false after clear")

func _build_store(name: String) -> SessionStoreModule:
	var config: SessionStoreModule.SessionStoreConfig = SessionStoreModule.SessionStoreConfig.new()
	config.file_path_template = "user://session_%s.dat"
	config.store_id = "%s_%d" % [name, Time.get_ticks_msec()]
	config.legacy_paths = []
	return SessionStoreModule.new(config)

func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
