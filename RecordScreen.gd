extends Control

@onready var earned_value_label: Label = $VBoxContainer/EarnedBox/EarnedVBox/ValueLabel
@onready var items_value_label: Label = $VBoxContainer/ItemsBox/HBox/ValueLabel
@onready var special_value_label: Label = $VBoxContainer/SpecialBox/HBox/ValueLabel
@onready var bags_value_label: Label = $VBoxContainer/BagsBox/HBox/ValueLabel
@onready var back_button: Button = $BackButton

func _ready() -> void:
	if back_button:
		back_button.pressed.connect(_on_back_pressed)
	_update_display()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			_reset_records()

func _reset_records() -> void:
	HighScoreManager.reset_records()
	_update_display()
	var sfx = get_node_or_null("/root/SfxPool")
	if sfx:
		sfx.play_sfx(preload("res://SE・BGM/SE/audiostock_1283196.mp3"))
	print("★ 最高記録をリセットしました")

func _update_display() -> void:
	var records = HighScoreManager.get_records()
	if earned_value_label:
		earned_value_label.text = "¥ " + _format_number(records.get("max_earned_amount", 0))
	if items_value_label:
		items_value_label.text = str(records.get("max_items_count", 0)) + " 個"
	if special_value_label:
		special_value_label.text = str(records.get("max_special_count", 0)) + " 個"
	if bags_value_label:
		bags_value_label.text = str(records.get("max_bags_count", 0)) + " 枚"

func _format_number(n: int) -> String:
	var s = str(abs(n))
	var res = ""
	var count = 0
	for i in range(s.length() - 1, -1, -1):
		res = s[i] + res
		count += 1
		if count % 3 == 0 and i > 0:
			res = "," + res
	return ("-" if n < 0 else "") + res

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://title.tscn")
