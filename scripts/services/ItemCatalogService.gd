extends RefCounted

static func get_item_by_id(game_data, id: String) -> Dictionary:
	var kind: String = get_item_kind(game_data, id)
	if kind == "weapon" and game_data.weapons.has(id):
		return game_data.weapons[id]
	if kind == "armor" and game_data.armors.has(id):
		return game_data.armors[id]

	if game_data.weapons.has(id):
		return game_data.weapons[id]
	if game_data.armors.has(id):
		return game_data.armors[id]
	if game_data.items.has(id):
		return game_data.items[id]

	return {}


static func get_weapon(game_data, id: String) -> Dictionary:
	if game_data.weapons.has(id):
		var weapon: Dictionary = game_data.weapons[id]
		var out: Dictionary = weapon.duplicate()
		out["id"] = id
		out["kind"] = "weapon"
		return out
	return {}


static func get_armor(game_data, id: String) -> Dictionary:
	if game_data.armors.has(id):
		var armor: Dictionary = game_data.armors[id]
		var out: Dictionary = armor.duplicate()
		out["id"] = id
		out["kind"] = "armor"
		return out
	return {}


static func get_item_name_by_id(game_data, id: String) -> String:
	if id == "":
		return ""
	if game_data.weapons.has(id):
		var weapon: Dictionary = game_data.weapons[id]
		return String(weapon.get("name", id))
	if game_data.armors.has(id):
		var armor: Dictionary = game_data.armors[id]
		return String(armor.get("name", id))
	if game_data.items.has(id):
		var item: Dictionary = game_data.items[id]
		return String(item.get("name", id))
	return id


static func get_item_kind(game_data, id: String) -> String:
	if game_data.weapons.has(id):
		return "weapon"
	if game_data.armors.has(id):
		return "armor"
	return "item"


static func get_item_display_name(game_data, id: String) -> String:
	if game_data.items.has(id):
		var item: Dictionary = game_data.items[id]
		var item_name := String(item.get("name", ""))
		if item_name != "":
			return item_name
	if game_data.weapons.has(id):
		return String(game_data.weapons[id].get("name", id))
	if game_data.armors.has(id):
		return String(game_data.armors[id].get("name", id))
	return id


static func get_item_tooltip(game_data, id: String) -> String:
	if id == "":
		return "Desconocido\n(id vacio)"

	var kind: String = get_item_kind(game_data, id)
	if kind == "":
		print("[DATA] WARN get_item_tooltip: id desconocido=", id)
		return "Desconocido\n(id: %s)" % id

	var item_name: String = get_item_display_name(game_data, id)
	match kind:
		"weapon":
			var weapon: Dictionary = game_data.weapons.get(id, {})
			var damage_min: int = int(weapon.get("dmg_min", 1))
			var damage_max: int = int(weapon.get("dmg_max", 2))
			var speed: float = float(weapon.get("speed", weapon.get("atk_speed", 1.0)))
			return "%s\nDano: %d-%d\nVelocidad: %.2f" % [item_name, damage_min, damage_max, speed]
		"armor":
			var armor: Dictionary = game_data.armors.get(id, {})
			var armor_value: int = int(armor.get("armor", armor.get("defense", 0)))
			return "%s\nDefensa: %d" % [item_name, armor_value]
		_:
			return "%s" % item_name
