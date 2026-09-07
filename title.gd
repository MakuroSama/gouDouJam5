extends Control

@onready var start_button: Button = $VBoxContainer/StartButton
@onready var record_button: Button = $VBoxContainer/RecordButton
@onready var quit_button: Button = $VBoxContainer/QuitButton

func _ready():
	start_button.pressed.connect(_on_start_button_pressed)
	record_button.pressed.connect(_on_record_button_pressed)
	quit_button.pressed.connect(_on_quit_button_pressed)

func _on_start_button_pressed():
	get_tree().change_scene_to_file("res://MainScene.tscn")

func _on_record_button_pressed():
	print("記録ボタンが押されました")

func _on_quit_button_pressed():
	get_tree().quit()
