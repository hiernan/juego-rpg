extends RefCounted

static func to_int(value: String) -> int:
	return int(value.strip_edges())


static func to_float(value: String) -> float:
	return float(value.strip_edges())


static func to_list(value: String, sep: String = ";") -> Array[String]:
	if value == "" or value.strip_edges().is_empty():
		return []
	var parts: PackedStringArray = value.split(sep, false)
	var out: Array[String] = []
	for part in parts:
		out.append(part.strip_edges())
	return out


static func read_csv(path: String) -> Array:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("No se pudo abrir: %s" % path)
		return []

	var headers: PackedStringArray = []
	if not file.eof_reached():
		headers = file.get_csv_line()

	var rows: Array = []
	while not file.eof_reached():
		var line: PackedStringArray = file.get_csv_line()
		if line.size() == 1 and line[0].strip_edges() == "":
			continue
		rows.append(line)

	file.close()
	return [headers, rows]
