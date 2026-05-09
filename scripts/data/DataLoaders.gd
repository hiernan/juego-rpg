extends RefCounted

const CsvLoaderScript = preload("res://scripts/data/CsvLoader.gd")

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
