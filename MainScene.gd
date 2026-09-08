extends Node2D

# ==========================================
# 商品データ定義（全13種類）
# ==========================================
const ITEM_DATA = {
	"res://daikon.tscn": {"name": "大根", "price": 200, "mass": 0.08},
	"res://broccoli.tscn": {"name": "ブロッコリー", "price": 90, "mass": 0.20},
	"res://negi.tscn": {"name": "ネギ", "price": 250, "mass": 0.08},
	"res://potato.tscn": {"name": "ジャガイモ", "price": 60, "mass": 0.15},
	"res://beef.tscn": {"name": "牛肉", "price": 600, "mass": 0.30},
	"res://chikin.tscn": {"name": "鶏肉", "price": 300, "mass": 0.28},
	"res://pork.tscn": {"name": "豚肉", "price": 450, "mass": 0.30},
	"res://salmon.tscn": {"name": "シャケ", "price": 320, "mass": 0.25},
	"res://cola.tscn": {"name": "コーラ", "price": 190, "mass": 0.35},
	"res://sports.tscn": {"name": "スポーツ飲料", "price": 170, "mass": 0.35},
	"res://orange.tscn": {"name": "オレンジジュース", "price": 140, "mass": 0.34},
	"res://tea.tscn": {"name": "お茶", "price": 100, "mass": 0.35},
	"res://tamanegi.tscn": {"name": "玉ねぎ", "price": 130, "mass": 0.15},
}

# ==========================================
# セット効果定義（倍率降順で優先判定）
# ==========================================
const SET_DEFINITIONS = [
	{
		"name": "ドリンクバーセット",
		"items": ["オレンジジュース", "コーラ", "スポーツ飲料", "お茶"],
		"multiplier": 4.0
	},
	{
		"name": "豚汁セット",
		"items": ["ジャガイモ", "大根", "ネギ", "豚肉"],
		"multiplier": 3.0
	},
	{
		"name": "生姜焼きセット",
		"items": ["玉ねぎ", "豚肉"],
		"multiplier": 1.5
	},
	{
		"name": "牛丼セット",
		"items": ["玉ねぎ", "牛肉"],
		"multiplier": 1.5
	},
	{
		"name": "ネギまセット",
		"items": ["鶏肉", "ネギ"],
		"multiplier": 1.5
	},
	{
		"name": "パーティーセット",
		"items": ["オレンジジュース", "コーラ"],
		"multiplier": 1.5
	},
]

const SPECIAL_STICKER_TEXTURE = preload("res://Image/allhigh.png")
const ResultScreenClass = preload("res://ResultScreen.gd")

# 3種類の袋シーン
const BAG_SCENES = {
	"small": preload("res://SmallBag.tscn"),
	"middle": preload("res://MiddleBag.tscn"),
	"big": preload("res://BigBag.tscn"),
}

var current_bag_type: String = "middle"

# スロット位置（上段左右、中段左右、下段左右）
@onready var slots = [
	$ShelfSlots/Slot0,
	$ShelfSlots/Slot1,
	$ShelfSlots/Slot2,
	$ShelfSlots/Slot3,
	$ShelfSlots/Slot4,
	$ShelfSlots/Slot5,
]

@onready var price_tags = [
	$PriceTags/PriceTag0,
	$PriceTags/PriceTag1,
	$PriceTags/PriceTag2,
	$PriceTags/PriceTag3,
	$PriceTags/PriceTag4,
	$PriceTags/PriceTag5,
]

# ドラッグ操作用
var grabbed_item: RigidBody2D = null
var grab_offset: Vector2 = Vector2.ZERO
var last_mouse_pos: Vector2 = Vector2.ZERO
var mouse_velocity: Vector2 = Vector2.ZERO

# お金・タイマー・袋
const INITIAL_PROFIT: int = -10000
var profit_money: int = INITIAL_PROFIT
var current_bag_value: int = 0
var active_sets: Array[String] = []
var remaining_time: float = 180.0

# 現在袋に入っている商品
var packed_items: Array[RigidBody2D] = []

@onready var wallet_label: Label = get_node_or_null("HUD/MarginContainer/HBoxContainer/WalletPanel/HBox/WalletLabel")
@onready var timer_label: Label = get_node_or_null("HUD/TimerPanel/VBox/TimerLabel")
@onready var price_label: Label = get_node_or_null("Scale/ScalePriceLabel")
@onready var purchase_button: TextureButton = get_node_or_null("HUD/PurchaseButton")

# ゲームオーバー状態と統計
var is_game_over: bool = false
var items_packed_count: int = 0
var special_items_count: int = 0
var bags_used_count: int = 1
var closeToEnd = false
func _ready() -> void:
	randomize()
	
	# ランダムな袋で開始
	var bag_types = BAG_SCENES.keys()
	var random_type = bag_types.pick_random()
	change_bag(random_type)
	
	if purchase_button:
		purchase_button.pressed.connect(_on_purchase_button_pressed)
	
	update_wallet_display()
	_update_timer_display()
	update_total_price_display()
	update_purchase_button_state()
	spawn_shelf_items()

func _physics_process(delta: float) -> void:
	_check_outside_bag_items(delta)
	_check_bag_containment()

# 袋の内部領域にあるかを判定（開口部より下、かつ袋の底・側壁の内側）
func _is_inside_bag_cavity(item_pos: Vector2) -> bool:
	if not has_node("Bag"):
		return false
	var bag_node = $Bag
	var bag_pos = bag_node.global_position
	var bag_w = bag_node.width if "width" in bag_node else 380.0
	var half_w = (bag_w * 0.5)
	
	var in_x = abs(item_pos.x - bag_pos.x) < (half_w - 10.0)
	var in_y = (item_pos.y >= bag_pos.y + 10.0) and (item_pos.y <= 855.0)
	return in_x and in_y

# アイテムを袋に正式登録（内部に入った商品のみ）
func _register_item_in_bag(item: RigidBody2D) -> void:
	if not is_instance_valid(item):
		return
	if item in packed_items or item.get_meta("in_bag", false):
		return
	packed_items.append(item)
	item.set_meta("in_bag", true)
	item.set_meta("has_settled_in_bag", true)
	if item.has_meta("despawn_timer"):
		item.remove_meta("despawn_timer")
	_recalculate_bag()
	print("★ 商品が袋に入りました: ", item.get_meta("item_name", "商品"))

# スポナーから離れたアイテムの管理（飛行中の袋イン判定、および袋外アイテムの3秒後デストロイ）
func _check_outside_bag_items(delta: float) -> void:
	for child in get_children():
		if child is RigidBody2D and child.has_meta("price"):
			if child == grabbed_item:
				continue
			if child in packed_items or child.get_meta("in_bag", false):
				continue
			# スポナー（棚）に静止している商品は保持
			if child.freeze and child.get_meta("slot_index", -1) >= 0:
				continue
				
			# 投げ飛ばされて落下中のアイテムが袋の内部に入ったかチェック
			if _is_inside_bag_cavity(child.global_position) and child.linear_velocity.y > -20.0:
				_register_item_in_bag(child)
				continue
				
			# 袋に入らなかったアイテム: 約3秒後にデストロイ（※ゲームオーバーにはならない）
			var timer: float = child.get_meta("despawn_timer", 3.0) - delta
			child.set_meta("despawn_timer", timer)
			if timer <= 0.0:
				_destroy_item(child)

func _destroy_item(item: RigidBody2D) -> void:
	if not is_instance_valid(item) or item.has_meta("is_destroying"):
		return
	item.set_meta("is_destroying", true)
	item.collision_layer = 0
	item.collision_mask = 0
	var tween = create_tween()
	tween.tween_property(item, "scale", Vector2.ZERO, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(item, "modulate:a", 0.0, 0.15)
	tween.tween_callback(item.queue_free)
	SfxPool.play_sfx(preload("res://SE・BGM/SE/audiostock_1128250.mp3"))
# １度袋の中に入ったもの（has_settled_in_bag）が袋から出た場合のみゲームオーバー
func _check_bag_containment() -> void:
	if is_game_over or not has_node("Bag"):
		return
		
	var bag_node = $Bag
	var bag_pos = bag_node.global_position
	var bag_w = bag_node.width if "width" in bag_node else 380.0
	var half_w = (bag_w * 0.5)

	for item in packed_items:
		if not is_instance_valid(item):
			continue
			
		# 一度袋の内部にしっかり収まった商品だけを対象とする
		if not item.get_meta("has_settled_in_bag", false):
			continue
			
		var pos = item.global_position
		var escaped = false
		
		# 1. 左右にはみ出して袋の外へこぼれ落ちた
		if abs(pos.x - bag_pos.x) > (half_w + 35.0):
			escaped = true
		# 2. 下に突き抜けて袋の外へこぼれた（底抜け・床落下）
		elif pos.y > 865.0:
			escaped = true
		# 3. 袋の口から上へ飛び出して外へこぼれ出た
		elif (pos.y < bag_pos.y - 15.0) and (abs(pos.x - bag_pos.x) > half_w):
			escaped = true
			
		if escaped:
			_on_item_escaped_bag(item)
			break

# 袋からアイテムがこぼれ出た時の処理（ゲームオーバー）
func _on_item_escaped_bag(item: RigidBody2D) -> void:
	if is_game_over:
		return
	is_game_over = true
	update_purchase_button_state()
	var item_name = item.get_meta("item_name", "商品")
	print("★ 袋の中に入っていた%sが袋からこぼれ出ました！ゲームオーバー" % item_name)
	
	if grabbed_item and is_instance_valid(grabbed_item):
		grabbed_item.freeze = false
		grabbed_item.collision_layer = 3
		grabbed_item.collision_mask = 3
		grabbed_item = null
	
	var tree = get_tree()
	if tree:
		await tree.create_timer(1.2).timeout
	_go_to_result_screen()

func _process(delta: float) -> void:
	if is_game_over:
		return
	
	remaining_time -= delta
	if remaining_time <= 0.0:
		remaining_time = 0.0
		_update_timer_display()
		_on_time_up()
		return
		
	_update_timer_display()

# タイマー表示を更新
func _update_timer_display() -> void:
	if timer_label:
		var sec: int = int(ceil(remaining_time))
		timer_label.text = "残り %d秒" % sec
		
		if sec <= 30:
			if closeToEnd == false:
				SfxPool.play_sfx(preload("res://SE・BGM/SE/audiostock_323312.mp3"))
				closeToEnd = true
			timer_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35, 1))
		else:
			timer_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3, 1))

# 額表示を更新
func update_wallet_display() -> void:
	if wallet_label:
		var prefix = "+" if profit_money > 0 else ""
		wallet_label.text = prefix + _format_number(profit_money) + " 円"
		if profit_money < 0:
			wallet_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4, 1))
		else:
			wallet_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4, 1))

# 秤の金額表示を更新（セット効果発動時はオレンジ色に強調）
func update_total_price_display() -> void:
	if price_label:
		price_label.text = "¥ " + _format_number(current_bag_value)
		if active_sets.size() > 0:
			price_label.add_theme_color_override("font_color", Color(0.95, 0.45, 0.05, 1))
		else:
			price_label.add_theme_color_override("font_color", Color(0.06, 0.16, 0.25, 1))

# 購入ボタンの状態を更新
func update_purchase_button_state() -> void:
	if purchase_button:
		var projected_profit = profit_money + current_bag_value
		var can_purchase = (projected_profit >= 0) and (packed_items.size() > 0) and not is_game_over
		purchase_button.disabled = not can_purchase
		purchase_button.modulate.a = 1.0 if can_purchase else 0.4

# セット効果と袋の中身の合計金額を計算
func calculate_bag_value() -> Dictionary:
	var valid_items: Array[RigidBody2D] = []
	for it in packed_items:
		if is_instance_valid(it):
			valid_items.append(it)
	packed_items = valid_items
	
	var available = valid_items.duplicate()
	var sets_formed: Array[String] = []
	var item_multipliers: Dictionary = {}
	
	for set_def in SET_DEFINITIONS:
		while true:
			var matched_items: Array[RigidBody2D] = []
			var req_names: Array = set_def["items"].duplicate()
			var temp_avail = available.duplicate()
			var all_found = true
			
			for req_name in req_names:
				var found_item: RigidBody2D = null
				for item in temp_avail:
					var item_name = item.get_meta("item_name", "")
					if item_name == req_name:
						found_item = item
						break
				if found_item:
					temp_avail.erase(found_item)
					matched_items.append(found_item)
				else:
					all_found = false
					break
			
			if all_found:
				for m_item in matched_items:
					available.erase(m_item)
					item_multipliers[m_item] = set_def["multiplier"]
				sets_formed.append(set_def["name"])
			else:
				break
				
	var total_value: int = 0
	for item in valid_items:
		var base_price: int = item.get_meta("price", 0)
		var mult: float = item_multipliers.get(item, 1.0)
		total_value += int(round(base_price * mult))
		
	return {
		"total_value": total_value,
		"sets": sets_formed
	}

# 袋の中身を再計算して表示更新
func _recalculate_bag() -> void:
	var bag_data = calculate_bag_value()
	current_bag_value = bag_data["total_value"]
	active_sets = bag_data["sets"]
	update_total_price_display()
	update_purchase_button_state()

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

# 棚の全6箇所に商品を配置する
func spawn_shelf_items() -> void:
	for i in range(slots.size()):
		spawn_item_at_slot(i)

# 使用した1つのスロットに新しい商品を補充する
func spawn_item_at_slot(slot_idx: int) -> void:
	if slot_idx < 0 or slot_idx >= slots.size():
		return
		
	var slot = slots[slot_idx]
	var price_tag: PriceTag = price_tags[slot_idx]
	
	var item_paths = ITEM_DATA.keys()
	var random_path = item_paths.pick_random()
	var data = ITEM_DATA[random_path]
	var item_scene = load(random_path)
	var item: RigidBody2D = item_scene.instantiate()
	
	# 【大きさの変動】0.75倍 〜 1.35倍 の範囲でランダムに変動
	var size_scale: float = randf_range(0.75, 1.35)
	item.scale = Vector2(size_scale, size_scale)
	
	# 大きさに応じて重さ（mass）も連動して変動
	item.mass = data["mass"] * (size_scale * size_scale)
	
	# 【金額の変動】大きさに応じて金額を計算
	var base_price: int = data["price"]
	var calculated_price: int = int(round((base_price * size_scale) / 10.0) * 10)
	calculated_price = max(calculated_price, 10)
	
	# 初期状態は棚で静止
	item.freeze = true
	item.collision_layer = 3
	item.collision_mask = 3
	item.global_position = slot.global_position
	add_child(item)

	var is_special = randf() < 0.25
	var final_price: int = calculated_price
	
	if is_special:
		final_price *= 5
		_attach_special_sticker(item)

	price_tag.set_price(final_price, is_special)
	price_tag.modulate.a = 1.0
	
	# アイテムにメタデータを保持
	item.set_meta("slot_index", slot_idx)
	item.set_meta("price", final_price)
	item.set_meta("is_special", is_special)
	item.set_meta("size_scale", size_scale)
	item.set_meta("item_name", data["name"])

	item.scale = Vector2.ZERO
	var tween = create_tween()
	tween.tween_property(item, "scale", Vector2(size_scale, size_scale), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	SfxPool.play_sfx(preload("res://SE・BGM/SE/audiostock_400832.mp3"))
# 特選シールを商品に貼り付ける
func _attach_special_sticker(item: RigidBody2D) -> void:
	var sticker = Sprite2D.new()
	sticker.texture = SPECIAL_STICKER_TEXTURE
	sticker.scale = Vector2(0.25, 0.25)
	sticker.position = Vector2(15, -15)
	sticker.z_index = 10
	item.add_child(sticker)

# ドラッグ＆ドロップおよびキー入力処理
func _unhandled_input(event: InputEvent) -> void:
	if is_game_over:
		return
		
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_try_grab_item(event.position)
			else:
				_release_grabbed_item()
				
	elif event is InputEventMouseMotion:
		mouse_velocity = (event.position - last_mouse_pos) / max(get_process_delta_time(), 0.001)
		last_mouse_pos = event.position
		
		if grabbed_item and is_instance_valid(grabbed_item):
			grabbed_item.global_position = event.position + grab_offset

	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_1:
			change_bag("small")
		elif event.keycode == KEY_2:
			change_bag("middle")
		elif event.keycode == KEY_3:
			change_bag("big")

# 袋を切り替える
func change_bag(type_name: String) -> void:
	if not BAG_SCENES.has(type_name):
		return
		
	current_bag_type = type_name
	
	if has_node("Bag"):
		var old_bag = $Bag
		var bag_pos = old_bag.position
		old_bag.name = "OldBag"
		old_bag.queue_free()
		
		var new_bag = BAG_SCENES[type_name].instantiate()
		new_bag.name = "Bag"
		new_bag.position = bag_pos
		if new_bag.has_signal("bag_broken"):
			new_bag.bag_broken.connect(_on_bag_broken)
		add_child(new_bag)
		print("★ 袋を切り替えました: ", type_name)

# マウス位置にある商品を掴む
func _try_grab_item(mouse_pos: Vector2) -> void:
	if is_game_over:
		return
		
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsPointQueryParameters2D.new()
	query.position = mouse_pos
	query.collide_with_bodies = true
	query.collision_mask = 3
	
	var results = space_state.intersect_point(query, 10)
	for res in results:
		var collider = res.collider
		if collider is RigidBody2D and collider.has_meta("price"):
			# ★ 袋に入ったオブジェクトには触れることができない
			if collider in packed_items or collider.get_meta("in_bag", false):
				continue
				
			grabbed_item = collider
			grab_offset = collider.global_position - mouse_pos
			grabbed_item.freeze = true
			grabbed_item.z_index = 50
			
			grabbed_item.collision_layer = 0
			grabbed_item.collision_mask = 0
			SfxPool.play_sfx(preload("res://SE・BGM/SE/audiostock_1272928.mp3"))
			var slot_idx = collider.get_meta("slot_index", -1)
			if slot_idx >= 0 and slot_idx < price_tags.size():
				price_tags[slot_idx].modulate.a = 0.4
			break
	
# 掴んでいた商品を離す
func _release_grabbed_item() -> void:
	if grabbed_item and is_instance_valid(grabbed_item):
		grabbed_item.freeze = false
		grabbed_item.z_index = 5
		
		# 手の動きに合わせた慣性速度をつける（投げ飛ばし可能）
		grabbed_item.linear_velocity = mouse_velocity.clamp(Vector2(-1500, -1500), Vector2(1500, 1500)) * 0.5
		
		var slot_idx: int = grabbed_item.get_meta("slot_index", -1)
		grabbed_item.collision_layer = 3
		grabbed_item.collision_mask = 3

		# スロット補充（手を離したら0.4秒後に新商品を補充）
		grabbed_item.set_meta("slot_index", -1)
		if slot_idx >= 0:
			var tree = get_tree()
			if tree:
				tree.create_timer(0.4).timeout.connect(func(): spawn_item_at_slot(slot_idx))

		# 手を離した瞬間に既に袋の内部に入っている場合
		if _is_inside_bag_cavity(grabbed_item.global_position):
			_register_item_in_bag(grabbed_item)
		else:
			# 投げ飛ばされた/袋の外で離された場合: 3秒のデスポーンタイマーを設定（飛行・落下中はゲームオーバーにならない）
			grabbed_item.set_meta("despawn_timer", 3.0)
			
		grabbed_item = null
		SfxPool.play_sfx(preload("res://SE・BGM/SE/audiostock_1283196.mp3"))

func _is_above_bag_opening(item_pos: Vector2) -> bool:
	if not has_node("Bag"):
		return false
		
	var bag_node = $Bag
	var bag_pos = bag_node.global_position
	var bag_w = bag_node.width if "width" in bag_node else 380.0
	var half_w = (bag_w * 0.5) + 30.0
	
	var is_in_x = (item_pos.x >= bag_pos.x - half_w) and (item_pos.x <= bag_pos.x + half_w)
	var is_above_y = item_pos.y <= (bag_pos.y + 30.0)
	
	return is_in_x and is_above_y

# 購入ボタン押下時: 袋の価値をお得額に加算し、袋を新品・ランダムサイズに交換
func _on_purchase_button_pressed() -> void:
	if is_game_over:
		return
	if (profit_money + current_bag_value) < 0 or packed_items.is_empty():
		print("所持金がマイナスのため、袋を追加（購入）できません")
		return
		
	var bag_val = current_bag_value
	profit_money += bag_val
	
	items_packed_count += packed_items.size()
	for item in packed_items:
		if is_instance_valid(item) and item.get_meta("is_special", false):
			special_items_count += 1
			
	for item in packed_items:
		if is_instance_valid(item):
			item.queue_free()
	packed_items.clear()
	
	# 袋を新品に交換（サイズをランダムに変化）
	var bag_types = BAG_SCENES.keys()
	var other_types = bag_types.filter(func(t): return t != current_bag_type)
	var next_type = other_types.pick_random() if not other_types.is_empty() else bag_types.pick_random()
	change_bag(next_type)
	
	current_bag_value = 0
	active_sets.clear()
	bags_used_count += 1
	SfxPool.play_sfx(preload("res://SE・BGM/SE/audiostock_959278.mp3"))
	update_wallet_display()
	update_total_price_display()
	update_purchase_button_state()
	print("★ 袋を追加（購入）しました！+¥ %d 獲得、現在のお得額: ¥ %d" % [bag_val, profit_money])

# 袋破損時の処理（ゲームセット）
func _on_bag_broken() -> void:
	if is_game_over:
		return
	is_game_over = true
	update_purchase_button_state()
	print("★ 袋が破れました！ゲームセット")
	SfxPool.play_sfx(preload("res://SE・BGM/SE/audiostock_1600118.mp3"))
	if grabbed_item and is_instance_valid(grabbed_item):
		grabbed_item.freeze = false
		grabbed_item.collision_layer = 3
		grabbed_item.collision_mask = 3
		grabbed_item = null
	
	var tree = get_tree()
	if tree:
		await tree.create_timer(1.2).timeout
	_go_to_result_screen()

# 制限時間終了時の処理（ゲームセット）
func _on_time_up() -> void:
	if is_game_over:
		return
	is_game_over = true
	update_purchase_button_state()
	print("★ 制限時間180秒終了！ゲームセット")
	SfxPool.play_sfx(preload("res://SE・BGM/SE/audiostock_1385435.mp3"))
	# 時間切れ時点で袋が破れていなければ、袋の中身を精算
	if packed_items.size() > 0:
		var bag_data = calculate_bag_value()
		profit_money += bag_data["total_value"]
		items_packed_count += packed_items.size()
		for item in packed_items:
			if is_instance_valid(item) and item.get_meta("is_special", false):
				special_items_count += 1
				
	var tree = get_tree()
	if tree:
		await tree.create_timer(0.8).timeout
	_go_to_result_screen()

# リザルト画面遷移
func _go_to_result_screen() -> void:
	ResultScreenClass.earned_amount = profit_money
	ResultScreenClass.items_count = items_packed_count
	ResultScreenClass.special_count = special_items_count
	ResultScreenClass.bags_count = bags_used_count
	var tree = get_tree()
	if tree:
		tree.change_scene_to_file("res://ResultScreen.tscn")
