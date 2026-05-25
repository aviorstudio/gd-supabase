## File-backed session persistence with optional legacy path migration.
class_name SessionStoreModule
extends RefCounted

## Configuration for session storage and migration behavior.
class SessionStoreConfig extends RefCounted:
	## Format string for the target session path (`%s` receives `store_id`).
	var file_path_template: String = "user://session_%s.dat"
	## Logical session store identifier.
	var store_id: String = "default"
	## Legacy file paths to check and migrate from on first load.
	var legacy_paths: Array[String] = []

var _config: SessionStoreConfig = SessionStoreConfig.new()

## Creates a new session store instance.
func _init(config: SessionStoreConfig = null) -> void:
	if config != null:
		_config = config

## Replaces runtime config values.
func configure(config: SessionStoreConfig) -> void:
	if config == null:
		return
	_config = config

## Saves session payload to primary session path.
func save(data: Dictionary[String, Variant]) -> bool:
	if data.is_empty():
		clear()
		return true
	var file: FileAccess = FileAccess.open(_get_primary_path(), FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data))
	return true

## Loads session data from primary or legacy path; migrates legacy data to primary.
func load_session() -> Dictionary[String, Variant]:
	var resolved_path: String = _resolve_existing_path()
	if resolved_path.is_empty():
		return {}
	var file: FileAccess = FileAccess.open(resolved_path, FileAccess.READ)
	if file == null:
		return {}
	var raw: String = file.get_as_text()
	if raw.is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(raw)
	if not (parsed is Dictionary):
		clear()
		return {}
	var payload: Dictionary[String, Variant] = {}
	payload.merge(parsed)
	var primary_path: String = _get_primary_path()
	if resolved_path != primary_path:
		save(payload)
		if FileAccess.file_exists(resolved_path):
			_remove_file(resolved_path)
	return payload

## Clears persisted session files for primary and legacy paths.
func clear() -> void:
	for candidate_path: String in _get_candidate_paths():
		if FileAccess.file_exists(candidate_path):
			_remove_file(candidate_path)

## Returns true when any known session file exists.
func exists() -> bool:
	for candidate_path: String in _get_candidate_paths():
		if FileAccess.file_exists(candidate_path):
			return true
	return false

func _get_primary_path() -> String:
	return _config.file_path_template % _config.store_id

func _get_candidate_paths() -> Array[String]:
	var candidates: Array[String] = [_get_primary_path()]
	for legacy_path: String in _config.legacy_paths:
		if legacy_path.is_empty():
			continue
		if candidates.has(legacy_path):
			continue
		candidates.append(legacy_path)
	return candidates

func _resolve_existing_path() -> String:
	for candidate_path: String in _get_candidate_paths():
		if FileAccess.file_exists(candidate_path):
			return candidate_path
	return ""

func _remove_file(path: String) -> void:
	var absolute_path: String = ProjectSettings.globalize_path(path)
	DirAccess.remove_absolute(absolute_path)
