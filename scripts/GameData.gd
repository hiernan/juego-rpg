extends Node

const InventoryServiceScript = preload("res://scripts/services/InventoryService.gd")
const ShopServiceScript = preload("res://scripts/services/ShopService.gd")

# --- Diccionarios globales (por id) ---
var enemies: Dictionary = {}			# id: {name, hp_min, hp_max, ...}
var weapons: Dictionary = {}			# id: {name, slot, dmg_min, ...}
var armors: Dictionary = {}				# id: {name, slot, armor, ...}
var locations: Dictionary = {}			# id: {name, flavor_ids[], monster_ids[], ...}
var loot_tables: Dictionary = {}		# id: [{type, weight}, ...]
var texts: Dictionary = {}				# id: {type, text_es}
var items: Dictionary = {}
var inventory: Array[String] = []
var stash: Array[String] = []
var loot_bag: Array = []
var equipped: Dictionary = {"weapon": "", "armor": ""}
var auto_potion_threshold: float = 0.25	# 25%
var auto_potion_item_id: String = "potion_small"
var _auto_potion_suppressed: bool = false	# evita spameo hasta salir del umbral
var combat_constants := {}

# Equipo actual del avatar
var equipment := {
	"weapon": null,
	"armor": null,
}

# --- Estado del Avatar (persistente) ---
var avatar := {
	"level": 1,
	"xp": 0,
	"max_hp": 50,
	"hp": 50,
	"str": 5,
	"dex": 5,
	"init": 5,
	"gold": 100,
	"weapon_id": "",            # sin arma equipada al arrancar
	"armor_id":  "",            # sin armadura equipada al arrancar

	"inventory": [ "lockpick", "lockpick", "short_sword", "leather_armor", "leather_armor", "potion_small", "potion_small", "potion_medium", "potion_great" ],
	"stash":     [ "long_sword", "chain_mail" ],
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
	# Restar vida del avatar
	var av = avatar
	var hp_max: int = int(av.get("hp_max", av.get("max_hp", 0)))
	var hp_cur: int = int(av.get("hp", 0))
	var damage: int = max(amount, 0)
	var new_hp: int = int(max(hp_cur - damage, 0))
	avatar["hp"] = new_hp
	print("[DMG] -%d HP (%d → %d / %d)" % [damage, hp_cur, new_hp, hp_max])

	# Autopoción: chequeo inmediato post-daño usando la BOLSA
	if hp_max > 0:
		var thresh: int = int(ceil(float(hp_max) * auto_potion_threshold))
		var in_danger: bool = new_hp <= thresh

		# Si salimos del peligro, reseteamos el anti-spam
		if not in_danger and _auto_potion_suppressed:
			_auto_potion_suppressed = false

		if in_danger:
			# Elegir la MEJOR curativa disponible en la bolsa (según CSV)
			var potion_id: String = pick_best_heal_from_bag()
			if potion_id != "" and bag_has(potion_id, 1):
				if bag_consume(potion_id, 1):
					var healed: int = apply_potion_effect(potion_id)
					print("[POTION] Auto-uso: +%d HP (restantes=%d, id=%s)" % [healed, bag_count(potion_id), potion_id])
					return
			# No hay curativas → aviso una sola vez hasta salir del umbral
			if not _auto_potion_suppressed:
				_auto_potion_suppressed = true
				print("[AVATAR] ¡Arghhh, me quedé sin pociones!")

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
	_load_items("res://data/items.csv")
	_load_locations("res://data/locations.csv")
	_load_loot_tables("res://data/loot_tables.csv")
	_load_texts("res://data/texts.csv")
	_load_combat_constants("res://data/combat_constants.csv")
	_load_shop("blacksmith", "res://data/shop_blacksmith.csv")
	_load_shop("healer",     "res://data/shop_healer.csv")
	_load_shop("tavern",     "res://data/shop_tavern.csv")
	print("[SHOP TEST] tavern items -> ", get_shop_items("tavern"))
	print("[SHOP TEST] tavern price potion_small -> ", get_shop_price("tavern", "potion_small"))
	print("[SHOP TEST] blacksmith stock long_sword -> ", get_shop_stock("blacksmith", "long_sword"))

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

# --- Tiendas / Economía ---
var shops: Dictionary = {
	"blacksmith": {},	# id -> { stock:int, price_override:int|-1 }
	"healer": {},
	"tavern": {}
}
var sell_ratio: float = 0.60	# el jugador vende al 60% del precio de compra
var heal_full_cost: int = 15	# costo base de curar al 100% (overrideable más adelante)

func _load_shop(shop: String, path: String) -> void:
	var data := _read_csv(path)
	if data.is_empty(): return
	var headers: PackedStringArray = data[0]
	var rows: Array = data[1]
	var col: Dictionary = {}
	for i in range(headers.size()):
		col[headers[i]] = i

	var dst: Dictionary = {}
	for r in rows:
		var row: PackedStringArray = r
		var sid: String = String(row[col["id"]])
		var stock_idx: int = int(col.get("stock", -1))
		var stock: int
		if stock_idx != -1 and stock_idx < row.size():
			stock = _to_int(row[stock_idx])
		else:
			stock = -1

		var pov_idx: int = int(col.get("price_override", -1))
		var pov_raw: String
		if pov_idx != -1 and pov_idx < row.size():
			pov_raw = String(row[pov_idx])
		else:
			pov_raw = ""

		var price_override: int
		if pov_raw.strip_edges() == "":
			price_override = -1
		else:
			price_override = _to_int(pov_raw)

		dst[sid] = { "stock": stock, "price_override": price_override }

	shops[shop] = dst

func get_shop_items(shop: String) -> Array:
	return ShopServiceScript.get_shop_items(self, shop)

func get_shop_stock(shop: String, id: String) -> int:
	return ShopServiceScript.get_shop_stock(self, shop, id)

func get_shop_price(shop: String, id: String) -> int:
	return ShopServiceScript.get_shop_price(self, shop, id)


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
		# NUEVO: armor plana si la columna existe
		if col.has("armor"):
			item["armor"] = _to_int(row[col["armor"]])

		enemies[id] = item

func _load_weapons(path: String) -> void:
	var data := _read_csv(path)
	if data.is_empty(): return
	var headers: PackedStringArray = data[0]
	var rows: Array = data[1]
	var col: Dictionary = {}
	for i in range(headers.size()):
		col[headers[i]] = i

	var has_kind: bool = col.has("kind")

	for r in rows:
		var row: PackedStringArray = r
		var id: String = String(row[col["id"]])

		var kind_val: String = "weapon"
		if has_kind:
			var kv := String(row[col["kind"]])
			if kv != "":
				kind_val = kv

		var item := {
			"name": row[col["name"]],
			"dmg_min": _to_int(row[col["dmg_min"]]),
			"dmg_max": _to_int(row[col["dmg_max"]]),
			"price": _to_int(row[col["price"]]),
			"kind": kind_val,
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

	var has_kind: bool = col.has("kind")

	for r in rows:
		var row: PackedStringArray = r
		var id: String = String(row[col["id"]])

		var kind_val: String = "armor"
		if has_kind:
			var kv := String(row[col["kind"]])
			if kv != "":
				kind_val = kv

		var item := {
			"name": row[col["name"]],
			"armor": _to_int(row[col["armor"]]),
			"price": _to_int(row[col["price"]]),
			"kind": kind_val,
		}
		armors[id] = item

func get_item_by_id(id: String) -> Dictionary:
	# Usa el kind si existe para buscar en la tabla correcta
	var kind: String = get_kind_for_id(id)
	if kind == "weapon" and weapons.has(id):
		return weapons[id]
	if kind == "armor" and armors.has(id):
		return armors[id]

	# Fallbacks por si el kind aún no está seteado o no coincide
	if weapons.has(id):
		return weapons[id]
	if armors.has(id):
		return armors[id]

	return {}

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

# --- Equipment API mínima ---
#func get_equipped_weapon_id() -> String:
	#var v = equipment.get("weapon", null)
	#return v if v is String else ""
#
#func set_equipped_weapon_id(id: String) -> void:
	#equipment["weapon"] = id

func get_equipped_armor_id() -> String:
	var v = equipment.get("armor", null)
	return v if v is String else ""

func set_equipped_armor_id(id: String) -> void:
	equipment["armor"] = id

# --- Helpers para mover 1 unidad por id simple ---
func _remove_one(arr: Array, id: String) -> bool:
	var idx := arr.find(id)
	if idx != -1:
		arr.remove_at(idx)
		return true
	return false

func _add_one(arr: Array, id: String) -> void:
	arr.append(id)

# --- Equipar arma con swap ---
# from_src: "inventory" o "stash"
func equip_weapon(id: String, from_src: String) -> void:
	if from_src == "inventory":
		_remove_one(inventory, id)
	elif from_src == "stash":
		_remove_one(stash, id)

	var old := ""
	if equipped.has("weapon_id") and equipped.weapon_id:
		old = String(equipped.weapon_id)

	# Equipa la nueva
	equipped.weapon_id = id

	# La vieja al inventario (si había)
	if old != "":
		_add_one(inventory, old)

	# Si tenés algún guardado/emit, llamalo acá (opcional):
	# save()
	# Events.player_state_changed.emit("weapon_changed")

func get_equipped_weapon_id() -> String:
	return str(avatar.get("weapon_id", ""))

func set_equipped_weapon_id(id: String) -> void:
	# Asegura que el arma equipada vive en avatar["weapon_id"]
	if not avatar.has("weapon_id"):
		avatar["weapon_id"] = ""
	avatar["weapon_id"] = id
	print("[GD] set_equipped_weapon_id -> ", id)

func inventory_add(id: String) -> void:
	inventory.append(id)

func inventory_remove_first(id: String) -> bool:
	var i := inventory.find(id)
	if i != -1:
		inventory.remove_at(i)
		return true
	return false

func stash_remove_first(id: String) -> bool:
	var i := stash.find(id)
	if i != -1:
		stash.remove_at(i)
		return true
	return false

func _remove_from_array_or_dict(ref: Variant, id: String, qty: int) -> bool:
	# Diccionario: decrementa cantidad y borra si llega a 0.
	if typeof(ref) == TYPE_DICTIONARY:
		var d: Dictionary = ref
		if not d.has(id):
			return false
		var current: int = int(d[id])
		var new_qty: int = max(0, current - qty)
		if new_qty > 0:
			d[id] = new_qty
		else:
			d.erase(id)
		return true

	# Array: elimina hasta 'qty' ocurrencias del id.
	if typeof(ref) == TYPE_ARRAY:
		var a: Array = ref
		var removed: bool = false
		var to_remove: int = qty
		for i in range(a.size() - 1, -1, -1):
			if to_remove <= 0:
				break
			if String(a[i]) == id:
				a.remove_at(i)
				to_remove -= 1
				removed = true
		return removed

	push_warning("remove_item_from_source: tipo de contenedor no soportado (%s)" % str(typeof(ref)))
	return false

# Devuelve el diccionario de un arma por id (o {} si no existe).
func get_weapon(id: String) -> Dictionary:
	if weapons.has(id):
		var w: Dictionary = weapons[id]
		var out: Dictionary = w.duplicate()
		out["id"] = id
		out["kind"] = "weapon"
		return out
	return {}

# (Opcional, por paridad con armas; no rompe nada dejarla.)
func get_armor(id: String) -> Dictionary:
	if armors.has(id):
		var a: Dictionary = armors[id]
		var out: Dictionary = a.duplicate()
		out["id"] = id
		out["kind"] = "armor"
		return out
	return {}

func get_item_name_by_id(id: String) -> String:
	if id == "":
		return ""
	if weapons.has(id):
		var w: Dictionary = weapons[id]
		return String(w.get("name", id))
	if armors.has(id):
		var a: Dictionary = armors[id]
		return String(a.get("name", id))
	return id

func add_item_to_inventory(id: String, qty: int = 1) -> void:
	for i in range(qty):
		inventory.append(id)
		
func add_item_to_stash(id: String, qty: int = 1) -> void:
	for i in range(qty):
		stash.append(id)

func remove_item_from_inventory(id: String, qty: int = 1) -> void:
	var n := qty
	while n > 0:
		var idx := inventory.find(id)
		if idx == -1:
			break
		inventory.remove_at(idx)
		n -= 1

func remove_item_from_stash(id: String, qty: int = 1) -> void:
	var n := qty
	while n > 0:
		var idx := stash.find(id)
		if idx == -1:
			break
		stash.remove_at(idx)
		n -= 1

# Útil para drag&drop: saca del origen según "from"
func remove_item_from_source(id: String, from_src: String, qty: int = 1) -> void:
	match from_src:
		"inventory":
			remove_item_from_inventory(id, qty)
		"stash", "baul":
			remove_item_from_stash(id, qty)
		_:
			# origen desconocido (equip slots no almacenan ítems como listas)
			pass

func get_item_tooltip(id: String) -> String:
	# Fuente única de la verdad para tooltips
	if id == "":
		return "¿Desconocido?\n(id vacío)"
	var kind: String = get_item_kind(id)
	if kind == "":
		# id no reconocido en catálogos
		print("[DATA] WARN get_item_tooltip: id desconocido=", id)
		return "¿Desconocido?\n(id: %s)" % id

	# Nombre "lindo"
	var name: String = ""
	if has_method("get_item_display_name"):
		name = get_item_display_name(id)
	else:
		name = id

	match kind:
		"weapon":
			var w: Dictionary = weapons.get(id, {})
			var dmin: int = int(w.get("dmg_min", 1))
			var dmax: int = int(w.get("dmg_max", 2))
			var spd: float = float(w.get("speed", w.get("atk_speed", 1.0)))
			return "%s\nDaño: %d–%d\nVelocidad: %.2f" % [name, dmin, dmax, spd]
		"armor":
			var a: Dictionary = armors.get(id, {})
			var arm: int = int(a.get("armor", a.get("defense", 0)))
			return "%s\nDefensa: %d" % [name, arm]
		_:
			# Futuro: consumibles/llaves/etc.
			return "%s" % name


# ===== Helpers genéricos de contenedores (arrays de ids) =====

func add_item_to_container(container_name: String, id: String, count: int) -> void:
	InventoryServiceScript.add_item_to_container(self, container_name, id, count)


func remove_item_from_container(container_name: String, id: String, count: int) -> void:
	InventoryServiceScript.remove_item_from_container(self, container_name, id, count)

# Compatibilidad con llamadas antiguas
func get_kind_for_id(id: String) -> String:
	return get_item_kind(id)

# --- INVENTORY CORE CONTRACT ----------------------------------------------

# Contenedores válidos para mover ítems.
const CONTAINERS := {
	"inventory": true,
	"stash": true,
	"equipped_weapon": true,
	"equipped_armor": true,
}

# Devuelve "weapon", "armor" o "item" (lo que ya usás).
func get_item_kind(id: String) -> String:
	if weapons.has(id):
		return "weapon"
	if armors.has(id):
		return "armor"
	return "item"

func move_item_between_containers(from: String, to: String, id: String, amount: int) -> bool:
	# Mueve 1 unidad del item 'id' entre:
	#   inventory | stash | equipped_weapon | equipped_armor
	# Soporta swap: si equipa y había algo, lo manda al inventory.
	# Devuelve true si pudo mover; false si no.
	if id == "":
		return false

	var av: Dictionary = avatar
	var inv: Array = av.get("inventory", [])
	var stash: Array = av.get("stash", [])
	var wid: String = str(av.get("weapon_id", ""))
	var aid: String = str(av.get("armor_id", ""))

	var removed: bool = false

	# --- quitar del origen ---
	if from == "inventory":
		var i: int = inv.find(id)
		if i != -1:
			inv.remove_at(i)
			removed = true
	elif from == "stash":
		var j: int = stash.find(id)
		if j != -1:
			stash.remove_at(j)
			removed = true
	elif from == "equipped_weapon":
		if wid == id:
			av["weapon_id"] = ""
			removed = true
	elif from == "equipped_armor":
		if aid == id:
			av["armor_id"] = ""
			removed = true

	if not removed:
		# no estaba en el origen; no hacemos nada
		return false

	# --- agregar al destino ---
	if to == "inventory":
		inv.append(id)

	elif to == "stash":
		stash.append(id)

	elif to == "equipped_weapon":
		# si había arma, va al inventory
		if wid != "":
			inv.append(wid)
		av["weapon_id"] = id

	elif to == "equipped_armor":
		# si había armadura, va al inventory
		if aid != "":
			inv.append(aid)
		av["armor_id"] = id

	else:
		# destino desconocido -> revert (volver al origen básico: inventory)
		inv.append(id)

	# --- escribir cambios ---
	av["inventory"] = inv
	av["stash"] = stash
	avatar = av

	return true

# ¿Es stackeable? (por ahora solo items comunes)
func is_stackable(id: String) -> bool:
	return InventoryServiceScript.is_stackable(self, id)

func get_item_price(id: String) -> int:
	return ShopServiceScript.get_item_price(self, id)

func can_afford(cost: int) -> bool:
	return ShopServiceScript.can_afford(self, cost)

func pay_gold(cost: int) -> bool:
	return ShopServiceScript.pay_gold(self, cost)

func add_gold(amount: int) -> void:
	ShopServiceScript.add_gold(self, amount)

func shop_buy(shop: String, id: String, amount: int = 1) -> bool:
	return ShopServiceScript.shop_buy(self, shop, id, amount)

func shop_sell(shop: String, id: String, amount: int = 1) -> bool:
	return ShopServiceScript.shop_sell(self, shop, id, amount)

func heal_full(cost: int) -> bool:
	return ShopServiceScript.heal_full(self, cost)


# Lee el string "from"/"to" y devuelve referencia al contenedor correcto.
# No toca UI.
func _get_container_ref(name: String) -> Variant:
	return InventoryServiceScript.get_container_ref(self, name)

# Escribe el contenedor de vuelta (para equipped_* al ser String).
func _set_container_ref(name: String, value: Variant) -> void:
	InventoryServiceScript.set_container_ref(self, name, value)

# Contrato único de movimiento. NO actualiza UI.
# from: "inventory" | "stash" | "equipped_weapon" | "equipped_armor"
# to:   idem
# id:   canonical id
# qty:  cantidad (default 1; ignorado para no-stackeables)
func move_item(from: String, to: String, id: String, qty: int = 1) -> bool:
	# Validaciones rápidas
	if id == "" or not CONTAINERS.has(from) or not CONTAINERS.has(to):
		return false
	if from == to:
		return true  # no-op

	var kind := get_item_kind(id)
	var stack := is_stackable(id)

	# Obtener referencias
	var from_ref: Variant = _get_container_ref(from)
	var to_ref: Variant  = _get_container_ref(to)

	# Quitar del origen
	var removed := false
	if stack:
		# Arrays: inventory/stash
		if from == "inventory" or from == "stash":
			var arr: Array = from_ref
			var removed_any := false
			var left := qty
			while left > 0:
				var idx := arr.find(id)
				if idx == -1:
					break
				arr.remove_at(idx)
				removed_any = true
				left -= 1
			removed = removed_any

			_set_container_ref(from, arr)
		else:
			# No debería sacar stacks de slots
			return false
	else:
		# No stackeables: si viene de slot, limpiar; si viene de array, erase 1
		if from == "equipped_weapon" or from == "equipped_armor":
			if String(from_ref) == id:
				removed = true
				_set_container_ref(from, "")
			else:
				return false
		else:
			var arr2: Array = from_ref
			var removed_any2 := false
			var left2 := qty
			while left2 > 0:
				var idx2 := arr2.find(id)
				if idx2 == -1:
					break
				arr2.remove_at(idx2)
				removed_any2 = true
				left2 -= 1
			removed = removed_any2

			_set_container_ref(from, arr2)

	if not removed:
		return false

	# Agregar al destino
	if to == "inventory" or to == "stash":
		var arr3: Array = _get_container_ref(to)
		arr3.append(id)
		_set_container_ref(to, arr3)
		return true

	# Destino es un slot: validar compatibilidad
	if to == "equipped_weapon" and kind != "weapon":
		# devolver al origen para no perder nada
		move_item(to, from, id, 1) # noop seguro si no llegó a ponerse
		return false
	if to == "equipped_armor" and kind != "armor":
		move_item(to, from, id, 1)
		return false

	# Si ya hay algo equipado en ese slot → swap al inventory
	var prev: Variant = _get_container_ref(to)
	if String(prev) != "":
		var inv: Array = _get_container_ref("inventory")
		inv.append(String(prev))
		_set_container_ref("inventory", inv)

	# Equipar
	_set_container_ref(to, id)
	return true
# --------------------------------------------------------------------------

# ─────────────────────────────────────────────────────────────────────
# DnD atómico — quitar y devolver (Variante A)

func take_item(from: String, id: String, amount: int = 1) -> bool:
	return InventoryServiceScript.take_item(self, from, id, amount)

func give_item(to: String, id: String, amount: int = 1) -> bool:
	return InventoryServiceScript.give_item(self, to, id, amount)
# ─────────────────────────────────────────────────────────────────────

# ─────────────────────────────────────────────────────────────────────
# Equip genérico con swap (lo anterior -> inventory)

func swap_equip(slot_kind: String, new_id: String) -> bool:
	# slot_kind: "weapon" | "armor"
	if new_id == "":
		return false

	var expected_kind: String = slot_kind
	var k: String = get_item_kind(new_id)
	if k != expected_kind:
		return false

	var slot_name := ""
	if slot_kind == "weapon":
		slot_name = "equipped_weapon"
	elif slot_kind == "armor":
		slot_name = "equipped_armor"
	else:
		return false

	# guardar qué había antes
	var current := String(_get_container_ref(slot_name))

	# equipar nuevo
	_set_container_ref(slot_name, String(new_id))

	# si realmente había algo, mandarlo a inventario
	if current != "" and current != new_id:
		var inv: Array = _get_container_ref("inventory")
		if typeof(inv) == TYPE_ARRAY:
			inv.append(current)
			_set_container_ref("inventory", inv)

	return true

# ─────────────────────────────────────────────────────────────────────

func get_equipped_id(slot_kind: String) -> String:
	if slot_kind == "weapon":
		return String(_get_container_ref("equipped_weapon"))
	elif slot_kind == "armor":
		return String(_get_container_ref("equipped_armor"))
	return ""

# ─────────────────────────────────────────────────────────────────────
# LOOT BAG — bolsa temporal de botín durante misión

func count_in_container(container: String, id: String) -> int:
	return InventoryServiceScript.count_in_container(self, container, id)

func loot_bag_reset() -> void:
	# vacía la bolsa
	loot_bag = []
	print("[LOOT] reset")

func loot_bag_add(id: String) -> void:
	# agrega 1 ítem a la bolsa si el id es válido
	if id == "":
		print("[LOOT] WARN: id vacío")
		return
	var k: String = get_item_kind(id)
	if k == "":
		print("[LOOT] WARN: id desconocido=", id)
		return
	loot_bag.append(String(id))
	print("[LOOT] add id=", id, " bag_size=", loot_bag.size())

func consolidate_loot_bag_to_inventory() -> void:
	# pasa todo el contenido de la bolsa al inventario y vacía la bolsa
	var inv: Array = _get_container_ref("inventory")
	for id in loot_bag:
		inv.append(String(id))
	_set_container_ref("inventory", inv)
	print("[LOOT] consolidate -> +", loot_bag.size(), " items a inventario (total inv=", inv.size(), ")")
	loot_bag = []

# ─────────────────────────────────────────────────────────────────────
# Eventos de fin de misión

func on_mission_success() -> void:
	# éxito: consolidar bolsa a inventario
	print("[MISSION] success: consolidating loot bag")
	consolidate_loot_bag_to_inventory()

func on_mission_abandon() -> void:
	# abandono: mismo trato que éxito (definición actual)
	print("[MISSION] abandon: consolidating loot bag")
	consolidate_loot_bag_to_inventory()

func on_mission_death() -> void:
	# muerte: se pierde TODO (bolsa + inventario + equipados)
	print("[DEATH] mission death: losing loot bag, inventory and equipped")
	# perder bolsa
	loot_bag = []
	# limpiar inventario
	_set_container_ref("inventory", [])
	# limpiar equipados
	_set_container_ref("equipped_weapon", "")
	_set_container_ref("equipped_armor", "")

# ─────────────────────────────────────────────────────────────────────
# LOOT BAG — inventario activo durante la misión

func transfer_inventory_to_bag() -> void:
	# Mueve TODO el inventario a la bolsa y deja inventario vacío
	var inv: Array = []
	var inv_ref = _get_container_ref("inventory")
	if typeof(inv_ref) == TYPE_ARRAY:
		inv = inv_ref
	else:
		# Fallback por si el inventario está anidado en avatar["inventory"]
		var av_inv = avatar.get("inventory", [])
		if typeof(av_inv) == TYPE_ARRAY:
			inv = av_inv
	# mover
	var moved := inv.size()
	for id in inv:
		loot_bag.append(String(id))
	# vaciar inventario en ambos lugares por las dudas
	_set_container_ref("inventory", [])
	if "inventory" in avatar:
		avatar["inventory"] = []
	print("[LOOT] transfer_inventory_to_bag: moved=", moved, " bag_size=", loot_bag.size())


func bag_count(id: String) -> int:
	# Cuenta cuántas unidades de 'id' hay en la bolsa
	if id == "":
		return 0
	var c := 0
	for x in loot_bag:
		if String(x) == String(id):
			c += 1
	return c

func bag_has(id: String, amount: int = 1) -> bool:
	# ¿Hay al menos 'amount' unidades de 'id' en la bolsa?
	return bag_count(id) >= max(1, amount)

func bag_consume(id: String, amount: int = 1) -> bool:
	# Quita 'amount' unidades de 'id' desde la bolsa (si hay suficientes)
	if id == "" or amount <= 0:
		return false
	var removed := 0
	# remove_at mientras contamos (recorremos por índice)
	for i in range(loot_bag.size()):
		if removed >= amount:
			break
		if String(loot_bag[i]) == String(id):
			loot_bag.remove_at(i)
			removed += 1
			i -= 1
	var ok := (removed == amount)
	print("[LOOT] bag_consume id=", id, " amount=", amount, " ok=", ok, " bag_size=", loot_bag.size())
	return ok

# Efecto de poción (curación básica). LEE: ajusta según tus columnas reales.
func apply_potion_effect(id: String) -> int:
	# Curación basada en CSV (heal_pct/ heal_hp)
	var av = avatar
	var hp_max: int = int(av.get("hp_max", av.get("max_hp", 0)))
	var hp_cur: int = int(av.get("hp", 0))
	var heal: int = get_heal_amount_from_item(id, hp_max)

	if heal > 0 and hp_max > 0:
		var new_hp: int = min(hp_cur + heal, hp_max)
		avatar["hp"] = new_hp
		print("[POTION] use id=%s +%d HP (%d→%d/%d)" % [id, heal, hp_cur, new_hp, hp_max])
	else:
		print("[POTION] WARN: sin curación válida para id=", id)
	return heal

# ─────────────────────────────────────────────────────────────────────
# HEAL HELPERS — leen curación desde items.csv (kind/subkind, heal_pct/heal_hp)

func is_healing_item(id: String) -> bool:
	# Un ítem es "curativo" si kind=consumable y subkind=heal
	var items_dict = self.get("items")
	if typeof(items_dict) != TYPE_DICTIONARY:
		return false
	var row = items_dict.get(id, {})
	if typeof(row) != TYPE_DICTIONARY:
		return false
	var kind: String = String(row.get("kind", ""))
	var subkind: String = String(row.get("subkind", ""))
	return (kind == "consumable" and subkind == "heal")


func get_heal_amount_from_item(id: String, hp_max: int) -> int:
	# Devuelve cuántos HP cura 'id' en base a heal_pct (prioritario) o heal_hp
	var items_dict = self.get("items")
	if typeof(items_dict) != TYPE_DICTIONARY:
		return 0
	var row = items_dict.get(id, {})
	if typeof(row) != TYPE_DICTIONARY:
		return 0

	var heal_pct: int = int(row.get("heal_pct", 0))
	var heal_hp: int = int(row.get("heal_hp", 0))

	if heal_pct > 0 and hp_max > 0:
		var amt: int = int(ceil(float(hp_max) * float(heal_pct) * 0.01))
		return max(amt, 1)  # al menos 1
	return max(heal_hp, 0)

func bag_list_healing() -> Array:
	# Lista curativos en la BOLSA, devolviendo {id, count, heal} por cada id
	var result: Array = []
	var items_dict = self.get("items")
	if typeof(items_dict) != TYPE_DICTIONARY:
		return result

	# Agrupar por id dentro de la bolsa
	var counts: Dictionary = {}
	for x in loot_bag:
		var iid := String(x)
		# Solo contamos curativos
		var row = items_dict.get(iid, {})
		if typeof(row) != TYPE_DICTIONARY:
			continue
		var kind: String = String(row.get("kind", ""))
		var subkind: String = String(row.get("subkind", ""))
		if not (kind == "consumable" and subkind == "heal"):
			continue
		counts[iid] = int(counts.get(iid, 0)) + 1

	# Necesitamos hp_max para calcular heal_pct
	var av = avatar
	var hp_max: int = int(av.get("hp_max", av.get("max_hp", 0)))

	# Armar salida con heal calculado
	for iid in counts.keys():
		var heal_amt: int = get_heal_amount_from_item(String(iid), hp_max)
		if heal_amt > 0:
			result.append({
				"id": String(iid),
				"count": int(counts[iid]),
				"heal": heal_amt
			})
	return result


func pick_best_heal_from_bag() -> String:
	# Elige el id curativo con MAYOR curación (heal) disponible en la bolsa
	var options: Array = bag_list_healing()
	if options.is_empty():
		return ""
	var best_id: String = ""
	var best_heal: int = -1
	for opt in options:
		var h: int = int(opt.get("heal", 0))
		if h > best_heal:
			best_heal = h
			best_id = String(opt.get("id", ""))
	return best_id

func _load_items(path: String) -> void:
	# Lee items.csv en GameData.items usando cabeceras
	items = {}
	var fa := FileAccess.open(path, FileAccess.READ)
	if fa == null:
		print("[DATA] WARN _load_items: no pude abrir ", path)
		return

	# Cabeceras
	if fa.eof_reached():
		print("[DATA] WARN _load_items: archivo vacío ", path)
		return
	var headers: PackedStringArray = fa.get_csv_line()

# Normalizar nombres esperados (id,name,kind,subkind,heal_pct,heal_hp,stackable,max_stack,rarity,tooltip_extra,price)
	var idx := {}
	for i in range(headers.size()):
		idx[String(headers[i]).strip_edges().to_lower()] = i

	var count := 0
	while not fa.eof_reached():
		var cols: PackedStringArray = fa.get_csv_line()
		if cols.size() == 0:
			continue

		# Leer con seguridad por nombre de columna
		var id := ""
		if "id" in idx and idx["id"] < cols.size():
			id = String(cols[idx["id"]]).strip_edges()
		if id == "":
			continue

		var row := {}

		# Campos texto
		row["name"] = String(cols[idx.get("name", -1)]) if idx.has("name") and idx["name"] < cols.size() else id
		row["kind"] = String(cols[idx.get("kind", -1)]).to_lower() if idx.has("kind") and idx["kind"] < cols.size() else ""
		row["subkind"] = String(cols[idx.get("subkind", -1)]).to_lower() if idx.has("subkind") and idx["subkind"] < cols.size() else ""
		row["rarity"] = String(cols[idx.get("rarity", -1)]) if idx.has("rarity") and idx["rarity"] < cols.size() else ""
		row["tooltip_extra"] = String(cols[idx.get("tooltip_extra", -1)]) if idx.has("tooltip_extra") and idx["tooltip_extra"] < cols.size() else ""

		# Números
		var heal_pct_val := 0
		if idx.has("heal_pct") and idx["heal_pct"] < cols.size():
			heal_pct_val = int(String(cols[idx["heal_pct"]]).strip_edges())
		row["heal_pct"] = heal_pct_val

		var heal_hp_val := 0
		if idx.has("heal_hp") and idx["heal_hp"] < cols.size():
			heal_hp_val = int(String(cols[idx["heal_hp"]]).strip_edges())
		row["heal_hp"] = heal_hp_val
		
		# Precio
		var price_val: int = 0
		if idx.has("price") and idx["price"] < cols.size():
			var pstr: String = String(cols[idx["price"]]).strip_edges()
			if pstr != "":
				price_val = int(pstr)
		row["price"] = price_val

		var max_stack_val := 1
		if idx.has("max_stack") and idx["max_stack"] < cols.size():
			max_stack_val = int(String(cols[idx["max_stack"]]).strip_edges())
		row["max_stack"] = max(1, max_stack_val)

		# Booleanos
		var stackable_val := false
		if idx.has("stackable") and idx["stackable"] < cols.size():
			var s := String(cols[idx["stackable"]]).strip_edges().to_lower()
			stackable_val = (s == "true" or s == "1" or s == "yes" or s == "y")
		row["stackable"] = stackable_val

		items[id] = row
		count += 1

	fa.close()
	print("[DATA] _load_items OK: ", count, " filas desde ", path)

# Nombre de display unificado para cualquier id (items/weapons/armors)
func get_item_display_name(id: String) -> String:
	var items_dict = self.get("items")
	if typeof(items_dict) == TYPE_DICTIONARY:
		var row = items_dict.get(id, {})
		if typeof(row) == TYPE_DICTIONARY:
			var nm = String(row.get("name", ""))
			if nm != "":
				return nm
	if weapons.has(id):
		return String(weapons[id].get("name", id))
	if armors.has(id):
		return String(armors[id].get("name", id))
	return id

func loot_bag_to_inventory() -> void:
	for x in loot_bag:
		var iid: String = String(x)
		give_item("inventory", iid, 1)
	loot_bag.clear()
	print("[LOOT] bag → inventory")

# ========== Combat Helpers (ATK/DEF + DR) ==========
func _cc_get(key: String, defval: float) -> float:
	var row: Dictionary = combat_constants.get("global", {})
	return float(row.get(key, defval))

func DR(x: float) -> float:
	var K_DR: float = _cc_get("K_DR", 50.0)
	return x / (x + K_DR) if x > 0.0 else 0.0

func _stats_from_actor(actor: Dictionary) -> Dictionary:
	return {
		"LV": int(actor.get("level", 1)),
		"STR": int(actor.get("str", actor.get("STR", 0))),
		"DEX": int(actor.get("dex", actor.get("DEX", 0))),
		"INT": int(actor.get("int", actor.get("INT", 0))),
	}

func _equipped_weapon_avg(actor: Dictionary) -> float:
	var wid := String(actor.get("weapon_id", ""))
	if wid != "" and weapons.has(wid):
		var w: Dictionary = weapons.get(wid, {})
		return (float(w.get("dmg_min", 0)) + float(w.get("dmg_max", 0))) / 2.0
	return 0.0

func _equipped_armor_def(actor: Dictionary) -> float:
	var total := 0.0

	# Enemigos u otros actores pueden traer armadura plana directamente
	if actor.has("armor"):
		total += float(actor.get("armor", 0))

	# Avatar/equipados: sumar pieza principal
	var aid := String(actor.get("armor_id", ""))
	if aid != "" and armors.has(aid):
		var a: Dictionary = armors.get(aid, {})
		total += float(a.get("armor", a.get("defense", 0)))

	return total

func get_primary_secondary_for_action(action_type: String, actor_stats: Dictionary) -> Dictionary:
	var STR: float = float(actor_stats.get("STR", 0))
	var DEX: float = float(actor_stats.get("DEX", 0))
	var INT: float = float(actor_stats.get("INT", 0))
	var P := 0.0
	var S := 0.0
	match action_type:
		"MELEE":
			P = STR
			S = (DEX + INT) / 2.0
		"RANGED":
			P = DEX
			S = (STR + INT) / 2.0
		"MAGIC":
			P = INT
			S = (STR + DEX) / 2.0
		_:
			# Fallback: melee
			P = STR
			S = (DEX + INT) / 2.0
	return { "P": P, "S": S }

func build_offense(actor: Dictionary, P: float, S: float) -> float:
	var st := _stats_from_actor(actor)
	var LV: float = float(st["LV"])
	var atk0: float = _cc_get("atk0", 10.0)
	var atk_lv: float = _cc_get("atk_lv", 3.0)
	var mP: float = _cc_get("mP", 0.8)
	var mS: float = _cc_get("mS", 0.3)
	var wpn_scale: float = _cc_get("wpn_scale", 1.0)
	var no_weapon_mult: float = _cc_get("no_weapon_mult", 0.6)
	var improv_scale: float = _cc_get("improv_scale", 0.1)

	var ATK_base := atk0 + atk_lv * LV
	var DR_P := DR(P)
	var DR_S := DR(S)
	var stat_mult := 1.0 + mP * DR_P + mS * DR_S

	var WPN_avg := _equipped_weapon_avg(actor)
	if WPN_avg > 0.0:
		var core_offense := ATK_base + wpn_scale * WPN_avg
		return max(1.0, core_offense * stat_mult)
	else:
		var improv := improv_scale * P
		var core_offense_noW := (ATK_base + improv) * no_weapon_mult
		return max(1.0, core_offense_noW * stat_mult)

func build_defense(actor: Dictionary) -> float:
	var st := _stats_from_actor(actor)
	var LV: float = float(st["LV"])
	var STR: float = float(st["STR"])
	var INT: float = float(st["INT"])
	var def0: float = _cc_get("def0", 8.0)
	var def_lv: float = _cc_get("def_lv", 2.5)
	var dSTR: float = _cc_get("dSTR", 20.0)
	var dINT: float = _cc_get("dINT", 20.0)

	var DEF_base := def0 + def_lv * LV
	var ARM_def := _equipped_armor_def(actor)
	var DEF_stat := dSTR * DR(STR) + dINT * DR(INT)
	var core_def := DEF_base + ARM_def + DEF_stat
	return max(0.0, core_def)
# ===================================================

func _load_combat_constants(path: String) -> void:
	combat_constants.clear()
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		print("[CONST] ERROR: no se pudo abrir:", path)
		return

	var header: PackedStringArray = f.get_csv_line()
	if header.is_empty():
		print("[CONST] WARN: CSV vacío:", path)
		return

	while not f.eof_reached():
		var row: PackedStringArray = f.get_csv_line()
		if row.is_empty():
			continue
		var id := String(row[0]).strip_edges()
		if id == "":
			continue
		var d: Dictionary = {}
		for i in range(1, header.size()):
			if i >= row.size():
				continue
			var key := String(header[i]).strip_edges()
			var val := String(row[i]).strip_edges()
			d[key] = val	# lo guardamos como String; _cc_get() lo castea a float
		combat_constants[id] = d

	var g: Dictionary = combat_constants.get("global", {})
	print("[CONST] loaded:", path, " keys(global)=", g.keys())
