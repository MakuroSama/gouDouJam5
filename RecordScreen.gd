extends Control

@onready var earned_value_label: Label = $VBoxContainer/EarnedBox/EarnedVBox/ValueLabel
@onready var items_value_label: Label = $VBoxContainer/ItemsBox/HBox/ValueLabel
@onready var special_value_label: Label = $VBoxContainer/SpecialBox/HBox/ValueLabel
@onready var bags_value_label: Label = $VBoxContainer/BagsBox/HBox/ValueLabel
@onready var back_button: Button = $BackButton

func _ready() -> void:
	if back_button:
		back_button.pressed.connect(_on_back_pressed)
	
	var records = HighScoreManager.get_records()
	earned_value_label.text = "¥ " + _format_number(records.get("max_earned_amount", 0))
	items_value_label.text = str(records.get("max_items_count", 0)) + " 個"
	special_value_label.text = str(records.get("max_special_count", 0)) + " 個"
	bags_value_label.text = str(records.get("max_bags_count", 0)) + " 枚"

func _format_number(n: int) -> String:
	var s = str(n)
	var res = ""
	var count = 0
	for i in range(s.length() - 1, -1, -1):
		res = s[i] + res
		count += 1
		if count % 3 == 0 and i > 0:
			res = "," + res
	return res

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://title.tscn")
