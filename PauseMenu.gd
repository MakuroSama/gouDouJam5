extends CanvasLayer

@onready var gear_button: TextureButton = $GearButton
@onready var overlay: Control = $Overlay
@onready var resume_button: Button = $Overlay/VBoxContainer/ResumeButton
@onready var title_button: Button = $Overlay/VBoxContainer/TitleButton

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	overlay.visible = false
	gear_button.pressed.connect(_on_gear_button_pressed)
	resume_button.pressed.connect(_on_resume_button_pressed)
	title_button.pressed.connect(_on_title_button_pressed)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if overlay.visible:
				_on_resume_button_pressed()
			else:
				_on_gear_button_pressed()

func _on_gear_button_pressed() -> void:
	overlay.visible = true
	gear_button.visible = false
	get_tree().paused = true

func _on_resume_button_pressed() -> void:
	overlay.visible = false
	gear_button.visible = true
	get_tree().paused = false

func _on_title_button_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://title.tscn")
