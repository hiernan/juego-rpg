extends RefCounted

class_name InventoryService

const CONTAINERS := {
	"inventory": true,
	"stash": true,
	"equipped_weapon": true,
	"equipped_armor": true,
}

static func add_item_to_container(game_data, container_name: String, id: String, count: int) -> void:
	if not game_data.avatar.has(container_name):
		game_data.avatar[container_name] = []
	var arr: Array = game_data.avatar[container_name]
	for i in range(count):
		arr.append(id)
	game_data.avatar[container_name] = arr


static func remove_item_from_container(game_data, container_name: String, id: String, count: int) -> void:
	if not game_data.avatar.has(container_name):
		return
	var arr: Array = game_data.avatar[container_name]
	var removed: int = 0
	while removed < count and arr.has(id):
		arr.erase(id)
		removed += 1
	game_data.avatar[container_name] = arr


static func is_stackable(game_data, id: String) -> bool:
	var kind: String = game_data.get_item_kind(id)
	return kind == "item"


static func get_container_ref(game_data, name: String) -> Variant:
	if name == "inventory":
		return game_data.avatar.get("inventory", [])
	if name == "stash":
		return game_data.avatar.get("stash", [])
	if name == "equipped_weapon":
		return game_data.avatar.get("weapon_id", "")
	if name == "equipped_armor":
		return game_data.avatar.get("armor_id", "")
	return null


static func set_container_ref(game_data, name: String, value: Variant) -> void:
	match name:
		"inventory":
			game_data.avatar["inventory"] = value
		"stash":
			game_data.avatar["stash"] = value
		"equipped_weapon":
			game_data.avatar["weapon_id"] = String(value)
		"equipped_armor":
			game_data.avatar["armor_id"] = String(value)
		_:
			pass


static func take_item(game_data, from: String, id: String, amount: int = 1) -> bool:
	var ref: Variant = get_container_ref(game_data, from)
	if typeof(ref) == TYPE_ARRAY:
		var arr: Array = ref
		var removed: int = 0
		var i: int = arr.size() - 1
		while i >= 0 and removed < amount:
			if String(arr[i]) == String(id):
				arr.remove_at(i)
				removed += 1
			i -= 1

		if removed > 0:
			set_container_ref(game_data, from, arr)
		return removed >= amount

	if amount != 1:
		return false
	var cur: String = String(ref)
	if cur == String(id):
		set_container_ref(game_data, from, "")
		return true
	return false


static func give_item(game_data, to: String, id: String, amount: int = 1) -> bool:
	var ref: Variant = get_container_ref(game_data, to)
	if typeof(ref) == TYPE_ARRAY:
		var arr: Array = ref
		for i in range(amount):
			arr.append(String(id))
		set_container_ref(game_data, to, arr)
		return true

	var cur := String(ref)
	if cur == "":
		set_container_ref(game_data, to, String(id))
		return true
	return false


static func count_in_container(game_data, container: String, id: String) -> int:
	if container.begins_with("equipped"):
		var cur := String(get_container_ref(game_data, container))
		return 1 if cur == id else 0

	var ref: Variant = get_container_ref(game_data, container)
	if typeof(ref) != TYPE_ARRAY:
		return 0

	var count: int = 0
	for item_id in ref:
		if String(item_id) == id:
			count += 1
	return count


static func move_item_between_containers(game_data, from: String, to: String, id: String, amount: int) -> bool:
	if id == "":
		return false

	var av: Dictionary = game_data.avatar
	var inv: Array = av.get("inventory", [])
	var stash: Array = av.get("stash", [])
	var wid: String = str(av.get("weapon_id", ""))
	var aid: String = str(av.get("armor_id", ""))

	var removed: bool = false

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
		return false

	if to == "inventory":
		inv.append(id)
	elif to == "stash":
		stash.append(id)
	elif to == "equipped_weapon":
		if wid != "":
			inv.append(wid)
		av["weapon_id"] = id
	elif to == "equipped_armor":
		if aid != "":
			inv.append(aid)
		av["armor_id"] = id
	else:
		inv.append(id)

	av["inventory"] = inv
	av["stash"] = stash
	game_data.avatar = av

	return true


static func move_item(game_data, from: String, to: String, id: String, qty: int = 1) -> bool:
	if id == "" or not CONTAINERS.has(from) or not CONTAINERS.has(to):
		return false
	if from == to:
		return true

	var kind: String = game_data.get_item_kind(id)
	var stack: bool = is_stackable(game_data, id)
	var from_ref: Variant = get_container_ref(game_data, from)

	var removed := false
	if stack:
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
			set_container_ref(game_data, from, arr)
		else:
			return false
	else:
		if from == "equipped_weapon" or from == "equipped_armor":
			if String(from_ref) == id:
				removed = true
				set_container_ref(game_data, from, "")
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
			set_container_ref(game_data, from, arr2)

	if not removed:
		return false

	if to == "inventory" or to == "stash":
		var arr3: Array = get_container_ref(game_data, to)
		arr3.append(id)
		set_container_ref(game_data, to, arr3)
		return true

	if to == "equipped_weapon" and kind != "weapon":
		move_item(game_data, to, from, id, 1)
		return false
	if to == "equipped_armor" and kind != "armor":
		move_item(game_data, to, from, id, 1)
		return false

	var prev: Variant = get_container_ref(game_data, to)
	if String(prev) != "":
		var inv: Array = get_container_ref(game_data, "inventory")
		inv.append(String(prev))
		set_container_ref(game_data, "inventory", inv)

	set_container_ref(game_data, to, id)
	return true


static func swap_equip(game_data, slot_kind: String, new_id: String) -> bool:
	if new_id == "":
		return false

	var expected_kind: String = slot_kind
	var kind: String = game_data.get_item_kind(new_id)
	if kind != expected_kind:
		return false

	var slot_name := ""
	if slot_kind == "weapon":
		slot_name = "equipped_weapon"
	elif slot_kind == "armor":
		slot_name = "equipped_armor"
	else:
		return false

	var current := String(get_container_ref(game_data, slot_name))
	set_container_ref(game_data, slot_name, String(new_id))

	if current != "" and current != new_id:
		var inv: Array = get_container_ref(game_data, "inventory")
		if typeof(inv) == TYPE_ARRAY:
			inv.append(current)
			set_container_ref(game_data, "inventory", inv)

	return true


static func get_equipped_id(game_data, slot_kind: String) -> String:
	if slot_kind == "weapon":
		return String(get_container_ref(game_data, "equipped_weapon"))
	if slot_kind == "armor":
		return String(get_container_ref(game_data, "equipped_armor"))
	return ""
