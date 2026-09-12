extends SceneTree

func _init() -> void:
	push_error("deliberate assertion failure")
	quit(1)
	print("TEST_REACHED:assertion_overwrite:1")
	quit()
