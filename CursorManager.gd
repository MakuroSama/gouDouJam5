extends Node

# マウスカーソルを gamehand.png に置き換える
const CURSOR_PATH := "res://Image/gamehand.png"
const CURSOR_SIZE := 64  # 表示サイズ(px)。カーソルは最大256pxまで

func _ready() -> void:
	var tex: Texture2D = load(CURSOR_PATH)
	if tex == null:
		return
	var img := tex.get_image()
	if img.is_compressed():
		img.decompress()
	var h := int(round(CURSOR_SIZE * float(img.get_height()) / img.get_width()))
	img.resize(CURSOR_SIZE, h, Image.INTERPOLATE_LANCZOS)
	var cursor := ImageTexture.create_from_image(img)
	# ホットスポット（クリック位置）は画像中央
	var hotspot := Vector2(CURSOR_SIZE, h) * 0.5
	Input.set_custom_mouse_cursor(cursor, Input.CURSOR_ARROW, hotspot)
	Input.set_custom_mouse_cursor(cursor, Input.CURSOR_POINTING_HAND, hotspot)
