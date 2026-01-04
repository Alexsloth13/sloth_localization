@tool
extends AcceptDialog

var _release_url := ""
var _current_label: Label
var _latest_label: Label

func _ready() -> void:
	title = "Sloth Localization Update"
	var vbox := VBoxContainer.new()
	add_child(vbox)
	_current_label = Label.new()
	_latest_label = Label.new()
	vbox.add_child(_current_label)
	vbox.add_child(_latest_label)
	add_button("Open Release Page", false, "open_release")
	get_ok_button().text = "Later"
	custom_action.connect(_on_custom_action)

func show_update(current_version: String, latest_version: String, release_url: String) -> void:
	_release_url = release_url
	_current_label.text = "Current version: %s" % current_version
	_latest_label.text = "Latest version: %s" % latest_version
	popup_centered()

func _on_custom_action(action: String) -> void:
	if action == "open_release" and _release_url != "":
		OS.shell_open(_release_url)
