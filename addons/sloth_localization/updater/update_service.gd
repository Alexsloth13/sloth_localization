@tool
extends Node

signal update_available(current_version: String, latest_version: String, release_url: String)

const RELEASES_URL := "https://api.github.com/repos/Alexsloth13/sloth_localization/releases/latest"
const PLUGIN_CFG_PATH := "res://addons/sloth_localization/plugin.cfg"

func check_for_updates() -> void:
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_request_completed.bind(http))
	var headers := ["User-Agent: Godot"]
	var err := http.request(RELEASES_URL, headers)
	if err != OK:
		http.queue_free()

func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		http.queue_free()
		return
	var json := JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		http.queue_free()
		return
	var data = json.data
	if typeof(data) != TYPE_DICTIONARY:
		http.queue_free()
		return
	var tag_name := str(data.get("tag_name", "")).strip_edges()
	var release_url := str(data.get("html_url", "")).strip_edges()
	var latest_version := _normalize_version(tag_name)
	var current_version := _read_current_version()
	if latest_version != "" and current_version != "" and _is_newer_version(latest_version, current_version):
		update_available.emit(current_version, latest_version, release_url)
	http.queue_free()

func _read_current_version() -> String:
	var cfg := ConfigFile.new()
	if cfg.load(PLUGIN_CFG_PATH) != OK:
		return ""
	return str(cfg.get_value("plugin", "version", "")).strip_edges()

func _normalize_version(tag_name: String) -> String:
	if tag_name.begins_with("v"):
		return tag_name.substr(1).strip_edges()
	return tag_name

func _is_newer_version(latest: String, current: String) -> bool:
	var latest_parts := _parse_semver(latest)
	var current_parts := _parse_semver(current)
	if latest_parts.is_empty() or current_parts.is_empty():
		return false
	for i in range(3):
		if latest_parts[i] > current_parts[i]:
			return true
		if latest_parts[i] < current_parts[i]:
			return false
	return false

func _parse_semver(version: String) -> Array[int]:
	var parts := version.split(".")
	if parts.size() < 3:
		return []
	var numbers: Array[int] = []
	for i in range(3):
		var part := parts[i]
		if not part.is_valid_int():
			return []
		numbers.append(int(part))
	return numbers
