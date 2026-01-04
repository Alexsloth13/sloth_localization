@tool
extends Panel
class_name TranslationCard

@onready var key_icon: Label = $MarginContainer/VBoxContainer/KeyHeader/KeyIcon
@onready var key_label: Label = $MarginContainer/VBoxContainer/KeyHeader/KeyLabel
@onready var translations_container: VBoxContainer = $MarginContainer/VBoxContainer/TranslationsContainer

var translation_data: Array = []
var headers: Array = []

func _ready():
	setup_style()

func setup_style():
	# Beautiful gradient background
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0.15, 0.18, 0.25, 1.0)
	style_box.border_width_left = 2
	style_box.border_width_right = 2
	style_box.border_width_top = 2
	style_box.border_width_bottom = 2
	style_box.border_color = Color(0.4, 0.6, 0.8, 0.8)
	style_box.corner_radius_top_left = 8
	style_box.corner_radius_top_right = 8
	style_box.corner_radius_bottom_left = 8
	style_box.corner_radius_bottom_right = 8
	
	# Add shadow
	style_box.shadow_color = Color(0, 0, 0, 0.3)
	style_box.shadow_size = 4
	style_box.shadow_offset = Vector2(2, 2)
	
	add_theme_stylebox_override("panel", style_box)

func set_translation_data(data: Array, column_headers: Array):
	translation_data = data
	headers = column_headers
	if is_inside_tree():
		update_display()
	else:
		call_deferred("update_display")

func update_display():
	if translation_data.is_empty() or headers.is_empty():
		return

	# Wait for nodes to be ready
	if not key_icon or not key_label or not translations_container:
		call_deferred("update_display")
		return

	# Set key - make it clickable
	if translation_data.size() > 0:
		key_icon.text = "KEY:"

		# Convert key_label to button for clickability (if it's not already)
		if key_label is Label:
			var key_button = Button.new()
			key_button.text = str(translation_data[0])
			key_button.add_theme_font_size_override("font_size", 20)
			key_button.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
			key_button.flat = true
			key_button.alignment = HORIZONTAL_ALIGNMENT_LEFT

			# Style the key button to look like a label
			var key_style = StyleBoxFlat.new()
			key_style.bg_color = Color.TRANSPARENT
			key_button.add_theme_stylebox_override("normal", key_style)
			key_button.add_theme_stylebox_override("pressed", key_style)
			key_button.add_theme_stylebox_override("hover", key_style)
			key_button.add_theme_stylebox_override("focus", key_style)

			# Replace the label with button
			var parent = key_label.get_parent()
			parent.remove_child(key_label)
			parent.add_child(key_button)
			key_label = key_button
		else:
			key_label.text = str(translation_data[0])
			key_label.add_theme_font_size_override("font_size", 20)
			key_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	
	# Clear existing translations
	for child in translations_container.get_children():
		child.queue_free()
	
	# Add translations
	for i in range(1, min(translation_data.size(), headers.size())):
		var lang_container = HBoxContainer.new()
		lang_container.add_theme_constant_override("separation", 12)
		translations_container.add_child(lang_container)
		
		# Language panel
		var lang_panel = Panel.new()
		lang_panel.custom_minimum_size = Vector2(55, 30)
		
		var lang_style = StyleBoxFlat.new()
		lang_style.bg_color = Color(0.3, 0.4, 0.6, 0.8)
		lang_style.corner_radius_top_left = 4
		lang_style.corner_radius_top_right = 4
		lang_style.corner_radius_bottom_left = 4
		lang_style.corner_radius_bottom_right = 4
		lang_panel.add_theme_stylebox_override("panel", lang_style)
		
		var lang_label = Label.new()
		lang_label.text = headers[i].to_upper()
		lang_label.add_theme_font_size_override("font_size", 14)
		lang_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
		lang_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lang_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lang_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		lang_panel.add_child(lang_label)
		lang_container.add_child(lang_panel)
		
		# Translation text
		var translation_label = Label.new()
		translation_label.text = str(translation_data[i])
		translation_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		translation_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		translation_label.add_theme_font_size_override("font_size", 14)
		translation_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95))
		translation_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		translation_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		
		# Calculate height based on text length
		var text_lines = max(1, str(translation_data[i]).length() / 50)
		translation_label.custom_minimum_size.y = max(25, text_lines * 20)
		
		lang_container.add_child(translation_label)
