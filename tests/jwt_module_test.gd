extends SceneTree

const JwtModule = preload("res://src/jwt_module.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_decode_payload_extracts_claims()
	_test_get_expiry_and_is_expired()
	quit()

func _test_decode_payload_extracts_claims() -> void:
	var token: String = _build_jwt({
		"sub": "user-1",
		"email": "player@example.com",
		"exp": int(Time.get_unix_time_from_system()) + 3600,
		"iat": int(Time.get_unix_time_from_system())
	})
	var payload: JwtModule.JwtPayload = JwtModule.decode_payload(token)
	_assert(payload.subject == "user-1", "subject should decode from JWT payload")
	_assert(payload.email == "player@example.com", "email should decode from JWT payload")
	_assert(payload.expires_at > 0, "exp should decode from JWT payload")
	_assert(payload.issued_at > 0, "iat should decode from JWT payload")

func _test_get_expiry_and_is_expired() -> void:
	var future_expiry: int = int(Time.get_unix_time_from_system()) + 120
	var token: String = _build_jwt({"exp": future_expiry})
	_assert(JwtModule.get_expiry_unix(token) == future_expiry, "get_expiry_unix should return exp claim")
	_assert(not JwtModule.is_expired(token, future_expiry - 1), "token should not be expired before exp")
	_assert(JwtModule.is_expired(token, future_expiry), "token should be expired at exp")

func _build_jwt(claims: Dictionary[String, Variant]) -> String:
	var header_json: String = JSON.stringify({"alg": "HS256", "typ": "JWT"})
	var payload_json: String = JSON.stringify(claims)
	var header_segment: String = _to_base64url(header_json.to_utf8_buffer())
	var payload_segment: String = _to_base64url(payload_json.to_utf8_buffer())
	return "%s.%s.signature" % [header_segment, payload_segment]

func _to_base64url(raw: PackedByteArray) -> String:
	var encoded: String = Marshalls.raw_to_base64(raw)
	encoded = encoded.replace("+", "-").replace("/", "_")
	while encoded.ends_with("="):
		encoded = encoded.substr(0, encoded.length() - 1)
	return encoded

func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
