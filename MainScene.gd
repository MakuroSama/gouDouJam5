extends Node2D

# ==========================================
# 商品データ定義（全12種類）
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
}

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

# 所持金と袋の中身金額
const INITIAL_WALLET: int = 10000
var wallet_money: int = 10000
var current_bag_price: int = 0
var total_earned_price: int = 0

# 現在袋に入っている商品
var packed_items: Array[RigidBody2D] = []

@onready var wallet_label: Label = get_node_or_null("HUD/MarginContainer/HBoxContainer/WalletPanel/HBox/WalletLabel")
@onready var price_label: Label = get_node_or_null("Scale/ScalePriceLabel")
@onready var purchase_button: TextureButton = get_node_or_null("HUD/PurchaseButton")

# ゲームオーバー状態と統計
var is_game_over: bool = false
var items_packed_count: int = 0
var special_items_count: int = 0
var bags_used_count: int = 1

func _ready() -> void:
	randomize()
	
	# ★3種類の袋（小・中・大）からランダムに1つ選んで出現させる！
	var bag_types = BAG_SCENES.keys()
	var random_type = bag_types.pick_random()
	change_bag(random_type)
	
	if purchase_button:
		purchase_button.pressed.connect(_on_purchase_button_pressed)
	
	update_wallet_display()
	update_total_price_display()
	update_purchase_button_state()
	spawn_shelf_items()

# 所持金表示を更新
func update_wallet_display() -> void:
	if wallet_label:
		wallet_label.text = "¥ " + _format_number(wallet_money)
		if wallet_money < 0:
			wallet_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35, 1))
		else:
			wallet_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4, 1))

# 秤の金額表示を更新
func update_total_price_display() -> void:
	if price_label:
		price_label.text = "¥ " + _format_number(current_bag_price)
		if current_bag_price > wallet_money:
			price_label.add_theme_color_override("font_color", Color(0.85, 0.15, 0.15, 1))
		else:
			price_label.add_theme_color_override("font_color", Color(0.06, 0.16, 0.25, 1))

# 購入ボタンの状態を更新
func update_purchase_button_state() -> void:
	if purchase_button:
		var can_purchase = (wallet_money >= current_bag_price) and not is_game_over
		purchase_button.disabled = not can_purchase
		purchase_button.modulate.a = 1.0 if can_purchase else 0.4

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
	
	# 【金額の変動】大きさに応じて金額を計算（10円単位に四捨五入）
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

	item.scale = Vector2.ZERO
	var tween = create_tween()
	tween.tween_property(item, "scale", Vector2(size_scale, size_scale), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# 特選シールを商品に貼り付ける
func _attach_special_sticker(item: RigidBody2D) -> void:
	var sticker = Sprite2D.new()
	sticker.texture = SPECIAL_STICKER_TEXTURE
	sticker.scale = Vector2(0.25, 0.25)
	sticker.position = Vector2(15, -15) # 右上寄りに配置
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
		# 数字キー 1, 2, 3 で袋のサイズをリアルタイム切り替え！
		if event.keycode == KEY_1:
			change_bag("small")
		elif event.keycode == KEY_2:
			change_bag("middle")
		elif event.keycode == KEY_3:
			change_bag("big")

# 袋（ヒモのサイズ）をリアルタイムに切り替える
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
			grabbed_item = collider
			grab_offset = collider.global_position - mouse_pos
			grabbed_item.freeze = true
			grabbed_item.z_index = 50 # 掴んでいる間は一番手前に表示
			
			grabbed_item.collision_layer = 0
			grabbed_item.collision_mask = 0
			
			# スロットから持ち出したので値札を薄くする演出
			var slot_idx = collider.get_meta("slot_index", -1)
			if slot_idx >= 0 and slot_idx < price_tags.size():
				price_tags[slot_idx].modulate.a = 0.4
			break

# 掴んでいた商品を離す（上から投入した時だけ袋に入る！）
func _release_grabbed_item() -> void:
	if grabbed_item and is_instance_valid(grabbed_item):
		grabbed_item.freeze = false
		grabbed_item.z_index = 5
		
		# 手の動きに合わせた慣性速度をつける
		grabbed_item.linear_velocity = mouse_velocity.clamp(Vector2(-1500, -1500), Vector2(1500, 1500)) * 0.5
		
		var slot_idx: int = grabbed_item.get_meta("slot_index", -1)

		var was_in_bag = (grabbed_item in packed_items)
		if _is_above_bag_opening(grabbed_item.global_position):

			grabbed_item.collision_layer = 3
			grabbed_item.collision_mask = 3
			
			# ★袋に入った！秤（袋の中身金額）に加算（所持金は購入ボタン押下時に引かれる）
			if not was_in_bag:
				var item_price = grabbed_item.get_meta("price", 0)
				current_bag_price += item_price
				packed_items.append(grabbed_item)
				
				update_total_price_display()
				update_purchase_button_state()
				
				# 袋に入ったのでスロットの紐付けを解除
				grabbed_item.set_meta("slot_index", -1)
				
				if slot_idx >= 0:
					get_tree().create_timer(0.4).timeout.connect(func(): spawn_item_at_slot(slot_idx))
		else:
		
			grabbed_item.collision_layer = 4 
			grabbed_item.collision_mask = 1  

			# 袋から取り出して外へ放出した場合、秤から減額
			if was_in_bag:
				packed_items.erase(grabbed_item)
				var item_price = grabbed_item.get_meta("price", 0)
				current_bag_price -= item_price
				update_total_price_display()
				update_purchase_button_state()

			grabbed_item.set_meta("slot_index", -1)
			if slot_idx >= 0:
				get_tree().create_timer(0.8).timeout.connect(func(): spawn_item_at_slot(slot_idx))
			
		grabbed_item = null

func _is_above_bag_opening(item_pos: Vector2) -> bool:
	if not has_node("Bag"):
		return false
		
	var bag_node = $Bag
	var bag_pos = bag_node.global_position
	var bag_w = bag_node.width if "width" in bag_node else 380.0
	var half_w = (bag_w * 0.5) + 30.0 # 開口部の横幅（左右マージン付き）
	
	var is_in_x = (item_pos.x >= bag_pos.x - half_w) and (item_pos.x <= bag_pos.x + half_w)
	var is_above_y = item_pos.y <= (bag_pos.y + 30.0)
	
	return is_in_x and is_above_y

# 購入ボタン押下時: 所持金から袋の中身金額を支払い、袋を新品・ランダムサイズに交換
func _on_purchase_button_pressed() -> void:
	if is_game_over:
		return
	if wallet_money < current_bag_price:
		print("所持金が足りないため、袋を購入できません")
		return
		
	# 購入確定！所持金から袋の中身金額を引く
	var paid_amount = current_bag_price
	wallet_money -= paid_amount
	total_earned_price += paid_amount
	
	# 統計データの集計
	items_packed_count += packed_items.size()
	for item in packed_items:
		if is_instance_valid(item) and item.get_meta("is_special", false):
			special_items_count += 1
			
	# 袋の中の商品を片付ける（購入完了して持ち帰り）
	for item in packed_items:
		if is_instance_valid(item):
			item.queue_free()
	packed_items.clear()
	
	# 袋を新品に交換（サイズをランダムに変化させる）
	var bag_types = BAG_SCENES.keys()
	var other_types = bag_types.filter(func(t): return t != current_bag_type)
	var next_type = other_types.pick_random() if not other_types.is_empty() else bag_types.pick_random()
	change_bag(next_type)
	
	# 袋の中身金額を0にリセット、使った袋の数をカウント
	current_bag_price = 0
	bags_used_count += 1
	
	update_wallet_display()
	update_total_price_display()
	update_purchase_button_state()
	print("★ 袋を購入しました！¥ %d を支払い、残り所持金は ¥ %d です。新袋サイズ: %s" % [paid_amount, wallet_money, next_type])

# 袋破損時の処理（ゲームオーバー演出〜リザルト画面遷移）
func _on_bag_broken() -> void:
	if is_game_over:
		return
	is_game_over = true
	update_purchase_button_state()
	print("★ 袋が破れました！リザルト画面へ遷移します")
	
	# 掴んでいた商品を安全に解放
	if grabbed_item and is_instance_valid(grabbed_item):
		grabbed_item.freeze = false
		grabbed_item.collision_layer = 3
		grabbed_item.collision_mask = 3
		grabbed_item = null
	
	# リザルト画面に統計データをセット
	ResultScreenClass.earned_amount = total_earned_price
	ResultScreenClass.items_count = items_packed_count
	ResultScreenClass.special_count = special_items_count
	ResultScreenClass.bags_count = bags_used_count
	
	# 袋が破れて商品がこぼれる様子を少し見せてからリザルト画面へ
	await get_tree().create_timer(1.2).timeout
	get_tree().change_scene_to_file("res://ResultScreen.tscn")
