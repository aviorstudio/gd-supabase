## Strict JWT inspection for explicitly unverified metadata hints.
## This module never verifies signatures and must not be used for authorization.
class_name JwtModule
extends RefCounted

const MAX_TOKEN_BYTES := 64 * 1024
const MAX_EXACT_JSON_INTEGER := 9007199254740991

enum InspectionStatus {
	OK,
	TOKEN_TOO_LARGE,
	INVALID_STRUCTURE,
	INVALID_BASE64URL,
	INVALID_UTF8,
	INVALID_JSON,
	INVALID_HEADER,
	INVALID_CLAIMS,
}

enum ExpiryStatus {
	VALID,
	EXPIRED,
	INVALID_OR_UNKNOWN,
}

## Header and claims decoded without signature verification.
class UnverifiedMetadata extends RefCounted:
	var header: Dictionary[String, Variant] = {}
	var claims: Dictionary[String, Variant] = {}
	## Always false. Kept explicit so metadata cannot be mistaken for verified identity.
	var trusted: bool = false

## Typed result of structural JWT inspection.
class InspectionResult extends RefCounted:
	var status: int = InspectionStatus.INVALID_STRUCTURE
	var metadata: UnverifiedMetadata = UnverifiedMetadata.new()
	var error: String = ""

	func is_valid() -> bool:
		return status == InspectionStatus.OK

## Typed unverified expiry hint.
class ExpiryResult extends RefCounted:
	var status: int = ExpiryStatus.INVALID_OR_UNKNOWN
	var expires_at: int = 0
	var error: String = ""
	## Always false: expiry parsing is not signature verification.
	var trusted: bool = false

## Inspects a compact JWT. Claims are untrusted metadata only.
static func inspect_unverified(token: String) -> InspectionResult:
	if token.to_utf8_buffer().size() > MAX_TOKEN_BYTES:
		return _inspection_error(InspectionStatus.TOKEN_TOO_LARGE, "token exceeds 64 KiB")
	var parts: PackedStringArray = token.split(".", true)
	if parts.size() != 3 or parts[0].is_empty() or parts[1].is_empty() or parts[2].is_empty():
		return _inspection_error(InspectionStatus.INVALID_STRUCTURE, "JWT must contain three non-empty segments")
	if not _is_base64url(parts[2]) or parts[2].length() % 4 == 1:
		return _inspection_error(InspectionStatus.INVALID_BASE64URL, "invalid signature base64url segment")

	var header_result: Dictionary = _decode_json_object(parts[0])
	if not bool(header_result.get("ok", false)):
		return _inspection_error(int(header_result.status), str(header_result.error))
	var payload_result: Dictionary = _decode_json_object(parts[1])
	if not bool(payload_result.get("ok", false)):
		return _inspection_error(int(payload_result.status), str(payload_result.error))

	var header: Dictionary = header_result.value
	var claims: Dictionary = payload_result.value
	if not (header.get("alg") is String) or str(header.get("alg")).is_empty() or str(header.get("alg")).to_lower() == "none":
		return _inspection_error(InspectionStatus.INVALID_HEADER, "JWT alg must be a non-empty, non-none string")
	for claim_name: String in ["sub", "email"]:
		if claims.has(claim_name) and not (claims[claim_name] is String):
			return _inspection_error(InspectionStatus.INVALID_CLAIMS, "%s must be a string" % claim_name)
	for claim_name: String in ["exp", "iat"]:
		if claims.has(claim_name) and not _is_safe_nonnegative_integer(claims[claim_name]):
			return _inspection_error(InspectionStatus.INVALID_CLAIMS, "%s must be an exact non-negative JSON integer" % claim_name)

	var result := InspectionResult.new()
	result.status = InspectionStatus.OK
	result.metadata.header.merge(header)
	result.metadata.claims.merge(claims)
	return result

## Returns a typed expiry result. It is an unverified scheduling hint, not auth.
static func get_expiry_hint(token: String, now_unix: int = -1) -> ExpiryResult:
	var inspected := inspect_unverified(token)
	if not inspected.is_valid():
		return _expiry_error(inspected.error)
	if not inspected.metadata.claims.has("exp"):
		return _expiry_error("exp claim is missing")
	var expiry_value: Variant = inspected.metadata.claims.exp
	if not _is_safe_nonnegative_integer(expiry_value) or int(expiry_value) <= 0:
		return _expiry_error("exp claim is invalid")
	var result := ExpiryResult.new()
	result.expires_at = int(expiry_value)
	var now_seconds := now_unix if now_unix >= 0 else int(Time.get_unix_time_from_system())
	result.status = ExpiryStatus.EXPIRED if now_seconds >= result.expires_at else ExpiryStatus.VALID
	return result

static func _decode_json_object(segment: String) -> Dictionary:
	if not _is_base64url(segment) or segment.length() % 4 == 1:
		return {"ok": false, "status": InspectionStatus.INVALID_BASE64URL, "error": "invalid base64url segment"}
	var normalized := segment.replace("-", "+").replace("_", "/")
	while normalized.length() % 4 != 0:
		normalized += "="
	var raw := Marshalls.base64_to_raw(normalized)
	if raw.is_empty():
		return {"ok": false, "status": InspectionStatus.INVALID_BASE64URL, "error": "empty decoded segment"}
	var canonical := Marshalls.raw_to_base64(raw).replace("+", "-").replace("/", "_").trim_suffix("=").trim_suffix("=")
	if canonical != segment:
		return {"ok": false, "status": InspectionStatus.INVALID_BASE64URL, "error": "non-canonical base64url segment"}
	if not _is_valid_utf8(raw):
		return {"ok": false, "status": InspectionStatus.INVALID_UTF8, "error": "segment is not valid UTF-8"}
	var text := raw.get_string_from_utf8()
	var json := JSON.new()
	if json.parse(text) != OK:
		return {"ok": false, "status": InspectionStatus.INVALID_JSON, "error": "segment is not valid JSON"}
	if not (json.data is Dictionary):
		return {"ok": false, "status": InspectionStatus.INVALID_JSON, "error": "segment JSON must be an object"}
	return {"ok": true, "value": json.data}

static func _is_base64url(value: String) -> bool:
	for index: int in value.length():
		var code := value.unicode_at(index)
		var allowed := (code >= 65 and code <= 90) or (code >= 97 and code <= 122) or (code >= 48 and code <= 57) or code == 45 or code == 95
		if not allowed:
			return false
	return not value.is_empty()

static func _is_safe_nonnegative_integer(value: Variant) -> bool:
	if not (value is int or value is float):
		return false
	var number := float(value)
	return is_finite(number) and number >= 0.0 and number <= MAX_EXACT_JSON_INTEGER and floor(number) == number

static func _is_valid_utf8(raw: PackedByteArray) -> bool:
	var index := 0
	while index < raw.size():
		var first := raw[index]
		if first <= 0x7f:
			index += 1
			continue
		var continuation_count := 0
		var second_min := 0x80
		var second_max := 0xbf
		if first >= 0xc2 and first <= 0xdf:
			continuation_count = 1
		elif first >= 0xe0 and first <= 0xef:
			continuation_count = 2
			if first == 0xe0:
				second_min = 0xa0
			elif first == 0xed:
				second_max = 0x9f
		elif first >= 0xf0 and first <= 0xf4:
			continuation_count = 3
			if first == 0xf0:
				second_min = 0x90
			elif first == 0xf4:
				second_max = 0x8f
		else:
			return false
		if index + continuation_count >= raw.size():
			return false
		var second := raw[index + 1]
		if second < second_min or second > second_max:
			return false
		for offset: int in range(2, continuation_count + 1):
			var continuation := raw[index + offset]
			if continuation < 0x80 or continuation > 0xbf:
				return false
		index += continuation_count + 1
	return true

static func _inspection_error(status: int, error: String) -> InspectionResult:
	var result := InspectionResult.new()
	result.status = status
	result.error = error
	return result

static func _expiry_error(error: String) -> ExpiryResult:
	var result := ExpiryResult.new()
	result.error = error
	return result
