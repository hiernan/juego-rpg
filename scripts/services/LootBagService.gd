extends RefCounted

static func reset(game_data) -> void:
	game_data.loot_bag = []
	print("[LOOT] reset")


static func add(game_data, id: String) -> void:
	if id == "":
		print("[LOOT] WARN: id vacio")
		return
	var kind: String = game_data.get_item_kind(id)
	if kind == "":
		print("[LOOT] WARN: id desconocido=", id)
		return
	game_data.loot_bag.append(String(id))
	print("[LOOT] add id=", id, " bag_size=", game_data.loot_bag.size())


static func consolidate_to_inventory(game_data) -> void:
	var inventory: Array = game_data._get_container_ref("inventory")
	for id in game_data.loot_bag:
		inventory.append(String(id))
	game_data._set_container_ref("inventory", inventory)
	print("[LOOT] consolidate -> +", game_data.loot_bag.size(), " items a inventario (total inv=", inventory.size(), ")")
	game_data.loot_bag = []


static func on_mission_success(game_data) -> void:
	print("[MISSION] success: consolidating loot bag")
	consolidate_to_inventory(game_data)


static func on_mission_abandon(game_data) -> void:
	print("[MISSION] abandon: consolidating loot bag")
	consolidate_to_inventory(game_data)


static func on_mission_death(game_data) -> void:
	print("[DEATH] mission death: losing loot bag, inventory and equipped")
	game_data.loot_bag = []
	game_data._set_container_ref("inventory", [])
	game_data._set_container_ref("equipped_weapon", "")
	game_data._set_container_ref("equipped_armor", "")


static func transfer_inventory_to_bag(game_data) -> void:
	var inventory: Array = []
	var inventory_ref: Variant = game_data._get_container_ref("inventory")
	if typeof(inventory_ref) == TYPE_ARRAY:
		inventory = inventory_ref
	else:
		var avatar_inventory: Variant = game_data.avatar.get("inventory", [])
		if typeof(avatar_inventory) == TYPE_ARRAY:
			inventory = avatar_inventory

	var moved: int = inventory.size()
	for id in inventory:
		game_data.loot_bag.append(String(id))

	game_data._set_container_ref("inventory", [])
	if "inventory" in game_data.avatar:
		game_data.avatar["inventory"] = []
	print("[LOOT] transfer_inventory_to_bag: moved=", moved, " bag_size=", game_data.loot_bag.size())


static func count(game_data, id: String) -> int:
	if id == "":
		return 0
	var total := 0
	for item_id in game_data.loot_bag:
		if String(item_id) == String(id):
			total += 1
	return total


static func has(game_data, id: String, amount: int = 1) -> bool:
	return count(game_data, id) >= max(1, amount)


static func consume(game_data, id: String, amount: int = 1) -> bool:
	if id == "" or amount <= 0:
		return false

	var removed := 0
	for i in range(game_data.loot_bag.size() - 1, -1, -1):
		if removed >= amount:
			break
		if String(game_data.loot_bag[i]) == String(id):
			game_data.loot_bag.remove_at(i)
			removed += 1

	var ok := removed == amount
	print("[LOOT] bag_consume id=", id, " amount=", amount, " ok=", ok, " bag_size=", game_data.loot_bag.size())
	return ok


static func apply_potion_effect(game_data, id: String) -> int:
	var avatar: Dictionary = game_data.avatar
	var hp_max: int = int(avatar.get("hp_max", avatar.get("max_hp", 0)))
	var hp_current: int = int(avatar.get("hp", 0))
	var heal: int = get_heal_amount_from_item(game_data, id, hp_max)

	if heal > 0 and hp_max > 0:
		var new_hp: int = min(hp_current + heal, hp_max)
		game_data.avatar["hp"] = new_hp
		print("[POTION] use id=%s +%d HP (%d->%d/%d)" % [id, heal, hp_current, new_hp, hp_max])
	else:
		print("[POTION] WARN: sin curacion valida para id=", id)
	return heal


static func is_healing_item(game_data, id: String) -> bool:
	var items_dict: Variant = game_data.get("items")
	if typeof(items_dict) != TYPE_DICTIONARY:
		return false
	var row: Variant = items_dict.get(id, {})
	if typeof(row) != TYPE_DICTIONARY:
		return false
	var kind: String = String(row.get("kind", ""))
	var subkind: String = String(row.get("subkind", ""))
	return kind == "consumable" and subkind == "heal"


static func get_heal_amount_from_item(game_data, id: String, hp_max: int) -> int:
	var items_dict: Variant = game_data.get("items")
	if typeof(items_dict) != TYPE_DICTIONARY:
		return 0
	var row: Variant = items_dict.get(id, {})
	if typeof(row) != TYPE_DICTIONARY:
		return 0

	var heal_pct: int = int(row.get("heal_pct", 0))
	var heal_hp: int = int(row.get("heal_hp", 0))

	if heal_pct > 0 and hp_max > 0:
		var amount: int = int(ceil(float(hp_max) * float(heal_pct) * 0.01))
		return max(amount, 1)
	return max(heal_hp, 0)


static func list_healing(game_data) -> Array:
	var result: Array = []
	var items_dict: Variant = game_data.get("items")
	if typeof(items_dict) != TYPE_DICTIONARY:
		return result

	var counts: Dictionary = {}
	for item_id in game_data.loot_bag:
		var id := String(item_id)
		var row: Variant = items_dict.get(id, {})
		if typeof(row) != TYPE_DICTIONARY:
			continue
		var kind: String = String(row.get("kind", ""))
		var subkind: String = String(row.get("subkind", ""))
		if not (kind == "consumable" and subkind == "heal"):
			continue
		counts[id] = int(counts.get(id, 0)) + 1

	var avatar: Dictionary = game_data.avatar
	var hp_max: int = int(avatar.get("hp_max", avatar.get("max_hp", 0)))
	for id in counts.keys():
		var heal_amount: int = get_heal_amount_from_item(game_data, String(id), hp_max)
		if heal_amount > 0:
			result.append({
				"id": String(id),
				"count": int(counts[id]),
				"heal": heal_amount,
			})
	return result


static func pick_best_heal_from_bag(game_data) -> String:
	var options: Array = list_healing(game_data)
	if options.is_empty():
		return ""

	var best_id := ""
	var best_heal := -1
	for option in options:
		var heal: int = int(option.get("heal", 0))
		if heal > best_heal:
			best_heal = heal
			best_id = String(option.get("id", ""))
	return best_id


static func bag_to_inventory(game_data) -> void:
	for item_id in game_data.loot_bag:
		game_data.give_item("inventory", String(item_id), 1)
	game_data.loot_bag.clear()
	print("[LOOT] bag -> inventory")
