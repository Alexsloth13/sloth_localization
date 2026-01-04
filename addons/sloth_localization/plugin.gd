@tool
extends EditorPlugin

const CSVViewerDockScene: PackedScene = preload("res://addons/sloth_localization/csv_viewer_dock.tscn")
const VisibleLanguagesStateScript: Script = preload("res://addons/sloth_localization/visible_languages_state.gd")
const UpdateServiceScript: Script = preload("res://addons/sloth_localization/updater/update_service.gd")
const UpdatePopupScript: Script = preload("res://addons/sloth_localization/updater/update_popup.gd")

var dock
var visible_languages_state: Node
var update_service: Node
var update_popup: AcceptDialog

func _enter_tree():
	visible_languages_state = VisibleLanguagesStateScript.new()
	visible_languages_state.name = "SlothLocalizerState"
	get_tree().get_root().add_child(visible_languages_state)
	dock = CSVViewerDockScene.instantiate()
	dock.name = _get_plugin_name()
	# Godot 4 does not expose add_control_to_main_screen, so attach directly
	# to the main screen container.
	get_editor_interface().get_editor_main_screen().add_child(dock)
	dock.visible = false
	update_service = UpdateServiceScript.new()
	add_child(update_service)
	update_popup = UpdatePopupScript.new()
	add_child(update_popup)
	update_service.update_available.connect(_on_update_available)
	dock.check_updates_requested.connect(update_service.check_for_updates)
	update_service.check_for_updates()

func _exit_tree():
	if visible_languages_state:
		var state_parent = visible_languages_state.get_parent()
		if state_parent:
			state_parent.remove_child(visible_languages_state)
		visible_languages_state.queue_free()
		visible_languages_state = null
	if dock:
		var parent = dock.get_parent()
		if parent:
			parent.remove_child(dock)
		dock.queue_free()
		dock = null
	if update_popup:
		update_popup.queue_free()
		update_popup = null
	if update_service:
		update_service.queue_free()
		update_service = null

func _has_main_screen():
	return true

func _get_plugin_name():
	return 'Sloth Localization'

func _get_plugin_icon():
	return get_editor_interface().get_base_control().get_theme_icon('Script', 'EditorIcons')

# Godot 4 calls _make_visible when main screen changes; keep make_visible as alias for compatibility.
func _make_visible(is_visible):
	if dock:
		dock.visible = is_visible

func make_visible(is_visible):
	_make_visible(is_visible)

func _on_update_available(current_version: String, latest_version: String, release_url: String) -> void:
	if update_popup:
		update_popup.show_update(current_version, latest_version, release_url)
