extends Control

# ==========================================
# クレジット表記（ここを書き換えるか、シーンのNameLabelを書き換えてください）
# ==========================================
const PLANNER_NAME: String = "今村　陽向"
const PROGRAMMER_1_NAME: String = "山下 凛人"
const PROGRAMMER_2_NAME: String = "ヨンスンノン タナコン"

@onready var start_button: Button = $VBoxContainer/StartButton
@onready var record_button: Button = $VBoxContainer/RecordButton
@onready var quit_button: Button = $VBoxContainer/QuitButton

@onready var playing_board: Control = get_node_or_null("Playingboard")
@onready var play_start_button: Button = get_node_or_null("Playingboard/PlayStartButton")
@onready var credit_button: Button = get_node_or_null("CreditButton")
@onready var credit_popup: Control = get_node_or_null("CreditPopup")


func _ready():
	# もしシーン側にPlayingboardがまだ無い（未保存・未リロード）場合は自動生成する
	if not playing_board:
		var tex_rect = TextureRect.new()
		tex_rect.name = "Playingboard"
		tex_rect.texture = load("res://Image/Playingboard.png")
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(tex_rect)
		playing_board = tex_rect
	elif playing_board is TextureRect:
		playing_board.texture = load("res://Image/Playingboard.png")

	if not play_start_button:
		# Playingboardの中にButtonがあるか探し、無ければStartButtonを複製して下に配置
		for child in playing_board.get_children():
			if child is Button:
				play_start_button = child
				break
		if not play_start_button:
			play_start_button = start_button.duplicate()
			play_start_button.name = "PlayStartButton"
			play_start_button.text = "セールスタート！！"
			playing_board.add_child(play_start_button)
			play_start_button.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
			play_start_button.offset_left = -380.0
			play_start_button.offset_top = -135.0
			play_start_button.offset_right = 380.0
			play_start_button.offset_bottom = -15.0

	play_start_button.text = "セールスタート！！"
	play_start_button.add_theme_font_size_override("font_size", 46)
	playing_board.visible = false
	
	start_button.pressed.connect(_on_start_button_pressed)
	record_button.pressed.connect(_on_record_button_pressed)
	quit_button.pressed.connect(_on_quit_button_pressed)
	play_start_button.pressed.connect(_on_play_start_button_pressed)
	_setup_credit_ui()

func _setup_credit_ui() -> void:
	if not credit_button:
		credit_button = start_button.duplicate()
		credit_button.name = "CreditButton"
		credit_button.text = "クレジット"
		credit_button.custom_minimum_size = Vector2.ZERO
		add_child(credit_button)
		credit_button.set_anchors_preset(Control.PRESET_TOP_LEFT)
		credit_button.offset_left = 35.0
		credit_button.offset_top = 30.0
		credit_button.offset_right = 375.0
		credit_button.offset_bottom = 125.0
		credit_button.add_theme_font_size_override("font_size", 36)

	if not credit_popup:
		credit_popup = _build_credit_popup_fallback()
		add_child(credit_popup)
		if playing_board:
			move_child(playing_board, get_child_count() - 1)

	var p_label = credit_popup.get_node_or_null("CreditPanel/VBoxContainer/PlannerBox/HBox/NameLabel") as Label
	var pg1_label = credit_popup.get_node_or_null("CreditPanel/VBoxContainer/Programmer1Box/HBox/NameLabel") as Label
	var pg2_label = credit_popup.get_node_or_null("CreditPanel/VBoxContainer/Programmer2Box/HBox/NameLabel") as Label
	if p_label and PLANNER_NAME != "名前を入力":
		p_label.text = PLANNER_NAME
	if pg1_label and PROGRAMMER_1_NAME != "名前を入力":
		pg1_label.text = PROGRAMMER_1_NAME
	if pg2_label and PROGRAMMER_2_NAME != "名前を入力":
		pg2_label.text = PROGRAMMER_2_NAME

	credit_popup.visible = false
	credit_button.pressed.connect(func(): credit_popup.visible = true)

	var close_btn = credit_popup.get_node_or_null("CreditPanel/CreditCloseButton") as Button
	if close_btn:
		close_btn.pressed.connect(func(): credit_popup.visible = false)

	var overlay = credit_popup.get_node_or_null("DarkOverlay") as Control
	if overlay:
		overlay.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				credit_popup.visible = false
		)

func _build_credit_popup_fallback() -> Control:
	var font = load("res://Font/HGRPP1.TTC")
	var popup = Control.new()
	popup.name = "CreditPopup"
	popup.set_anchors_preset(Control.PRESET_FULL_RECT)

	var overlay = ColorRect.new()
	overlay.name = "DarkOverlay"
	overlay.color = Color(0, 0, 0, 0.65)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	popup.add_child(overlay)

	var panel = Panel.new()
	panel.name = "CreditPanel"
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -460.0
	panel.offset_top = -350.0
	panel.offset_right = 460.0
	panel.offset_bottom = 350.0
	var p_style = StyleBoxFlat.new()
	p_style.bg_color = Color(0.14, 0.18, 0.22, 0.96)
	p_style.set_border_width_all(4)
	p_style.border_color = Color(0.96, 0.55, 0.12, 1)
	p_style.set_corner_radius_all(20)
	panel.add_theme_stylebox_override("panel", p_style)
	popup.add_child(panel)

	var header = Label.new()
	header.name = "HeaderLabel"
	header.text = "ク レ ジ ッ ト"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.set_anchors_preset(Control.PRESET_CENTER_TOP)
	header.offset_left = -250.0
	header.offset_top = 30.0
	header.offset_right = 250.0
	header.offset_bottom = 100.0
	header.add_theme_font_override("font", font)
	header.add_theme_font_size_override("font_size", 50)
	header.add_theme_color_override("font_color", Color.WHITE)
	header.add_theme_color_override("font_outline_color", Color.BLACK)
	header.add_theme_constant_override("outline_size", 12)
	panel.add_child(header)

	var vbox = VBoxContainer.new()
	vbox.name = "VBoxContainer"
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 24)
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.offset_left = -380.0
	vbox.offset_top = -200.0
	vbox.offset_right = 380.0
	vbox.offset_bottom = 185.0
	panel.add_child(vbox)

	var slot_style = StyleBoxFlat.new()
	slot_style.bg_color = Color(0.0941176, 0.356863, 0.47451, 1)
	slot_style.set_border_width_all(3)
	slot_style.border_color = Color(1, 0.85, 0.35, 0.9)
	slot_style.set_corner_radius_all(12)
	slot_style.content_margin_left = 30.0
	slot_style.content_margin_right = 30.0
	slot_style.content_margin_top = 14.0
	slot_style.content_margin_bottom = 14.0

	var entries = [
		["PlannerBox", "プランナー", PLANNER_NAME],
		["Programmer1Box", "プログラマー", PROGRAMMER_1_NAME],
		["Programmer2Box", "プログラマー", PROGRAMMER_2_NAME],
	]
	for e in entries:
		var box = PanelContainer.new()
		box.name = e[0]
		box.custom_minimum_size = Vector2(760, 105)
		box.add_theme_stylebox_override("panel", slot_style)
		var hbox = HBoxContainer.new()
		hbox.name = "HBox"
		hbox.alignment = BoxContainer.ALIGNMENT_CENTER
		hbox.add_theme_constant_override("separation", 30)
		box.add_child(hbox)

		var r_lbl = Label.new()
		r_lbl.name = "RoleLabel"
		r_lbl.text = e[1]
		r_lbl.custom_minimum_size = Vector2(260, 0)
		r_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		r_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		r_lbl.add_theme_font_override("font", font)
		r_lbl.add_theme_font_size_override("font_size", 34)
		r_lbl.add_theme_color_override("font_color", Color.WHITE)
		r_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
		r_lbl.add_theme_constant_override("outline_size", 8)
		hbox.add_child(r_lbl)

		var n_lbl = Label.new()
		n_lbl.name = "NameLabel"
		n_lbl.text = e[2]
		n_lbl.custom_minimum_size = Vector2(380, 0)
		n_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		n_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		n_lbl.add_theme_font_override("font", font)
		n_lbl.add_theme_font_size_override("font_size", 40)
		n_lbl.add_theme_color_override("font_color", Color(1, 0.95, 0.4, 1))
		n_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
		n_lbl.add_theme_constant_override("outline_size", 8)
		hbox.add_child(n_lbl)

		vbox.add_child(box)

	var close_btn = start_button.duplicate()
	close_btn.name = "CreditCloseButton"
	close_btn.text = "とじる"
	close_btn.custom_minimum_size = Vector2.ZERO
	panel.add_child(close_btn)
	close_btn.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	close_btn.offset_left = -170.0
	close_btn.offset_top = -120.0
	close_btn.offset_right = 170.0
	close_btn.offset_bottom = -25.0
	close_btn.add_theme_font_size_override("font_size", 40)

	return popup

func _on_start_button_pressed():
	playing_board.visible = true

func _on_play_start_button_pressed():
	get_tree().change_scene_to_file("res://MainScene.tscn")

func _on_record_button_pressed():
	get_tree().change_scene_to_file("res://RecordScreen.tscn")

func _on_quit_button_pressed():
	get_tree().quit()
