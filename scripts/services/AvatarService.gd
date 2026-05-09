extends RefCounted

static func get_weapon_damage_range(game_data) -> Vector2i:
	var weapon_id: String = String(game_data.avatar.get("weapon_id", ""))
	if weapon_id == "" or not game_data.weapons.has(weapon_id):
		return Vector2i(1, 2)
	var weapon: Dictionary = game_data.weapons[weapon_id]
	return Vector2i(int(weapon.get("dmg_min", 1)), int(weapon.get("dmg_max", 2)))


static func get_armor_value(game_data) -> int:
	var armor_id: String = String(game_data.avatar.get("armor_id", ""))
	if armor_id == "" or not game_data.armors.has(armor_id):
		return 0
	var armor: Dictionary = game_data.armors[armor_id]
	return int(armor.get("armor", 0))


static func apply_damage(game_data, amount: int) -> void:
	var avatar: Dictionary = game_data.avatar
	var hp_max: int = int(avatar.get("hp_max", avatar.get("max_hp", 0)))
	var hp_current: int = int(avatar.get("hp", 0))
	var damage: int = max(amount, 0)
	var new_hp: int = int(max(hp_current - damage, 0))
	game_data.avatar["hp"] = new_hp
	print("[DMG] -%d HP (%d -> %d / %d)" % [damage, hp_current, new_hp, hp_max])

	if hp_max <= 0:
		return

	var threshold: int = int(ceil(float(hp_max) * game_data.auto_potion_threshold))
	var in_danger: bool = new_hp <= threshold

	if not in_danger and game_data._auto_potion_suppressed:
		game_data._auto_potion_suppressed = false

	if not in_danger:
		return

	var potion_id: String = game_data.pick_best_heal_from_bag()
	if potion_id != "" and game_data.bag_has(potion_id, 1):
		if game_data.bag_consume(potion_id, 1):
			var healed: int = game_data.apply_potion_effect(potion_id)
			print("[POTION] Auto-uso: +%d HP (restantes=%d, id=%s)" % [healed, game_data.bag_count(potion_id), potion_id])
			return

	if not game_data._auto_potion_suppressed:
		game_data._auto_potion_suppressed = true
		print("[AVATAR] Arghhh, me quede sin pociones!")


static func heal(game_data, amount: int) -> void:
	var hp: int = int(game_data.avatar["hp"])
	var max_hp: int = int(game_data.avatar["max_hp"])
	game_data.avatar["hp"] = min(max_hp, hp + max(0, amount))


static func is_dead(game_data) -> bool:
	return int(game_data.avatar["hp"]) <= 0


static func on_death(game_data) -> void:
	game_data.avatar["weapon_id"] = ""
	game_data.avatar["armor_id"] = ""
	game_data.avatar["inventory"] = []
	game_data.avatar["hp"] = game_data.avatar["max_hp"]


static func get_equipped_armor_id(game_data) -> String:
	var value: Variant = game_data.equipment.get("armor", null)
	return value if value is String else ""


static func set_equipped_armor_id(game_data, id: String) -> void:
	game_data.equipment["armor"] = id


static func get_equipped_weapon_id(game_data) -> String:
	return str(game_data.avatar.get("weapon_id", ""))


static func set_equipped_weapon_id(game_data, id: String) -> void:
	if not game_data.avatar.has("weapon_id"):
		game_data.avatar["weapon_id"] = ""
	game_data.avatar["weapon_id"] = id
	print("[GD] set_equipped_weapon_id -> ", id)
