extends Node

const ClientIdModule = preload("res://addons/@aviorstudio_gd-supabase/src/client_id_module.gd")
const JwtModule = preload("res://addons/@aviorstudio_gd-supabase/src/jwt_module.gd")

func _ready() -> void:
	print("PACKAGE_PLATFORM:%s:web=%s" % [OS.get_name(), OS.has_feature("web")])
	var token := "eyJhbGciOiJIUzI1NiJ9.eyJleHAiOjQxMDI0NDQ4MDB9.signature"
	var passed := JwtModule.get_expiry_unix(token) == 4102444800
	if not OS.has_feature("web"):
		passed = passed and not ClientIdModule.get_client_id().is_empty()
	$Status.text = "PACKAGED GD-SUPABASE: PASS" if passed else "PACKAGED GD-SUPABASE: FAIL"
	print("PACKAGE_SMOKE_REACHED:%s" % ("PASS" if passed else "FAIL"))
	if OS.has_feature("web"):
		var document: JavaScriptObject = JavaScriptBridge.get_interface("document")
		document.set("title", "GD Supabase Web %s" % ("PASS" if passed else "FAIL"))
	if not passed:
		get_tree().quit(1)
