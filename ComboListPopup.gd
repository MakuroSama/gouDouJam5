extends Control

signal opened
signal closed

@onready var close_button: Button = get_node_or_null("CloseButton")
@onready var dark_overlay: ColorRect = get_node_or_null("DarkOverlay")
@onready var combo_image: TextureRect = get_node_or_null("ComboImage")

func _ready() -> void:
	visible = false
	if combo_image:
		combo_image.texture = load("res://Image/conbo.png")
	if close_button:
		close_button.pressed.connect(close)
	if dark_overlay:
		dark_overlay.gui_input.connect(_on_overlay_gui_input)

func _unhandled_input(event: InputEvent) -> void:
	if visible:
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			close()
			get_viewport().set_input_as_handled()

func open() -> void:
	visible = true
	if is_inside_tree():
		var sfx = get_node_or_null("/root/SfxPool")
		if sfx:
			sfx.play_sfx(preload("res://SE・BGM/SE/audiostock_400832.mp3"))
	opened.emit()

func close() -> void:
	visible = false
	if is_inside_tree():
		var sfx = get_node_or_null("/root/SfxPool")
		if sfx:
			sfx.play_sfx(preload("res://SE・BGM/SE/audiostock_1283196.mp3"))
	closed.emit()

func _on_overlay_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		close()
