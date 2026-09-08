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
@onready var replay_button: Button = get_node_or_null("ButtonsContainer/ReplayButton")
@onready var title_button: Button = get_node_or_null("ButtonsContainer/TitleButton")

func _ready() -> void:
	if replay_button:
		replay_button.pressed.connect(_on_replay_pressed)
	if title_button:
		title_button.pressed.connect(_on_title_pressed)
		
	# 旧ボタン存在時のフォールバック
	var old_quit = get_node_or_null("QuitButton")
	if old_quit:
		old_quit.pressed.connect(_on_title_pressed)
	
	# 最高記録の更新と保存
	HighScoreManager.update_records(
		earned_amount,
		items_count,
		special_count,
		bags_count
	)
	
	if items_value_label:
		items_value_label.text = str(items_count) + " 個"
	if special_value_label:
		special_value_label.text = str(special_count) + " 個"
	if bags_value_label:
		bags_value_label.text = str(bags_count) + " 枚"
	
	# 金額のカウントアップ演出
	if earned_value_label:
		earned_value_label.text = "¥ 0"
		if earned_amount != 0:
			if earned_amount < 0:
				earned_value_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4, 1))
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
	var s = str(abs(n))
	var res = ""
	var count = 0
	for i in range(s.length() - 1, -1, -1):
		res = s[i] + res
		count += 1
		if count % 3 == 0 and i > 0:
			res = "," + res
	return ("-" if n < 0 else "") + res

func _on_replay_pressed() -> void:
	get_tree().change_scene_to_file("res://MainScene.tscn")

func _on_title_pressed() -> void:
	get_tree().change_scene_to_file("res://title.tscn")
