extends SceneTree

const ClientIdModule = preload("res://addon/src/client_id_module.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_native_client_id_path()
	print("TEST_REACHED:client_id_module_test:3")
	quit(1 if _failures > 0 else 0)

var _failures: int = 0

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
	_failures += 1
	push_error(message)
