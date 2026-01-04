@tool
extends Control
class_name CSVViewerDock

# --- UI References (связаны через Unique Names в .tscn) ---
@onready var file_dialog: FileDialog = %FileDialog
@onready var cards_scroll_container: ScrollContainer = %CardsScrollContainer
@onready var grid_container: GridContainer = %GridContainer
@onready var filter_line_edit: LineEdit = %FilterLineEdit
@onready var prefix_filter_selector: OptionButton = %PrefixSelector
@onready var suffix_filter_selector: OptionButton = %SuffixSelector
@onready var filter_timer: Timer = %FilterTimer
@onready var file_info_label: Label = %FileInfoLabel

# Кнопки панелей
@onready var btn_open: Button = %BtnOpen
@onready var btn_save_csv: Button = %BtnSaveCSV
@onready var btn_add_key: Button = %BtnAddKey
@onready var settings_button: Button = %SettingsButton

# Пагинация (Низ)
@onready var bottom_page_size_selector: OptionButton = %BottomSizeSelector
@onready var bottom_prev_button: Button = %BottomPrevBtn
@onready var bottom_next_button: Button = %BottomNextBtn
@onready var bottom_page_label: Label = %BottomPageLabel

# Диалоги
@onready var edit_dialog: AcceptDialog = %EditDialog
@onready var inline_edit_dialog: AcceptDialog = %InlineEditDialog
@onready var rich_edit_dialog: AcceptDialog = %RichEditDialog
@onready var add_key_dialog: AcceptDialog = %AddKeyDialog
@onready var delete_confirm_dialog: ConfirmationDialog = %DeleteConfirmDialog
@onready var manage_prefixes_dialog: AcceptDialog = %ManagePrefixesDialog
@onready var manage_suffixes_dialog: AcceptDialog = %ManageSuffixesDialog

# --- Logic Variables ---
var csv_data: Array = []
var filtered_data: Array = []
var csv_headers: Array = []
var current_file_path: String = ""
var save_path = "user://sloth_localizer_settings.cfg"
var plugin_lists_path = "res://addons/sloth_localizer/prefix_suffixes.json"

# Pagination state
var page_size_options := [10, 20, 50, 100]
var page_size: int = 10
var current_page: int = 1

# Edit dialog internal state
var edit_form_fields: Dictionary = {}
var edit_form_field_indices: Array = []

# Inline editor internal state
var inline_text_edit: TextEdit
var inline_current_row: Array
var inline_current_headers: Array
var inline_current_field_index: int

# Rich text editor internal state
var rich_text_edit: RichTextLabel
var rich_input_text_edit: TextEdit 
var rich_current_row: Array
var rich_current_headers: Array
var rich_current_field_index: int
var rich_toolbar: HBoxContainer

# Add new key dialog internal state
var add_key_fields: Dictionary = {}
var add_key_prefix_selector: OptionButton # Локальный селектор для диалога добавления
var add_key_suffix_selector: OptionButton # Локальный селектор для диалога добавления
var add_key_cancel_button: Button
var add_key_original_key: String = ""
var add_key_mode: int = KEY_DIALOG_MODE_ADD

# Delete confirmation state
var delete_pending_key: String = ""

# Data Management
var prefixes_list: Array = ["__UI", "__MENU", "__GAME", "__ERROR"]
var prefix_list_container: VBoxContainer # Контейнер внутри диалога
var suffixes_list: Array = ["_TITLE", "_DESC", "_BTN", "_ERROR", "_SUCCESS"]
var suffix_list_container: VBoxContainer # Контейнер внутри диалога
var visible_languages_state: VisibleLanguagesState
var visible_language_checkboxes: Dictionary = {}

@onready var settings_overlay: Control = %SettingsOverlay
@onready var settings_panel: PanelContainer = %SettingsPanel
@onready var settings_close_button: Button = %SettingsCloseButton
@onready var settings_source_selector: OptionButton = %SettingsSourceSelector
@onready var settings_visible_grid: GridContainer = %SettingsVisibleGrid
@onready var settings_preset_selector: OptionButton = %SettingsPresetSelector
@onready var settings_manage_prefixes: Button = %SettingsManagePrefixes
@onready var settings_manage_suffixes: Button = %SettingsManageSuffixes

const LANG_PRESET_ALL := 0
const LANG_PRESET_SOURCE_ONLY := 1
const LANG_PRESET_EN_DE := 2
const LANG_PRESET_CUSTOM := 3
const KEY_DIALOG_MODE_ADD := 0
const KEY_DIALOG_MODE_EDIT := 1
const ADD_KEY_TRANSLATION_MIN_HEIGHT := 72
const ADD_KEY_SOURCE_TRANSLATION_MIN_HEIGHT := 88

func _ready():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	visible_languages_state = get_tree().get_root().get_node_or_null("SlothLocalizerState")
	if visible_languages_state:
		visible_languages_state.visible_languages_changed.connect(_on_visible_languages_changed)
		visible_languages_state.available_languages_changed.connect(_on_available_languages_changed)
		visible_languages_state.source_language_changed.connect(_on_source_language_changed)
	
	# Подключение сигналов основных кнопок
	btn_open.pressed.connect(_on_open_file_pressed)
	btn_save_csv.pressed.connect(_on_save_csv_pressed)
	btn_add_key.pressed.connect(_on_add_new_key_pressed)
	settings_button.pressed.connect(_on_settings_button_pressed)
	settings_close_button.pressed.connect(_close_settings_panel)
	settings_overlay.gui_input.connect(_on_settings_overlay_input)
	settings_manage_prefixes.pressed.connect(_on_manage_prefixes_pressed)
	settings_manage_suffixes.pressed.connect(_on_manage_suffixes_pressed)
	settings_source_selector.item_selected.connect(_on_source_language_selected)
	settings_preset_selector.item_selected.connect(_on_preset_selected)
	
	# Подключение сигналов файлового диалога
	file_dialog.file_selected.connect(_on_file_selected)
	
	# Подключение фильтров
	filter_line_edit.text_changed.connect(_on_filter_changed)
	filter_timer.timeout.connect(_on_filter_timer_timeout)
	prefix_filter_selector.item_selected.connect(_on_prefix_filter_changed)
	suffix_filter_selector.item_selected.connect(_on_suffix_filter_changed)
	
	# Подключение диалогов (кнопки OK/Confirm)
	inline_edit_dialog.confirmed.connect(_on_inline_save_pressed)
	rich_edit_dialog.confirmed.connect(_on_rich_save_pressed_wrapper)
	add_key_dialog.confirmed.connect(_on_key_dialog_save_pressed)
	add_key_dialog.custom_action.connect(_on_add_key_custom_action)
	delete_confirm_dialog.confirmed.connect(_on_delete_key_confirmed)
	delete_confirm_dialog.canceled.connect(_on_delete_key_canceled)
	manage_prefixes_dialog.confirmed.connect(_on_prefixes_dialog_confirmed)
	manage_suffixes_dialog.confirmed.connect(_on_suffixes_dialog_confirmed)
	
	# Инициализация содержимого диалогов (создаем внутренности программно)
	_setup_inline_edit_dialog_content()
	_setup_rich_edit_dialog_content()
	_setup_manage_prefixes_dialog_content()
	_setup_manage_suffixes_dialog_content()
	_refresh_settings_languages_ui()
	
	# Настройка пагинации
	_setup_pagination_ui()
	
	# Загрузка настроек
	call_deferred("load_settings")

# --- UI Setup Helpers (наполняют пустые диалоги из .tscn) ---

func _setup_pagination_ui():
	bottom_page_size_selector.clear()
	for option in page_size_options:
		bottom_page_size_selector.add_item(str(option), option)

	bottom_prev_button.pressed.connect(func(): _change_page(-1))
	bottom_next_button.pressed.connect(func(): _change_page(1))
	bottom_page_size_selector.item_selected.connect(func(idx): _change_page_size(bottom_page_size_selector.get_item_id(idx)))

	_update_pagination_controls(0)

func _refresh_settings_languages_ui():
	for child in settings_visible_grid.get_children():
		child.queue_free()

	visible_language_checkboxes.clear()

	var available = _get_available_languages()
	_setup_language_presets()
	settings_source_selector.clear()
	for i in range(available.size()):
		var lang = str(available[i])
		settings_source_selector.add_item(lang.to_upper(), i)
		settings_source_selector.set_item_metadata(i, lang)

	var source_lang = _get_source_language()
	for i in range(settings_source_selector.item_count):
		var item_lang = str(settings_source_selector.get_item_metadata(i))
		if item_lang.to_lower() == source_lang.to_lower():
			settings_source_selector.select(i)
			break

	if available.is_empty():
		var empty_label = Label.new()
		empty_label.text = "No language columns found."
		settings_visible_grid.add_child(empty_label)
		return

	_update_visible_grid_columns()
	for lang in available:
		var cb = CheckBox.new()
		cb.text = _format_language_label(str(lang))
		cb.custom_minimum_size = Vector2(90, 0)
		cb.button_pressed = _is_language_visible(str(lang))
		if str(lang).to_lower() == source_lang.to_lower():
			cb.disabled = true
			cb.button_pressed = true
			_apply_source_language_style(cb)
		cb.toggled.connect(_on_visible_language_toggled)
		settings_visible_grid.add_child(cb)
		visible_language_checkboxes[str(lang)] = cb

	_update_preset_selection()

func _open_settings_panel():
	_refresh_settings_languages_ui()
	settings_overlay.visible = true
	_animate_settings_panel(true)

func _close_settings_panel():
	_animate_settings_panel(false)

func _animate_settings_panel(opening: bool) -> void:
	var viewport_size = size
	if viewport_size.x <= 0 or viewport_size.y <= 0:
		viewport_size = get_viewport_rect().size
	var panel_width = clamp(int(viewport_size.x * 0.62), 600, 720)
	settings_panel.custom_minimum_size = Vector2(panel_width, 0)
	settings_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var start_x = viewport_size.x if opening else viewport_size.x - panel_width
	var end_x = viewport_size.x - panel_width if opening else viewport_size.x
	settings_panel.position = Vector2(start_x, 0)

	var tween = create_tween()
	tween.tween_property(settings_panel, "position", Vector2(end_x, 0), 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if not opening:
		tween.finished.connect(func(): settings_overlay.visible = false)

func _on_settings_overlay_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var click_pos = event.position
		if click_pos.x < settings_panel.global_position.x:
			_close_settings_panel()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and settings_overlay.visible:
		_close_settings_panel()
		get_viewport().set_input_as_handled()

func _setup_language_presets():
	settings_preset_selector.clear()
	settings_preset_selector.add_item("All Languages", LANG_PRESET_ALL)
	settings_preset_selector.add_item("Source Only", LANG_PRESET_SOURCE_ONLY)
	settings_preset_selector.add_item("EN + DE", LANG_PRESET_EN_DE)
	settings_preset_selector.add_item("Custom", LANG_PRESET_CUSTOM)

func _update_preset_selection():
	var available = _get_available_languages()
	var visible = visible_languages_state.get_visible_languages() if visible_languages_state else available
	var source = _get_source_language()
	var preset_id = _derive_preset_id(available, visible, source)
	settings_preset_selector.select(preset_id)

func _derive_preset_id(available: Array, visible: Array, source: String) -> int:
	if available.is_empty():
		return LANG_PRESET_CUSTOM
	var available_set = _to_lang_set(available)
	var visible_set = _to_lang_set(visible)
	if _sets_equal(available_set, visible_set):
		return LANG_PRESET_ALL

	if source != "":
		var source_set = _to_lang_set([source])
		if _sets_equal(visible_set, source_set):
			return LANG_PRESET_SOURCE_ONLY

	var expected = _build_en_de_set(available, source)
	if _sets_equal(visible_set, expected):
		return LANG_PRESET_EN_DE

	return LANG_PRESET_CUSTOM

func _build_en_de_set(available: Array, source: String) -> Dictionary:
	var result := {}
	if source != "":
		result[_normalize_lang(source)] = true
	var en = _find_lang_by_code(available, "en")
	if en != "":
		result[_normalize_lang(en)] = true
	var de = _find_lang_by_code(available, "de")
	if de != "":
		result[_normalize_lang(de)] = true
	return result

func _on_preset_selected(id: int) -> void:
	if not visible_languages_state:
		return
	var available = _get_available_languages()
	var source = _get_source_language()
	var selected: Array = []
	match id:
		LANG_PRESET_ALL:
			selected = available.duplicate()
		LANG_PRESET_SOURCE_ONLY:
			if source != "":
				selected.append(source)
		LANG_PRESET_EN_DE:
			if source != "":
				selected.append(source)
			var en = _find_lang_by_code(available, "en")
			if en != "" and not en in selected:
				selected.append(en)
			var de = _find_lang_by_code(available, "de")
			if de != "" and not de in selected:
				selected.append(de)
		LANG_PRESET_CUSTOM:
			return
	visible_languages_state.set_visible_languages(selected)

func _update_visible_grid_columns() -> void:
	var width = settings_panel.size.x
	if width <= 0:
		width = settings_panel.custom_minimum_size.x
	var columns = clamp(int(width / 140), 2, 3)
	settings_visible_grid.columns = columns

func _find_lang_by_code(langs: Array, code: String) -> String:
	for lang in langs:
		if _normalize_lang(str(lang)) == code:
			return str(lang)
	return ""

func _normalize_lang(lang: String) -> String:
	return lang.strip_edges().to_lower()

func _to_lang_set(langs: Array) -> Dictionary:
	var set := {}
	for lang in langs:
		set[_normalize_lang(str(lang))] = true
	return set

func _sets_equal(a: Dictionary, b: Dictionary) -> bool:
	if a.size() != b.size():
		return false
	for key in a.keys():
		if not b.has(key):
			return false
	return true

func _change_page(delta: int):
	current_page += delta
	update_cards_display(csv_headers)

func _change_page_size(new_size: int):
	page_size = new_size
	current_page = 1
	_select_page_size_item(bottom_page_size_selector)
	update_cards_display(csv_headers)

func _setup_inline_edit_dialog_content():
	var main_container = VBoxContainer.new()
	main_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inline_edit_dialog.add_child(main_container)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 40)
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_container.add_child(margin)

	inline_text_edit = TextEdit.new()
	inline_text_edit.custom_minimum_size = Vector2(450, 150)
	inline_text_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inline_text_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inline_text_edit.set("wrap_mode", 2)
	inline_text_edit.set("scroll_horizontal_enabled", false)
	inline_text_edit.gui_input.connect(_on_inline_text_edit_gui_input)
	margin.add_child(inline_text_edit)

	inline_edit_dialog.get_ok_button().text = "Save"
	inline_edit_dialog.add_button("Cancel", true, "cancel_inline_edit")
	inline_edit_dialog.custom_action.connect(_on_inline_edit_custom_action)

func _setup_rich_edit_dialog_content():
	var main_container = VBoxContainer.new()
	main_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rich_edit_dialog.add_child(main_container)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 50)
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_container.add_child(margin)

	var content_vbox = VBoxContainer.new()
	content_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_vbox.add_theme_constant_override("separation", 10)
	margin.add_child(content_vbox)

	# Toolbar
	rich_toolbar = HBoxContainer.new()
	content_vbox.add_child(rich_toolbar)
	_build_rich_toolbar(rich_toolbar)

	# Preview
	rich_text_edit = RichTextLabel.new()
	rich_text_edit.custom_minimum_size = Vector2(0, 150)
	rich_text_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rich_text_edit.bbcode_enabled = true
	rich_text_edit.selection_enabled = true
	
	var preview_panel = PanelContainer.new()
	preview_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_panel.add_child(rich_text_edit)
	content_vbox.add_child(preview_panel)

	# Input
	var lbl = Label.new()
	lbl.text = "BBCode Input:"
	content_vbox.add_child(lbl)

	rich_input_text_edit = TextEdit.new()
	rich_input_text_edit.custom_minimum_size = Vector2(0, 100)
	rich_input_text_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rich_input_text_edit.text_changed.connect(_on_rich_text_input_changed)
	content_vbox.add_child(rich_input_text_edit)

func _on_settings_button_pressed():
	_open_settings_panel()

func _on_visible_language_toggled(_pressed: bool):
	if not visible_languages_state:
		return
	var selected: Array = []
	for lang in visible_language_checkboxes.keys():
		var cb: CheckBox = visible_language_checkboxes[lang]
		if cb.button_pressed:
			selected.append(lang)
	visible_languages_state.set_visible_languages(selected)

func _on_source_language_selected(index: int):
	if not visible_languages_state:
		return
	var lang = str(settings_source_selector.get_item_metadata(index))
	visible_languages_state.set_source_language(lang)

func _on_visible_languages_changed(_visible: Array):
	_refresh_settings_languages_ui()
	update_cards_display(csv_headers)

func _on_available_languages_changed(_available: Array):
	_refresh_settings_languages_ui()
	update_cards_display(csv_headers)

func _on_source_language_changed(_source: String):
	_refresh_settings_languages_ui()
	update_cards_display(csv_headers)

func _get_available_languages() -> Array:
	if visible_languages_state:
		return visible_languages_state.available_languages.duplicate()
	if csv_headers.size() > 1:
		return csv_headers.slice(1, csv_headers.size())
	return []

func _is_language_visible(language: String) -> bool:
	if visible_languages_state:
		return visible_languages_state.is_language_visible(language)
	return true

func _get_source_language() -> String:
	if visible_languages_state:
		return visible_languages_state.get_source_language()
	return ""

func _is_source_language(language: String) -> bool:
	var source = _get_source_language()
	return source != "" and source.to_lower() == language.to_lower()

func _format_language_label(language: String) -> String:
	return language.to_upper()

func _apply_source_language_style(control: Control) -> void:
	var color = Color(0.95, 0.85, 0.3, 1)
	control.add_theme_color_override("font_color", color)
	control.add_theme_color_override("font_color_pressed", color)
	control.add_theme_color_override("font_color_hover", color)
	control.add_theme_color_override("font_color_disabled", color)

func _configure_add_key_translation_field(field: TextEdit, is_source: bool) -> void:
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field.custom_minimum_size = Vector2(0, ADD_KEY_SOURCE_TRANSLATION_MIN_HEIGHT if is_source else ADD_KEY_TRANSLATION_MIN_HEIGHT)
	field.set("wrap_mode", 2)
	field.set("scroll_horizontal_enabled", false)

func _get_visible_language_indices(headers: Array) -> Array:
	var indices: Array = []
	for i in range(1, headers.size()):
		if _is_language_visible(str(headers[i])):
			indices.append(i)
	return indices

func _get_visible_language_indices_with_source_first(headers: Array) -> Array:
	var indices = _get_visible_language_indices(headers)
	var source = _get_source_language()
	if source == "":
		return indices
	var source_index = -1
	for i in indices:
		if str(headers[i]).to_lower() == source.to_lower():
			source_index = i
			break
	if source_index != -1:
		indices.erase(source_index)
		indices.insert(0, source_index)
	return indices

func _update_available_languages_state():
	if not visible_languages_state:
		return
	var languages: Array = []
	for i in range(1, csv_headers.size()):
		languages.append(str(csv_headers[i]))
	visible_languages_state.set_available_languages(languages)

func _rename_key(original_key: String, new_key: String) -> void:
	for row in csv_data:
		if row[0] == original_key:
			row[0] = new_key
			break
	for row in filtered_data:
		if row[0] == original_key:
			row[0] = new_key
			break

func _setup_manage_prefixes_dialog_content():
	var vbox = VBoxContainer.new()
	manage_prefixes_dialog.add_child(vbox)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 50)
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(margin)
	
	var content = VBoxContainer.new()
	margin.add_child(content)
	
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 200)
	content.add_child(scroll)
	
	prefix_list_container = VBoxContainer.new()
	prefix_list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(prefix_list_container)
	
	var add_box = HBoxContainer.new()
	content.add_child(add_box)
	
	var new_prefix_edit = LineEdit.new()
	new_prefix_edit.placeholder_text = "New prefix..."
	new_prefix_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_box.add_child(new_prefix_edit)
	
	var btn_add = Button.new()
	btn_add.text = "Add"
	btn_add.pressed.connect(_on_add_prefix_pressed.bind(new_prefix_edit))
	add_box.add_child(btn_add)

func _setup_manage_suffixes_dialog_content():
	var vbox = VBoxContainer.new()
	manage_suffixes_dialog.add_child(vbox)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 50)
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(margin)
	
	var content = VBoxContainer.new()
	margin.add_child(content)
	
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 200)
	content.add_child(scroll)
	
	suffix_list_container = VBoxContainer.new()
	suffix_list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(suffix_list_container)
	
	var add_box = HBoxContainer.new()
	content.add_child(add_box)
	
	var new_suffix_edit = LineEdit.new()
	new_suffix_edit.placeholder_text = "New suffix..."
	new_suffix_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_box.add_child(new_suffix_edit)
	
	var btn_add = Button.new()
	btn_add.text = "Add"
	btn_add.pressed.connect(_on_add_suffix_pressed.bind(new_suffix_edit))
	add_box.add_child(btn_add)

func _build_rich_toolbar(toolbar: HBoxContainer):
	var tags = [
		{"label": "B", "tag": "b"},
		{"label": "I", "tag": "i"},
		{"label": "U", "tag": "u"},
	]
	for t in tags:
		var btn = Button.new()
		btn.text = t.label
		btn.custom_minimum_size = Vector2(30, 0)
		btn.pressed.connect(_add_bbcode_tag.bind(t.tag))
		toolbar.add_child(btn)
	
	toolbar.add_child(VSeparator.new())
	
	var btn_color = Button.new()
	btn_color.text = "Color"
	btn_color.pressed.connect(_show_color_picker)
	toolbar.add_child(btn_color)
	
	var btn_clear = Button.new()
	btn_clear.text = "Clear Fmt"
	btn_clear.pressed.connect(_clear_formatting)
	toolbar.add_child(btn_clear)

# --- File Operations ---

func _on_open_file_pressed():
	file_dialog.popup_centered()

func _on_file_selected(path: String):
	current_file_path = path
	save_settings()
	load_csv_file(path)

func load_csv_file(path: String):
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		file_info_label.text = "Error opening file"
		return

	csv_data.clear()
	filtered_data.clear()

	var headers = []
	var line_number = 0

	while not file.eof_reached():
		var line = file.get_line().strip_edges()
		if line.is_empty():
			continue

		var row = parse_csv_line(line)

		if line_number == 0:
			headers = row
		else:
			csv_data.append(row)

		line_number += 1

	file.close()

	csv_headers = headers.duplicate()
	filtered_data = csv_data.duplicate()
	current_page = 1
	_update_available_languages_state()
	update_cards_display(csv_headers)
	update_file_info_display()

func parse_csv_line(line: String) -> Array:
	var result = []
	var current_field = ""
	var in_quotes = false
	var i = 0

	while i < line.length():
		var char = line[i]

		if char == '"':
			if in_quotes and i + 1 < line.length() and line[i + 1] == '"':
				current_field += '"'
				i += 1
			else:
				in_quotes = !in_quotes
		elif char == ',' and not in_quotes:
			result.append(_decode_escaped_newlines(current_field.strip_edges()))
			current_field = ""
		else:
			current_field += char
		i += 1

	result.append(_decode_escaped_newlines(current_field.strip_edges()))
	return result

func _on_save_csv_pressed():
	if current_file_path.is_empty():
		return

	var file = FileAccess.open(current_file_path, FileAccess.WRITE)
	if file == null:
		return

	if csv_headers.size() > 0:
		var header_line = ""
		for i in range(csv_headers.size()):
			if i > 0: header_line += ","
			header_line += _escape_csv_field(csv_headers[i])
		file.store_line(header_line)

	for row in csv_data:
		var row_line = ""
		for i in range(row.size()):
			if i > 0: row_line += ","
			row_line += _escape_csv_field(str(row[i]))
		file.store_line(row_line)

	file.close()

func _escape_csv_field(field: String) -> String:
	field = _encode_newlines(field)
	if field.contains(",") or field.contains("\"") or field.contains("\n"):
		return "\"" + field.replace("\"", "\"\"") + "\""
	return field

func _encode_newlines(text: String) -> String:
	return text.replace("\r\n", "\n").replace("\n", "\\n")

func _decode_escaped_newlines(text: String) -> String:
	return text.replace("\\n", "\n")

func update_file_info_display():
	if current_file_path != "":
		file_info_label.text = "File: " + current_file_path.get_file()
	else:
		file_info_label.text = "No file loaded"

# --- Filtering ---

func _on_filter_changed(_text: String):
	filter_timer.stop()
	filter_timer.start()

func _on_filter_timer_timeout():
	apply_filters()

func _on_prefix_filter_changed(_index: int):
	apply_filters()

func _on_suffix_filter_changed(_index: int):
	apply_filters()

func apply_filters():
	filtered_data.clear()

	var text_filter = filter_line_edit.text
	var prefix_filter_index = prefix_filter_selector.selected
	var suffix_filter_index = suffix_filter_selector.selected

	for row in csv_data:
		if _should_include_row(row, text_filter, prefix_filter_index, suffix_filter_index):
			filtered_data.append(row)

	current_page = 1
	update_cards_display(csv_headers)

func _should_include_row(row: Array, text_filter: String, prefix_filter_index: int, suffix_filter_index: int) -> bool:
	if not text_filter.is_empty():
		var text_match = false
		for cell in row:
			if String(cell).to_lower().contains(text_filter.to_lower()):
				text_match = true
				break
		if not text_match: return false

	if prefix_filter_index > 0 and row.size() > 0:
		var key = str(row[0])
		if prefix_filter_index == 1: # "No prefix"
			for prefix in prefixes_list:
				if key.begins_with(prefix): return false
		else:
			var prefix = prefixes_list[prefix_filter_index - 2]
			if not key.begins_with(prefix): return false

	if suffix_filter_index > 0 and row.size() > 0:
		var key = str(row[0])
		if suffix_filter_index == 1: # "No suffix"
			for suffix in suffixes_list:
				if key.ends_with(suffix): return false
		else:
			var suffix = suffixes_list[suffix_filter_index - 2]
			if not key.ends_with(suffix): return false

	return true

# --- Display & Cards ---

func update_cards_display(headers: Array, preserve_scroll: bool = false, previous_scroll: int = 0):
	if not preserve_scroll:
		cards_scroll_container.scroll_vertical = 0

	for child in grid_container.get_children():
		child.queue_free()

	var total_items := filtered_data.size()
	if total_items == 0:
		_update_pagination_controls(0)
		return

	var display_headers := headers.duplicate()
	if display_headers.is_empty() and csv_data.size() > 0:
		for i in range(csv_data[0].size()):
			display_headers.append("Col " + str(i + 1))

	var visible_language_indices = _get_visible_language_indices_with_source_first(display_headers)
	var total_pages := max(1, int(ceil(float(total_items) / float(page_size))))
	current_page = clamp(current_page, 1, total_pages)
	var start_index := (current_page - 1) * page_size
	var end_index := min(start_index + page_size, total_items)

	for i in range(start_index, end_index):
		var row = filtered_data[i]
		var card = create_translation_card(row, display_headers, visible_language_indices)
		grid_container.add_child(card)

	_update_pagination_controls(total_items)
	if preserve_scroll:
		cards_scroll_container.scroll_vertical = previous_scroll

func _update_pagination_controls(total_items: int) -> void:
	var total_pages: int = max(1, int(ceil(float(total_items) / float(page_size))))
	current_page = clamp(current_page, 1, total_pages)
	var label_text: String = "Page %d / %d - %d items" % [current_page, total_pages, total_items]

	bottom_page_label.text = label_text

	var at_first: bool = current_page <= 1
	var at_last: bool = current_page >= total_pages

	bottom_prev_button.disabled = at_first
	bottom_next_button.disabled = at_last

	_select_page_size_item(bottom_page_size_selector)

func _select_page_size_item(selector: OptionButton) -> void:
	for i in range(selector.item_count):
		if selector.get_item_id(i) == page_size:
			selector.select(i)
			return

func create_translation_card(row_data: Array, headers: Array, visible_language_indices: Array) -> Control:
	var card = PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.18, 0.25, 1.0)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.4, 0.6, 0.8, 0.5)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	card.add_theme_stylebox_override("panel", style)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	card.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	# Key Header
	var key_header = HBoxContainer.new()
	vbox.add_child(key_header)

	var lbl = Label.new()
	lbl.text = "KEY:"
	lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	key_header.add_child(lbl)

	if row_data.size() > 0:
		var key_rich = RichTextLabel.new()
		key_rich.bbcode_enabled = true
		key_rich.fit_content = true
		key_rich.scroll_active = false
		key_rich.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		key_rich.text = _create_colored_key_text(str(row_data[0]))
		
		# Invisible button for click
		var key_btn = Button.new()
		key_btn.flat = true
		key_btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		key_btn.pressed.connect(_open_inline_editor.bind(row_data, headers, 0))
		key_rich.add_child(key_btn)
		
		key_header.add_child(key_rich)

		var btn_edit = Button.new()
		btn_edit.text = "✏️"
		btn_edit.pressed.connect(_on_edit_translation_pressed.bind(row_data, headers))
		key_header.add_child(btn_edit)

		var btn_dup = Button.new()
		btn_dup.text = "⎘"
		btn_dup.pressed.connect(_on_duplicate_key_pressed.bind(row_data, headers))
		key_header.add_child(btn_dup)

		var btn_del = Button.new()
		btn_del.text = "🗑"
		btn_del.pressed.connect(_on_delete_key_pressed.bind(row_data))
		key_header.add_child(btn_del)

	# Translations
	for i in visible_language_indices:
		if i >= row_data.size() or i >= headers.size():
			continue
		var row = HBoxContainer.new()
		vbox.add_child(row)
		
		var btn_lang = Button.new()
		var lang = str(headers[i])
		btn_lang.text = _format_language_label(lang)
		btn_lang.custom_minimum_size = Vector2(50, 0)
		if _is_source_language(lang):
			_apply_source_language_style(btn_lang)
		btn_lang.pressed.connect(_open_rich_editor.bind(row_data, headers, i))
		row.add_child(btn_lang)
		
		var btn_trans = Button.new()
		btn_trans.text = str(row_data[i])
		btn_trans.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn_trans.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		btn_trans.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn_trans.flat = true
		btn_trans.pressed.connect(_open_inline_editor.bind(row_data, headers, i))
		row.add_child(btn_trans)

	return card

func _create_colored_key_text(key_text: String) -> String:
	var found_prefix = ""
	var found_suffix = ""
	var middle = key_text

	for p in prefixes_list:
		if key_text.begins_with(p):
			found_prefix = p
			middle = key_text.substr(p.length())
			break
			
	for s in suffixes_list:
		if middle.ends_with(s):
			found_suffix = s
			middle = middle.substr(0, middle.length() - s.length())
			break
			
	var txt = ""
	if found_prefix: txt += "[color=#87CEEB]" + found_prefix + "[/color]"
	txt += "[color=#FFD700]" + middle + "[/color]"
	if found_suffix: txt += "[color=#90EE90]" + found_suffix + "[/color]"
	return txt

func _split_key_parts(key_text: String) -> Dictionary:
	var found_prefix := ""
	var found_suffix := ""
	var middle := key_text

	for p in prefixes_list:
		if key_text.begins_with(p):
			found_prefix = p
			middle = key_text.substr(p.length())
			break

	for s in suffixes_list:
		if middle.ends_with(s):
			found_suffix = s
			middle = middle.substr(0, middle.length() - s.length())
			break

	var prefix_id = -1
	var suffix_id = -1
	if found_prefix != "":
		prefix_id = prefixes_list.find(found_prefix)
	if found_suffix != "":
		suffix_id = suffixes_list.find(found_suffix)

	return {
		"base_key": middle,
		"prefix_id": prefix_id,
		"suffix_id": suffix_id,
	}

func _select_option_by_id(selector: OptionButton, id: int) -> void:
	for i in range(selector.item_count):
		if selector.get_item_id(i) == id:
			selector.select(i)
			return
	selector.select(0)

# --- Dialog Interactions ---

func _open_inline_editor(row: Array, headers: Array, idx: int):
	inline_current_row = row
	inline_current_headers = headers
	inline_current_field_index = idx
	
	if idx < row.size():
		inline_text_edit.text = str(row[idx])
	else:
		inline_text_edit.text = ""
		
	inline_edit_dialog.title = "Edit: " + (headers[idx] if idx < headers.size() else "Value")
	var viewport_size = get_viewport_rect().size
	var dialog_width = clamp(int(viewport_size.x * 0.78), 600, 900)
	var dialog_height = clamp(int(viewport_size.y * 0.4), 220, 420)
	inline_edit_dialog.size = Vector2i(dialog_width, dialog_height)
	inline_edit_dialog.popup_centered()
	inline_text_edit.grab_focus()

func _on_inline_save_pressed():
	if inline_current_field_index >= 0 and inline_current_row:
		var new_text = _sanitize_single_line_text(inline_text_edit.text)
		_update_data_cell(inline_current_row[0], inline_current_field_index, new_text)
		var prev_scroll = cards_scroll_container.scroll_vertical
		update_cards_display(csv_headers, true, prev_scroll)

func _on_inline_text_edit_gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			_on_inline_save_pressed()
			inline_edit_dialog.hide()
			accept_event()
			return
		if event.keycode == KEY_ESCAPE:
			inline_edit_dialog.hide()
			accept_event()
			return

func _sanitize_single_line_text(text: String) -> String:
	return text.replace("\r", " ").replace("\n", " ")

func _on_inline_edit_custom_action(action: StringName) -> void:
	if action == "cancel_inline_edit":
		inline_edit_dialog.hide()

func _open_rich_editor(row: Array, headers: Array, idx: int):
	rich_current_row = row
	rich_current_headers = headers
	rich_current_field_index = idx
	
	var txt = str(row[idx]) if idx < row.size() else ""
	rich_input_text_edit.text = txt
	rich_text_edit.text = txt
	
	rich_edit_dialog.title = "Rich Edit: " + (headers[idx] if idx < headers.size() else "Value")
	rich_edit_dialog.popup_centered()

func _on_rich_text_input_changed():
	rich_text_edit.text = rich_input_text_edit.text

func _on_rich_save_pressed_wrapper():
	if rich_current_field_index >= 0 and rich_current_row:
		var new_text = rich_input_text_edit.text
		_update_data_cell(rich_current_row[0], rich_current_field_index, new_text)
		var prev_scroll = cards_scroll_container.scroll_vertical
		update_cards_display(csv_headers, true, prev_scroll)

func _update_data_cell(key_val: String, col_idx: int, new_val: String):
	# Update inside filtered
	for row in filtered_data:
		if row[0] == key_val:
			if col_idx < row.size(): row[col_idx] = new_val
			break
	# Update inside master
	for row in csv_data:
		if row[0] == key_val:
			if col_idx < row.size(): row[col_idx] = new_val
			break

func _on_edit_translation_pressed(row: Array, headers: Array):
	_open_key_dialog(KEY_DIALOG_MODE_EDIT, row)

func _on_full_edit_confirmed(original_key: String, headers: Array):
	var new_key = original_key
	if edit_form_fields.has(0):
		new_key = edit_form_fields[0].text

	for idx in edit_form_field_indices:
		if idx == 0:
			continue
		var field = edit_form_fields[idx]
		_update_data_cell(original_key, idx, field.text)

	if new_key != "" and new_key != original_key:
		_rename_key(original_key, new_key)
				
	update_cards_display(csv_headers)

# --- Add Key ---

func _on_add_new_key_pressed():
	_open_key_dialog(KEY_DIALOG_MODE_ADD, [])

func _on_duplicate_key_pressed(row_data: Array, headers: Array):
	_open_key_dialog(KEY_DIALOG_MODE_ADD, row_data)

func _open_key_dialog(mode: int, prefill_row: Array):
	if csv_headers.is_empty(): return
	
	# Clean dialog
	for child in add_key_dialog.get_children():
		if child != add_key_dialog.get_ok_button() and child != add_key_cancel_button:
			child.queue_free()
	add_key_fields.clear()
	add_key_original_key = ""
	add_key_mode = mode
	add_key_dialog.title = "Add New Translation Key" if mode == KEY_DIALOG_MODE_ADD else "Edit Translation"
	add_key_dialog.get_ok_button().text = "Add Key" if mode == KEY_DIALOG_MODE_ADD else "Save"
	if not add_key_cancel_button or not is_instance_valid(add_key_cancel_button):
		add_key_cancel_button = add_key_dialog.add_button("Cancel", true, "cancel_add_key")

	var viewport_size = get_viewport_rect().size
	var dialog_width = clamp(int(viewport_size.x * 0.75), 640, 720)
	var dialog_height = clamp(int(viewport_size.y * 0.78), 480, 720)
	add_key_dialog.size = Vector2i(dialog_width, dialog_height)

	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_bottom", 50)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 12)
	add_key_dialog.add_child(margin)

	var root = VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)

	var key_label = Label.new()
	key_label.text = "Key"
	root.add_child(key_label)

	var key_row = HBoxContainer.new()
	key_row.add_theme_constant_override("separation", 8)
	root.add_child(key_row)
	
	add_key_prefix_selector = OptionButton.new()
	add_key_prefix_selector.add_item("No Prefix", -1)
	for p_idx in range(prefixes_list.size()):
		add_key_prefix_selector.add_item(prefixes_list[p_idx], p_idx)
	key_row.add_child(add_key_prefix_selector)
	
	var key_input = LineEdit.new()
	key_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	key_row.add_child(key_input)
	add_key_fields[0] = key_input
	
	add_key_suffix_selector = OptionButton.new()
	add_key_suffix_selector.add_item("No Suffix", -1)
	for s_idx in range(suffixes_list.size()):
		add_key_suffix_selector.add_item(suffixes_list[s_idx], s_idx)
	key_row.add_child(add_key_suffix_selector)

	var translations_label = Label.new()
	translations_label.text = "Translations"
	root.add_child(translations_label)

	var visible_indices = _get_visible_language_indices_with_source_first(csv_headers)

	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)

	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 8)
	scroll.add_child(vbox)
	
	if visible_indices.is_empty():
		var empty_label = Label.new()
		empty_label.text = "No visible languages selected."
		vbox.add_child(empty_label)
	else:
		for i in visible_indices:
			if i <= 0 or i >= csv_headers.size():
				continue
			var row = HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			vbox.add_child(row)

			var label = Label.new()
			var lang = str(csv_headers[i])
			label.text = _format_language_label(lang)
			label.custom_minimum_size = Vector2(60, 0)
			var is_source = _is_source_language(lang)
			if is_source:
				_apply_source_language_style(label)
			row.add_child(label)
			
			var te = TextEdit.new()
			_configure_add_key_translation_field(te, is_source)
			row.add_child(te)
			add_key_fields[i] = te

	if prefill_row.size() > 0:
		add_key_original_key = str(prefill_row[0])
		var parts = _split_key_parts(add_key_original_key)
		_select_option_by_id(add_key_prefix_selector, parts["prefix_id"])
		_select_option_by_id(add_key_suffix_selector, parts["suffix_id"])
		key_input.text = parts["base_key"]

		for idx in add_key_fields.keys():
			if idx == 0:
				continue
			if idx < prefill_row.size():
				add_key_fields[idx].text = str(prefill_row[idx])

	if add_key_fields.has(0):
		add_key_fields[0].grab_focus()
			
	add_key_dialog.popup_centered()

func _on_key_dialog_save_pressed():
	if not add_key_fields.has(0):
		return

	var key_base = add_key_fields[0].text
	var p_idx = add_key_prefix_selector.selected
	var s_idx = add_key_suffix_selector.selected
	var prefix = prefixes_list[add_key_prefix_selector.get_item_id(p_idx)] if p_idx > 0 else ""
	var suffix = suffixes_list[add_key_suffix_selector.get_item_id(s_idx)] if s_idx > 0 else ""
	var full_key = prefix + key_base + suffix
	if full_key.is_empty():
		return

	if add_key_mode == KEY_DIALOG_MODE_ADD:
		if add_key_original_key != "" and full_key == add_key_original_key:
			return
		for row in csv_data:
			if row.size() > 0 and row[0] == full_key:
				return

		var new_row = []
		for i in range(csv_headers.size()):
			new_row.append("")
		new_row[0] = full_key
		for idx in add_key_fields.keys():
			if idx == 0:
				continue
			new_row[idx] = add_key_fields[idx].text
		csv_data.append(new_row)
		filtered_data.append(new_row)
	else:
		if add_key_original_key == "":
			return
		var target_key = add_key_original_key
		if full_key != add_key_original_key:
			for row in csv_data:
				if row.size() > 0 and row[0] == full_key:
					return
			_rename_key(add_key_original_key, full_key)
			target_key = full_key
		for idx in add_key_fields.keys():
			if idx == 0:
				continue
			_update_data_cell(target_key, idx, add_key_fields[idx].text)

	update_cards_display(csv_headers, true, cards_scroll_container.scroll_vertical)

func _on_add_key_custom_action(action: StringName):
	if action == "cancel_add_key":
		add_key_dialog.hide()

# --- Delete Key ---

func _on_delete_key_pressed(row: Array):
	if row.size() > 0:
		delete_pending_key = row[0]
		delete_confirm_dialog.dialog_text = "Delete key '" + delete_pending_key + "'?"
		delete_confirm_dialog.popup_centered()

func _on_delete_key_confirmed():
	if delete_pending_key:
		for i in range(csv_data.size() -1, -1, -1):
			if csv_data[i][0] == delete_pending_key:
				csv_data.remove_at(i)
		for i in range(filtered_data.size() -1, -1, -1):
			if filtered_data[i][0] == delete_pending_key:
				filtered_data.remove_at(i)
		
		update_cards_display(csv_headers)
		delete_pending_key = ""

func _on_delete_key_canceled():
	delete_pending_key = ""

# --- Managers (Prefix/Suffix) ---

func _on_manage_prefixes_pressed():
	_refresh_list_container(prefix_list_container, prefixes_list, _delete_prefix_at)
	manage_prefixes_dialog.popup_centered()

func _on_manage_suffixes_pressed():
	_refresh_list_container(suffix_list_container, suffixes_list, _delete_suffix_at)
	manage_suffixes_dialog.popup_centered()

func _refresh_list_container(container: VBoxContainer, data_list: Array, delete_callback: Callable):
	for c in container.get_children(): c.queue_free()
	for i in range(data_list.size()):
		var hb = HBoxContainer.new()
		container.add_child(hb)
		var lbl = Label.new()
		lbl.text = data_list[i]
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.add_child(lbl)
		var btn = Button.new()
		btn.text = "X"
		btn.pressed.connect(delete_callback.bind(i))
		hb.add_child(btn)

func _delete_prefix_at(idx: int):
	if idx >= 0 and idx < prefixes_list.size():
		prefixes_list.remove_at(idx)
		_refresh_list_container(prefix_list_container, prefixes_list, _delete_prefix_at)
		_save_prefixes_to_settings()
		_update_filter_selectors()

func _delete_suffix_at(idx: int):
	if idx >= 0 and idx < suffixes_list.size():
		suffixes_list.remove_at(idx)
		_refresh_list_container(suffix_list_container, suffixes_list, _delete_suffix_at)
		_save_suffixes_to_settings()
		_update_filter_selectors()

func _on_add_prefix_pressed(le: LineEdit):
	var txt = le.text.strip_edges()
	if txt and not txt in prefixes_list:
		prefixes_list.append(txt)
		le.clear()
		_refresh_list_container(prefix_list_container, prefixes_list, _delete_prefix_at)
		_save_prefixes_to_settings()
		_update_filter_selectors()

func _on_add_suffix_pressed(le: LineEdit):
	var txt = le.text.strip_edges()
	if txt and not txt in suffixes_list:
		suffixes_list.append(txt)
		le.clear()
		_refresh_list_container(suffix_list_container, suffixes_list, _delete_suffix_at)
		_save_suffixes_to_settings()
		_update_filter_selectors()

func _on_prefixes_dialog_confirmed(): pass
func _on_suffixes_dialog_confirmed(): pass

func _update_filter_selectors():
	# Update Main UI Selectors
	prefix_filter_selector.clear()
	prefix_filter_selector.add_item("All")
	prefix_filter_selector.add_item("No Prefix")
	for p in prefixes_list: prefix_filter_selector.add_item(p)
	
	suffix_filter_selector.clear()
	suffix_filter_selector.add_item("All")
	suffix_filter_selector.add_item("No Suffix")
	for s in suffixes_list: suffix_filter_selector.add_item(s)

# --- Settings ---

func save_settings():
	var config = ConfigFile.new()
	config.set_value("settings", "last_file", current_file_path)
	config.save(save_path)

func load_settings():
	var config = ConfigFile.new()
	var err = config.load(save_path)
	if err == OK:
		current_file_path = config.get_value("settings", "last_file", "")
		if current_file_path != "" and FileAccess.file_exists(current_file_path):
			call_deferred("load_csv_file", current_file_path)

	_load_plugin_lists()
	_update_filter_selectors()

func _save_prefixes_to_settings():
	_save_plugin_lists()

func _save_suffixes_to_settings():
	_save_plugin_lists()

func _load_plugin_lists() -> void:
	if not FileAccess.file_exists(plugin_lists_path):
		return
	var file = FileAccess.open(plugin_lists_path, FileAccess.READ)
	if not file:
		return
	var content = file.get_as_text()
	var data = JSON.parse_string(content)
	if typeof(data) != TYPE_DICTIONARY:
		return
	if data.has("prefixes") and data["prefixes"] is Array:
		prefixes_list = data["prefixes"].duplicate()
	if data.has("suffixes") and data["suffixes"] is Array:
		suffixes_list = data["suffixes"].duplicate()

func _save_plugin_lists() -> void:
	var data = {
		"prefixes": prefixes_list,
		"suffixes": suffixes_list,
	}
	var file = FileAccess.open(plugin_lists_path, FileAccess.WRITE)
	if not file:
		return
	file.store_string(JSON.stringify(data, "\t"))

# --- Formatting Helpers ---

func _add_bbcode_tag(tag: String):
	if not rich_input_text_edit: return
	var sel = rich_input_text_edit.get_selected_text()
	if sel:
		var wrap = "["+tag+"]" + sel + "[/"+tag+"]"
		rich_input_text_edit.insert_text_at_caret(wrap)
	else:
		var wrap = "["+tag+"][/"+tag+"]"
		rich_input_text_edit.insert_text_at_caret(wrap)

func _show_color_picker():
	# Simplified insertion
	if rich_input_text_edit:
		rich_input_text_edit.insert_text_at_caret("[color=red][/color]")

func _clear_formatting():
	if rich_input_text_edit:
		var txt = rich_input_text_edit.text
		var regex = RegEx.new()
		regex.compile("\\[.*?\\]")
		rich_input_text_edit.text = regex.sub(txt, "", true)
