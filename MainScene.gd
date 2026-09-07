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

func _ready() -> void:
	randomize()
	spawn_shelf_items()

# 棚の全6箇所に商品を配置する
func spawn_shelf_items() -> void:
	for i in range(slots.size()):
		spawn_item_at_slot(i)

# 指定した1つのスロットに新しい商品を補充する
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
	
	# 25%の確率で「特選」シール（特選の場合は金額がさらに5倍！）
	var is_special = randf() < 0.25
	var final_price: int = calculated_price
	
	if is_special:
		final_price *= 5
		_attach_special_sticker(item)
	
	# 値札の金額を設定＆表示をくっきり戻す
	price_tag.set_price(final_price, is_special)
	price_tag.modulate.a = 1.0
	
	# アイテムにメタデータを保持
	item.set_meta("slot_index", slot_idx)
	item.set_meta("price", final_price)
	item.set_meta("is_special", is_special)
	item.set_meta("size_scale", size_scale)
	
	# ポンッと出現するポップイン演出
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

# ドラッグ＆ドロップ入力処理
func _unhandled_input(event: InputEvent) -> void:
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

# マウス位置にある商品を掴む
func _try_grab_item(mouse_pos: Vector2) -> void:
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
			
			# ★完全解決: ドラッグ中は layer=0, mask=0 にして物理世界から完全に消す！
			# 袋のリンク（mask 1）からも絶対に検知されず、横から触れても1ミリも袋に力がかからない！
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
		
		# ★上から袋の開口部に向けて落とした場合のみ、袋の中に入る！
		if _is_above_bag_opening(grabbed_item.global_position):
			# 袋（Layer 2）との衝突をONにして袋の中に投入！
			grabbed_item.collision_layer = 3
			grabbed_item.collision_mask = 3
			
			# 袋に入ったのでスロットの紐付けを解除
			grabbed_item.set_meta("slot_index", -1)
			
			# ★次の商品を棚の空いたスロットに0.4秒後に補充！
			if slot_idx >= 0:
				get_tree().create_timer(0.4).timeout.connect(func(): spawn_item_at_slot(slot_idx))
		else:
			# 横や外側で離した場合は袋と絶対に衝突させず、床（Layer 1）だけに落とす
			grabbed_item.collision_layer = 4 # 袋のリンク（mask 1）には当たらないレイヤー
			grabbed_item.collision_mask = 1  # 床にだけ当たる
			
			# 外に落とした場合も棚が空きっぱなしにならないよう少し待ってから補充
			grabbed_item.set_meta("slot_index", -1)
			if slot_idx >= 0:
				get_tree().create_timer(0.8).timeout.connect(func(): spawn_item_at_slot(slot_idx))
			
		grabbed_item = null

# 袋の開口部（上空）にあるかどうかの判定
func _is_above_bag_opening(item_pos: Vector2) -> bool:
	if not has_node("Bag"):
		return false
		
	var bag_node = $Bag
	var bag_pos = bag_node.global_position
	var bag_w = bag_node.width if "width" in bag_node else 380.0
	var half_w = (bag_w * 0.5) + 30.0 # 開口部の横幅（左右マージン付き）
	
	# X座標が開口部の範囲内、かつ Y座標が袋の口の上（袋の口より高い位置）にあるか
	var is_in_x = (item_pos.x >= bag_pos.x - half_w) and (item_pos.x <= bag_pos.x + half_w)
	var is_above_y = item_pos.y <= (bag_pos.y + 30.0)
	
	return is_in_x and is_above_y
