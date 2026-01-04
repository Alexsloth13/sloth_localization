@tool
extends Node
class_name VisibleLanguagesState

signal visible_languages_changed(visible_languages: Array)
signal available_languages_changed(available_languages: Array)
signal source_language_changed(source_language: String)

const SETTINGS_SECTION := "settings"
const SETTINGS_KEY := "visible_languages"
const SOURCE_LANGUAGE_KEY := "source_language"

var save_path := "user://sloth_localizer_settings.cfg"
var available_languages: Array = []
var visible_languages: Array = []
var source_language: String = ""
var _has_saved_visible_languages := false

func _ready() -> void:
	_load_settings()

func set_available_languages(languages: Array) -> void:
	available_languages = languages.duplicate()
	if source_language == "" and available_languages.size() > 0:
		source_language = str(available_languages[0])
		source_language_changed.emit(source_language)
		_save_settings()
	if source_language != "" and not source_language in available_languages:
		source_language = str(available_languages[0]) if available_languages.size() > 0 else ""
		source_language_changed.emit(source_language)
		_save_settings()
	if not _has_saved_visible_languages:
		visible_languages = available_languages.duplicate()
		_ensure_source_visible()
		visible_languages_changed.emit(visible_languages)
	available_languages_changed.emit(available_languages)
	# Keep only valid selections when headers change.
	if _has_saved_visible_languages:
		var filtered := []
		for lang in visible_languages:
			if lang in available_languages:
				filtered.append(lang)
		visible_languages = filtered
		_ensure_source_visible()
		visible_languages_changed.emit(visible_languages)

func set_visible_languages(languages: Array) -> void:
	visible_languages = languages.duplicate()
	_ensure_source_visible()
	_has_saved_visible_languages = true
	_save_settings()
	visible_languages_changed.emit(visible_languages)

func set_source_language(language: String) -> void:
	source_language = language
	_ensure_source_visible()
	_save_settings()
	source_language_changed.emit(source_language)
	visible_languages_changed.emit(visible_languages)

func get_visible_languages() -> Array:
	if _has_saved_visible_languages:
		return visible_languages.duplicate()
	return available_languages.duplicate()

func get_source_language() -> String:
	return source_language

func is_language_visible(language: String) -> bool:
	if not _has_saved_visible_languages:
		return true
	return language in visible_languages

func _load_settings() -> void:
	var config = ConfigFile.new()
	if config.load(save_path) != OK:
		return
	if config.has_section_key(SETTINGS_SECTION, SETTINGS_KEY):
		visible_languages = config.get_value(SETTINGS_SECTION, SETTINGS_KEY, [])
		_has_saved_visible_languages = true
	if config.has_section_key(SETTINGS_SECTION, SOURCE_LANGUAGE_KEY):
		source_language = config.get_value(SETTINGS_SECTION, SOURCE_LANGUAGE_KEY, "")

func _save_settings() -> void:
	var config = ConfigFile.new()
	config.load(save_path)
	config.set_value(SETTINGS_SECTION, SETTINGS_KEY, visible_languages)
	config.set_value(SETTINGS_SECTION, SOURCE_LANGUAGE_KEY, source_language)
	config.save(save_path)

func _ensure_source_visible() -> void:
	if source_language == "":
		return
	if not source_language in visible_languages:
		visible_languages.append(source_language)
