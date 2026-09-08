extends RefCounted
class_name HighScoreManager

const SAVE_PATH: String = "user://records.json"

# デフォルト記録データ
static func get_default_records() -> Dictionary:
	return {
		"max_earned_amount": 0,
		"max_items_count": 0,
		"max_special_count": 0,
		"max_bags_count": 0
	}

# 記録の読込
static func get_records() -> Dictionary:
	var records = get_default_records()
	if not FileAccess.file_exists(SAVE_PATH):
		return records
		
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return records
		
	var json_str = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	if json.parse(json_str) == OK and typeof(json.data) == TYPE_DICTIONARY:
		var data: Dictionary = json.data
		for key in records.keys():
			if data.has(key):
				records[key] = int(data[key])
		return records
		
	return records

# 記録の更新と保存
static func update_records(earned: int, items: int, special: int, bags: int) -> Dictionary:
	var records = get_records()
	records["max_earned_amount"] = max(records["max_earned_amount"], earned)
	records["max_items_count"] = max(records["max_items_count"], items)
	records["max_special_count"] = max(records["max_special_count"], special)
	records["max_bags_count"] = max(records["max_bags_count"], bags)
	
	save_records(records)
	return records

# 記録の保存
static func save_records(records: Dictionary) -> void:
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(records, "\t"))
		file.close()
