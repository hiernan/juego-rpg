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
