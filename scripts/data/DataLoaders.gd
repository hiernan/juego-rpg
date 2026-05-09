extends RefCounted

const CsvLoaderScript = preload("res://scripts/data/CsvLoader.gd")

static func load_items(path: String) -> Dictionary:
	var result: Dictionary = {}
	var data := CsvLoaderScript.read_csv(path)
	if data.is_empty():
		print("[DATA] WARN _load_items: no pude abrir ", path)
		return result

	var headers: PackedStringArray = data[0]
	if headers.is_empty():
		print("[DATA] WARN _load_items: archivo vacio ", path)
		return result

	var idx := _header_index(headers)
	var rows: Array = data[1]
	var count := 0
	for r in rows:
		var cols: PackedStringArray = r
		if cols.size() == 0:
			continue

		var id := _get_col(cols, idx, "id").strip_edges()
		if id == "":
			continue

		var row := {}
		row["name"] = _get_col(cols, idx, "name", id)
		row["kind"] = _get_col(cols, idx, "kind").to_lower()
		row["subkind"] = _get_col(cols, idx, "subkind").to_lower()
		row["rarity"] = _get_col(cols, idx, "rarity")
		row["tooltip_extra"] = _get_col(cols, idx, "tooltip_extra")
		row["heal_pct"] = _to_int_default(_get_col(cols, idx, "heal_pct"))
		row["heal_hp"] = _to_int_default(_get_col(cols, idx, "heal_hp"))
		row["price"] = _to_int_default(_get_col(cols, idx, "price"))
		row["max_stack"] = max(1, _to_int_default(_get_col(cols, idx, "max_stack"), 1))
		row["stackable"] = _to_bool(_get_col(cols, idx, "stackable"))

		result[id] = row
		count += 1

	print("[DATA] _load_items OK: ", count, " filas desde ", path)
	return result


static func load_weapons(path: String) -> Dictionary:
	var result: Dictionary = {}
	var data := CsvLoaderScript.read_csv(path)
	if data.is_empty():
		return result

	var headers: PackedStringArray = data[0]
	var idx := _header_index(headers)
	var has_kind: bool = idx.has("kind")
	for r in data[1]:
		var row: PackedStringArray = r
		var id := _get_col(row, idx, "id")
		if id == "":
			continue

		var kind_val := "weapon"
		if has_kind:
			var csv_kind := _get_col(row, idx, "kind")
			if csv_kind != "":
				kind_val = csv_kind

		result[id] = {
			"name": _get_col(row, idx, "name"),
			"dmg_min": _to_int_default(_get_col(row, idx, "dmg_min")),
			"dmg_max": _to_int_default(_get_col(row, idx, "dmg_max")),
			"price": _to_int_default(_get_col(row, idx, "price")),
			"kind": kind_val,
		}
	return result


static func load_enemies(path: String) -> Dictionary:
	var result: Dictionary = {}
	var data := CsvLoaderScript.read_csv(path)
	if data.is_empty():
		return result

	var headers: PackedStringArray = data[0]
	var idx := _header_index(headers)
	for r in data[1]:
		var row: PackedStringArray = r
		var id := _get_col(row, idx, "id")
		if id == "":
			continue

		var item := {
			"name": _get_col(row, idx, "name"),
			"hp_min": _to_int_default(_get_col(row, idx, "hp_min")),
			"hp_max": _to_int_default(_get_col(row, idx, "hp_max")),
			"dmg_min": _to_int_default(_get_col(row, idx, "dmg_min")),
			"dmg_max": _to_int_default(_get_col(row, idx, "dmg_max")),
			"gold_min": _to_int_default(_get_col(row, idx, "gold_min")),
			"gold_max": _to_int_default(_get_col(row, idx, "gold_max")),
			"xp": _to_int_default(_get_col(row, idx, "xp")),
		}
		if idx.has("armor"):
			item["armor"] = _to_int_default(_get_col(row, idx, "armor"))

		result[id] = item
	return result


static func load_locations(path: String) -> Dictionary:
	var result: Dictionary = {}
	var data := CsvLoaderScript.read_csv(path)
	if data.is_empty():
		return result

	var headers: PackedStringArray = data[0]
	var idx := _header_index(headers)
	for r in data[1]:
		var row: PackedStringArray = r
		var id := _get_col(row, idx, "id")
		if id == "":
			continue

		result[id] = {
			"name": _get_col(row, idx, "name"),
			"flavor_ids": CsvLoaderScript.to_list(_get_col(row, idx, "flavor_ids")),
			"monster_ids": CsvLoaderScript.to_list(_get_col(row, idx, "monster_ids")),
			"loot_table_id": _get_col(row, idx, "loot_table_id"),
			"danger_level": _to_int_default(_get_col(row, idx, "danger_level")),
		}
	return result


static func load_loot_tables(path: String) -> Dictionary:
	var result: Dictionary = {}
	var data := CsvLoaderScript.read_csv(path)
	if data.is_empty():
		return result

	var headers: PackedStringArray = data[0]
	var idx := _header_index(headers)
	for r in data[1]:
		var row: PackedStringArray = r
		var table_id := _get_col(row, idx, "id")
		var item_id := _get_col(row, idx, "item_id")
		if table_id == "":
			continue

		if not result.has(table_id):
			result[table_id] = []
		var entries: Array = result[table_id]
		entries.append({
			"item_id": item_id,
			"weight": _to_int_default(_get_col(row, idx, "weight")),
		})
		result[table_id] = entries
	return result


static func load_texts(path: String) -> Dictionary:
	var result: Dictionary = {}
	var data := CsvLoaderScript.read_csv(path)
	if data.is_empty():
		return result

	var headers: PackedStringArray = data[0]
	var idx := _header_index(headers)
	for r in data[1]:
		var row: PackedStringArray = r
		var id := _get_col(row, idx, "id")
		if id == "":
			continue

		result[id] = {
			"text_es": _get_col(row, idx, "text_es"),
		}
	return result


static func load_armors(path: String) -> Dictionary:
	var result: Dictionary = {}
	var data := CsvLoaderScript.read_csv(path)
	if data.is_empty():
		return result

	var headers: PackedStringArray = data[0]
	var idx := _header_index(headers)
	var has_kind: bool = idx.has("kind")
	for r in data[1]:
		var row: PackedStringArray = r
		var id := _get_col(row, idx, "id")
		if id == "":
			continue

		var kind_val := "armor"
		if has_kind:
			var csv_kind := _get_col(row, idx, "kind")
			if csv_kind != "":
				kind_val = csv_kind

		result[id] = {
			"name": _get_col(row, idx, "name"),
			"armor": _to_int_default(_get_col(row, idx, "armor")),
			"price": _to_int_default(_get_col(row, idx, "price")),
			"kind": kind_val,
		}
	return result


static func load_combat_constants(path: String) -> Dictionary:
	var result: Dictionary = {}
	var data := CsvLoaderScript.read_csv(path)
	if data.is_empty():
		print("[CONST] ERROR: no se pudo abrir:", path)
		return result

	var headers: PackedStringArray = data[0]
	if headers.is_empty():
		print("[CONST] WARN: CSV vacio:", path)
		return result

	var rows: Array = data[1]
	for r in rows:
		var row: PackedStringArray = r
		if row.is_empty():
			continue
		var id := String(row[0]).strip_edges()
		if id == "":
			continue

		var item: Dictionary = {}
		for i in range(1, headers.size()):
			if i >= row.size():
				continue
			var key := String(headers[i]).strip_edges()
			var value := String(row[i]).strip_edges()
			item[key] = value
		result[id] = item

	var global_row: Dictionary = result.get("global", {})
	print("[CONST] loaded:", path, " keys(global)=", global_row.keys())
	return result


static func _header_index(headers: PackedStringArray) -> Dictionary:
	var idx := {}
	for i in range(headers.size()):
		idx[String(headers[i]).strip_edges().to_lower()] = i
	return idx


static func _get_col(cols: PackedStringArray, idx: Dictionary, name: String, default_value: String = "") -> String:
	if not idx.has(name):
		return default_value
	var col_index: int = int(idx[name])
	if col_index < 0 or col_index >= cols.size():
		return default_value
	return String(cols[col_index])


static func _to_int_default(value: String, default_value: int = 0) -> int:
	var text := value.strip_edges()
	if text == "":
		return default_value
	return int(text)


static func _to_bool(value: String) -> bool:
	var text := value.strip_edges().to_lower()
	return text == "true" or text == "1" or text == "yes" or text == "y"
