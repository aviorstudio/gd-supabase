## JWT helpers for payload decoding and expiry checks (no signature verification).
class_name JwtModule
extends RefCounted

## Parsed JWT payload object.
class JwtPayload extends RefCounted:
	## JWT `sub` claim.
	var subject: String = ""
	## JWT `email` claim.
	var email: String = ""
	## JWT `exp` claim in unix seconds.
	var expires_at: int = 0
	## JWT `iat` claim in unix seconds.
	var issued_at: int = 0
	## Full decoded claim map.
	var claims: Dictionary[String, Variant] = {}

## Decodes and parses payload segment from a JWT string.
static func decode_payload(token: String) -> JwtPayload:
	var payload: JwtPayload = JwtPayload.new()
	var parts: PackedStringArray = token.split(".")
	if parts.size() < 2:
		return payload
	var payload_segment: String = _base64url_to_base64(parts[1])
	var payload_raw: PackedByteArray = Marshalls.base64_to_raw(payload_segment)
	if payload_raw.is_empty():
		return payload
	var payload_text: String = payload_raw.get_string_from_utf8()
	if payload_text.is_empty():
		return payload
	var parsed: Variant = JSON.parse_string(payload_text)
	if not (parsed is Dictionary):
		return payload
	var claims: Dictionary[String, Variant] = {}
	claims.merge(parsed)
	payload.claims = claims
	payload.subject = str(claims.get("sub", ""))
	payload.email = str(claims.get("email", ""))
	payload.expires_at = int(claims.get("exp", 0))
	payload.issued_at = int(claims.get("iat", 0))
	return payload

## Returns true when the token has a valid `exp` claim in the past.
static func is_expired(token: String, now_unix: int = -1) -> bool:
	var expiry_unix: int = get_expiry_unix(token)
	if expiry_unix <= 0:
		return false
	var now_seconds: int = now_unix if now_unix >= 0 else int(Time.get_unix_time_from_system())
	return now_seconds >= expiry_unix

## Returns token expiry timestamp (`exp`) in unix seconds, or 0 when unavailable.
static func get_expiry_unix(token: String) -> int:
	var payload: JwtPayload = decode_payload(token)
	return payload.expires_at

static func _base64url_to_base64(value: String) -> String:
	var normalized: String = value.replace("-", "+").replace("_", "/")
	var remainder: int = normalized.length() % 4
	if remainder == 2:
		normalized += "=="
	elif remainder == 3:
		normalized += "="
	elif remainder == 1:
		normalized += "==="
	return normalized
