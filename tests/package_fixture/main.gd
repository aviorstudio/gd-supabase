extends Node

const ClientIdModule = preload("res://addons/@aviorstudio_gd-supabase/src/client_id_module.gd")
const JwtModule = preload("res://addons/@aviorstudio_gd-supabase/src/jwt_module.gd")
const SessionStoreModule = preload("res://addons/@aviorstudio_gd-supabase/src/session_store_module.gd")

func _ready() -> void:
	print("PACKAGE_PLATFORM:%s:web=%s" % [OS.get_name(), OS.has_feature("web")])
	var token := "eyJhbGciOiJIUzI1NiJ9.eyJleHAiOjQxMDI0NDQ4MDB9.c2ln"
	var expiry := JwtModule.get_expiry_hint(token, 2000)
	var passed := expiry.status == JwtModule.ExpiryStatus.VALID and not expiry.trusted
	if not OS.has_feature("web"):
		passed = passed and not ClientIdModule.get_client_id().is_empty()
	else:
		var storage: JavaScriptObject = JavaScriptBridge.get_interface("sessionStorage")
		var client_key := "client'\nkey"
		storage.call("removeItem", client_key)
		var memory_config := ClientIdModule.ClientIdConfig.new()
		memory_config.storage_key = client_key
		var memory_id := ClientIdModule.get_client_id(memory_config)
		passed = passed and not memory_id.is_empty() and memory_id == ClientIdModule.get_client_id(memory_config)
		passed = passed and typeof(storage.call("getItem", client_key)) == TYPE_NIL
		var tab_config := ClientIdModule.ClientIdConfig.new()
		tab_config.storage_key = client_key
		tab_config.web_storage_mode = ClientIdModule.WebStorageMode.SESSION_STORAGE
		var tab_id := ClientIdModule.get_client_id(tab_config)
		passed = passed and not tab_id.is_empty() and storage.call("getItem", client_key) == tab_id

		var session_config := SessionStoreModule.SessionStoreConfig.new()
		session_config.mode = SessionStoreModule.StorageMode.WEB_SESSION_STORAGE
		session_config.storage_key = "session'\nkey"
		var session_store := SessionStoreModule.new(session_config)
		var saved: SessionStoreModule.OperationResult = session_store.save({"access_token": "web-test", "refresh_token": "web-refresh"})
		var loaded: SessionStoreModule.LoadResult = session_store.load_session()
		passed = passed and saved.status == SessionStoreModule.Status.OK and loaded.status == SessionStoreModule.Status.OK
		passed = passed and loaded.data.get("access_token") == "web-test"
	$Status.text = "PACKAGED GD-SUPABASE: PASS" if passed else "PACKAGED GD-SUPABASE: FAIL"
	print("PACKAGE_SMOKE_REACHED:%s" % ("PASS" if passed else "FAIL"))
	if not passed:
		get_tree().quit(1)
