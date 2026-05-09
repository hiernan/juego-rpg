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
