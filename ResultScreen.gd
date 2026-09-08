extends Control
class_name ResultScreen

static var earned_amount: int = 0
static var items_count: int = 0
static var special_count: int = 0
static var bags_count: int = 1

@onready var earned_value_label: Label = $VBoxContainer/EarnedBox/EarnedVBox/ValueLabel
@onready var items_value_label: Label = $VBoxContainer/ItemsBox/HBox/ValueLabel
@onready var special_value_label: Label = $VBoxContainer/SpecialBox/HBox/ValueLabel
@onready var bags_value_label: Label = $VBoxContainer/BagsBox/HBox/ValueLabel
@onready var quit_button: Button = $QuitButton

func _ready() -> void:
	quit_button.pressed.connect(_on_quit_pressed)
	
	items_value_label.text = str(items_count) + " 個"
	special_value_label.text = str(special_count) + " 個"
	bags_value_label.text = str(bags_count) + " 枚"
	
	# 金額のカウントアップ演出
	earned_value_label.text = "¥ 0"
	if earned_amount > 0:
		var tween = create_tween()
		tween.tween_method(
			func(val: int):
				earned_value_label.text = "¥ " + _format_number(val),
			0,
			earned_amount,
			1.2
		).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	else:
		earned_value_label.text = "¥ 0"

# 3桁区切りのフォーマット関数
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

func _on_quit_pressed() -> void:
	get_tree().change_scene_to_file("res://title.tscn")
