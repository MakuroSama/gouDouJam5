extends Node2D
class_name PriceTag

@onready var price_label: Label = $Label
@onready var sprite: Sprite2D = $Sprite2D

func set_price(amount: int, is_special: bool = false) -> void:
	if price_label:
		price_label.text = "¥ " + str(amount)
		if is_special:
			price_label.add_theme_color_override("font_color", Color(0.85, 0.1, 0.1, 1.0))
		else:
			price_label.add_theme_color_override("font_color", Color(0.15, 0.15, 0.15, 1.0))
