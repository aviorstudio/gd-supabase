extends SceneTree

const JwtModule = preload("res://addon/src/jwt_module.gd")

var _failures := 0
var _assertions := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_unverified_metadata()
	_test_typed_expiry()
	_test_malformed_tokens()
	_test_claim_types_and_bounds()
	print("TEST_REACHED:jwt_module_test:%d" % _assertions)
	quit(1 if _failures > 0 else 0)

func _test_unverified_metadata() -> void:
	var token := _build_jwt({"sub": "user-1", "email": "玩家@example.com", "exp": 2000, "iat": 1000})
	var result: JwtModule.InspectionResult = JwtModule.inspect_unverified(token)
	_assert(result.is_valid(), "valid compact JWT should be structurally inspectable")
	_assert(not result.metadata.trusted, "decoded metadata must always be explicitly untrusted")
	_assert(result.metadata.claims.get("sub") == "user-1", "subject is available only in untrusted claims")
	_assert(result.metadata.claims.get("email") == "玩家@example.com", "Unicode claims should decode losslessly")
	_assert(not result.metadata.has_method("authorize"), "unverified metadata must expose no authorization API")

func _test_typed_expiry() -> void:
	var token := _build_jwt({"exp": 2000})
	var valid: JwtModule.ExpiryResult = JwtModule.get_expiry_hint(token, 1999)
	var expired: JwtModule.ExpiryResult = JwtModule.get_expiry_hint(token, 2000)
	var missing: JwtModule.ExpiryResult = JwtModule.get_expiry_hint(_build_jwt({}), 1000)
	var invalid: JwtModule.ExpiryResult = JwtModule.get_expiry_hint(_build_jwt({"exp": "2000"}), 1000)
	_assert(valid.status == JwtModule.ExpiryStatus.VALID and not valid.trusted, "future exp should be a valid untrusted hint")
	_assert(expired.status == JwtModule.ExpiryStatus.EXPIRED, "exp equal to now should be expired with selected zero skew")
	_assert(missing.status == JwtModule.ExpiryStatus.INVALID_OR_UNKNOWN, "missing exp must be invalid/unknown")
	_assert(invalid.status == JwtModule.ExpiryStatus.INVALID_OR_UNKNOWN, "non-numeric exp must be invalid/unknown")

func _test_malformed_tokens() -> void:
	_assert(JwtModule.inspect_unverified("not-a-token").status == JwtModule.InspectionStatus.INVALID_STRUCTURE, "wrong segment count should fail")
	_assert(JwtModule.inspect_unverified("a.%.c").status == JwtModule.InspectionStatus.INVALID_BASE64URL, "invalid base64url should fail")
	_assert(JwtModule.inspect_unverified("%s.%s.%%" % [_json_segment({"alg": "HS256"}), _json_segment({})]).status == JwtModule.InspectionStatus.INVALID_BASE64URL, "invalid signature base64url should fail")
	var invalid_utf8 := _to_base64url(PackedByteArray([0xff, 0xfe]))
	_assert(JwtModule.inspect_unverified("%s.%s.c2ln" % [_json_segment({"alg": "HS256"}), invalid_utf8]).status == JwtModule.InspectionStatus.INVALID_UTF8, "invalid UTF-8 should fail")
	_assert(JwtModule.inspect_unverified("%s.%s.c2ln" % [_json_segment({"alg": "HS256"}), _to_base64url("[]".to_utf8_buffer())]).status == JwtModule.InspectionStatus.INVALID_JSON, "non-object payload should fail")
	_assert(JwtModule.inspect_unverified(_build_jwt({}, "none")).status == JwtModule.InspectionStatus.INVALID_HEADER, "none algorithm should fail structural policy")
	_assert(JwtModule.inspect_unverified("x".repeat(JwtModule.MAX_TOKEN_BYTES + 1)).status == JwtModule.InspectionStatus.TOKEN_TOO_LARGE, "token over 64 KiB should fail before decoding")

func _test_claim_types_and_bounds() -> void:
	_assert(JwtModule.inspect_unverified(_build_jwt({"sub": 123})).status == JwtModule.InspectionStatus.INVALID_CLAIMS, "non-string subject should fail")
	_assert(JwtModule.get_expiry_hint(_build_jwt({"exp": -1})).status == JwtModule.ExpiryStatus.INVALID_OR_UNKNOWN, "negative exp should fail")
	_assert(JwtModule.get_expiry_hint(_build_jwt({"exp": 9007199254740992.0})).status == JwtModule.ExpiryStatus.INVALID_OR_UNKNOWN, "exp beyond exact JSON integer range should fail")
	_assert(JwtModule.get_expiry_hint(_build_jwt({"exp": 1.5})).status == JwtModule.ExpiryStatus.INVALID_OR_UNKNOWN, "fractional exp should fail")

func _build_jwt(claims: Dictionary, algorithm: String = "HS256") -> String:
	return "%s.%s.%s" % [_json_segment({"alg": algorithm, "typ": "JWT"}), _json_segment(claims), _to_base64url("signature".to_utf8_buffer())]

func _json_segment(value: Variant) -> String:
	return _to_base64url(JSON.stringify(value).to_utf8_buffer())

func _to_base64url(raw: PackedByteArray) -> String:
	return Marshalls.raw_to_base64(raw).replace("+", "-").replace("/", "_").trim_suffix("=").trim_suffix("=")

func _assert(condition: bool, message: String) -> void:
	_assertions += 1
	if condition:
		return
	_failures += 1
	push_error(message)
