extends Node

# --- Diccionarios globales (por id) ---
var enemies: Dictionary = {}			# id: {name, hp_min, hp_max, ...}
var weapons: Dictionary = {}			# id: {name, slot, dmg_min, ...}
var armors: Dictionary = {}				# id: {name, slot, armor, ...}
var locations: Dictionary = {}			# id: {name, flavor_ids[], monster_ids[], ...}
var loot_tables: Dictionary = {}		# id: [{type, weight}, ...]
var texts: Dictionary = {}				# id: {type, text_es}

# --- Estado del Avatar (persistente) ---
var avatar := {
	"level": 1,
	"xp": 0,
	"max_hp": 20,
	"hp": 20,
	"str": 5,
	"dex": 5,
	"init": 5,
	"gold": 0,
	"weapon_id": "sword_short",	# puede ser "" si está en bolas
	"armor_id": "leather",			# puede ser "" si está en bolas
	"inventory": []					# lista de ids (placeholder por ahora)
}

# --- Estado de misión seleccionada ---
var current_location_id: String = "crypt"

# --- Helpers random/weighted ---
static func pick_random(arr: Array) -> Variant:
	if arr.is_empty(): return null
	return arr[randi() % arr.size()]

# --- Helpers Avatar ---
func get_weapon_damage_range() -> Vector2i:
	var wid: String = String(avatar.get("weapon_id", ""))
	if wid == "" or not weapons.has(wid):
		return Vector2i(1, 2)	# manos peladas
	var w: Dictionary = weapons[wid]
	return Vector2i(int(w.get("dmg_min", 1)), int(w.get("dmg_max", 2)))

func get_armor_value() -> int:
	var aid: String = String(avatar.get("armor_id", ""))
	if aid == "" or not armors.has(aid):
		return 0
	var a: Dictionary = armors[aid]
	return int(a.get("armor", 0))

func apply_damage(amount: int) -> void:
	var hp: int = int(avatar["hp"])
	hp = max(0, hp - max(0, amount))
	avatar["hp"] = hp

func heal(amount: int) -> void:
	var hp: int = int(avatar["hp"])
	var mhp: int = int(avatar["max_hp"])
	avatar["hp"] = min(mhp, hp + max(0, amount))

func is_dead() -> bool:
	return int(avatar["hp"]) <= 0

func on_death() -> void:
	# Pierde equipo, mantiene nivel/xp. Resucita con vida completa.
	avatar["weapon_id"] = ""
	avatar["armor_id"] = ""
	avatar["inventory"] = []
	avatar["hp"] = avatar["max_hp"]

static func pick_weighted(entries: Array) -> Dictionary:
	var total := 0
	for e_raw in entries:
		var e: Dictionary = e_raw
		total += int(e.get("weight", 0))
	if total <= 0:
		return {}
	var roll := randi() % total
	var acc := 0
	for e_raw in entries:
		var e2: Dictionary = e_raw
		acc += int(e2.get("weight", 0))
		if roll < acc:
			return e2
	return {}

func _ready() -> void:
	randomize()
	load_all()
	print("[GameData] Cargados:", enemies.size(), "enemigos /", weapons.size(), "armas /", armors.size(), "armaduras /", locations.size(), "locaciones /", loot_tables.size(), "loot_tables /", texts.size(), "textos")

# --- API pública ---
func reset() -> void:
	enemies.clear()
	weapons.clear()
	armors.clear()
	locations.clear()
	loot_tables.clear()
	texts.clear()

func load_all() -> void:
	reset()
	_load_enemies("res://data/enemies.csv")
	_load_weapons("res://data/weapons.csv")
	_load_armors("res://data/armors.csv")
	_load_locations("res://data/locations.csv")
	_load_loot_tables("res://data/loot_tables.csv")
	_load_texts("res://data/texts.csv")

# --- Helpers de parsing ---
static func _to_int(s: String) -> int:
	return int(s.strip_edges())

static func _to_float(s: String) -> float:
	return float(s.strip_edges())

static func _to_list(s: String, sep: String = ";") -> Array[String]:
	if s == "" or s.strip_edges().is_empty():
		return []
	var parts: PackedStringArray = s.split(sep, false)
	var out: Array[String] = []
	for p in parts:
		out.append(p.strip_edges())
	return out

# Lee un CSV y devuelve (headers, rows) donde rows es Array de PackedStringArray
static func _read_csv(path: String) -> Array:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("No se pudo abrir: %s" % path)
		return []
	var headers: PackedStringArray = []
	if not f.eof_reached():
		headers = f.get_csv_line()		# cabecera
	var rows: Array = []
	while not f.eof_reached():
		var line: PackedStringArray = f.get_csv_line()
		# Saltear filas vacías
		if line.size() == 1 and line[0].strip_edges() == "":
			continue
		rows.append(line)
	f.close()
	return [headers, rows]

# --- Loaders específicos ---
func _load_enemies(path: String) -> void:
	var data := _read_csv(path)
	if data.is_empty(): return
	var headers: PackedStringArray = data[0]
	var rows: Array = data[1]
	var col: Dictionary = {}
	for i in range(headers.size()):
		col[headers[i]] = i

	for r in rows:
		var row: PackedStringArray = r
		var id: String = (row[col["id"]] as String)
		var item := {
			"name": row[col["name"]],
			"hp_min": _to_int(row[col["hp_min"]]),
			"hp_max": _to_int(row[col["hp_max"]]),
			"dmg_min": _to_int(row[col["dmg_min"]]),
			"dmg_max": _to_int(row[col["dmg_max"]]),
			"gold_min": _to_int(row[col["gold_min"]]),
			"gold_max": _to_int(row[col["gold_max"]]),
			"xp": _to_int(row[col["xp"]])
		}
		enemies[id] = item

func _load_weapons(path: String) -> void:
	var data := _read_csv(path)
	if data.is_empty(): return
	var headers: PackedStringArray = data[0]
	var rows: Array = data[1]
	var col: Dictionary = {}
	for i in range(headers.size()):
		col[headers[i]] = i

	for r in rows:
		var row: PackedStringArray = r
		var id: String = (row[col["id"]] as String)
		var item := {
			"name": row[col["name"]],
			"dmg_min": _to_int(row[col["dmg_min"]]),
			"dmg_max": _to_int(row[col["dmg_max"]]),
			"price": _to_int(row[col["price"]])
		}
		weapons[id] = item

func _load_armors(path: String) -> void:
	var data := _read_csv(path)
	if data.is_empty(): return
	var headers: PackedStringArray = data[0]
	var rows: Array = data[1]
	var col: Dictionary = {}
	for i in range(headers.size()):
		col[headers[i]] = i

	for r in rows:
		var row: PackedStringArray = r
		var id: String = (row[col["id"]] as String)
		var item := {
			"name": row[col["name"]],
			"armor": _to_int(row[col["armor"]]),
			"price": _to_int(row[col["price"]])
		}
		armors[id] = item

func _load_locations(path: String) -> void:
	# NOTA: si tu CSV menciona 'rat' en monster_ids y no existe en enemies.csv,
	# no pasa nada por ahora (lo validamos más adelante si querés).
	var data := _read_csv(path)
	if data.is_empty(): return
	var headers: PackedStringArray = data[0]
	var rows: Array = data[1]
	var col: Dictionary = {}
	for i in range(headers.size()):
		col[headers[i]] = i

	for r in rows:
		var row: PackedStringArray = r
		var id: String = (row[col["id"]] as String)
		var item := {
			"name": row[col["name"]],
			"flavor_ids": _to_list(row[col["flavor_ids"]]),
			"monster_ids": _to_list(row[col["monster_ids"]]),
			"loot_table_id": row[col["loot_table_id"]],
			"danger_level": _to_int(row[col["danger_level"]])
		}
		locations[id] = item

func _load_loot_tables(path: String) -> void:
	var data := _read_csv(path)
	if data.is_empty(): return
	var headers: PackedStringArray = data[0]
	var rows: Array = data[1]
	var col: Dictionary = {}
	for i in range(headers.size()):
		col[headers[i]] = i

	# Reiniciar por si recargamos
	loot_tables.clear()

	for r in rows:
		var row: PackedStringArray = r
		var table_id: String = (row[col["id"]] as String)
		var item_id: String = (row[col["item_id"]] as String)
		var weight: int = _to_int(row[col["weight"]])

		if not loot_tables.has(table_id):
			loot_tables[table_id] = []
		var arr: Array = loot_tables[table_id]
		arr.append({"item_id": item_id, "weight": weight})
		loot_tables[table_id] = arr

func _load_texts(path: String) -> void:
	var data := _read_csv(path)
	if data.is_empty(): return
	var headers: PackedStringArray = data[0]
	var rows: Array = data[1]
	var col: Dictionary = {}
	for i in range(headers.size()):
		col[headers[i]] = i

	for r in rows:
		var row: PackedStringArray = r
		var id: String = (row[col["id"]] as String)
		var item := {
			"text_es": row[col["text_es"]]
		}
		texts[id] = item
