extends SceneTree

const ClientIdModule = preload("res://addon/src/client_id_module.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_native_client_id_path()
	quit()

func _test_native_client_id_path() -> void:
	if OS.has_feature("web"):
		return
	var id_a: String = ClientIdModule.get_client_id()
	var id_b: String = ClientIdModule.get_client_id()
	_assert(not id_a.is_empty(), "native client id should not be empty")
	_assert(id_a == id_b, "native client id should be stable across calls")
	_assert(id_a == OS.get_unique_id(), "native client id should use OS unique id")

func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
