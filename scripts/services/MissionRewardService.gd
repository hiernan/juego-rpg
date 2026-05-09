extends RefCounted

class_name MissionRewardService

static func empty_rewards() -> Dictionary:
	return {
		"gold": 0,
		"xp": 0,
		"items": [],
	}


static func add_gold(rewards: Dictionary, amount: int) -> void:
	rewards["gold"] = int(rewards.get("gold", 0)) + max(0, amount)


static func add_xp(rewards: Dictionary, amount: int) -> void:
	rewards["xp"] = int(rewards.get("xp", 0)) + max(0, amount)


static func add_item(game_data, rewards: Dictionary, item_id: String) -> void:
	var items: Array = rewards.get("items", [])
	items.append(item_id)
	rewards["items"] = items
	game_data.loot_bag_add(item_id)


static func apply_to_avatar(game_data, rewards: Dictionary) -> void:
	game_data.add_gold(int(rewards.get("gold", 0)))
	game_data.add_xp(int(rewards.get("xp", 0)))


static func consume_item(game_data, rewards: Dictionary, item_id: String, heal: int) -> void:
	game_data.heal(heal)

	var items: Array = rewards.get("items", [])
	var idx := items.find(item_id)
	if idx >= 0:
		items.remove_at(idx)
		rewards["items"] = items
		return

	game_data.take_item("inventory", item_id, 1)


static func get_result_items(rewards: Dictionary, result_bag: Array) -> Array:
	if result_bag.size() > 0:
		return result_bag.duplicate()
	return (rewards.get("items", []) as Array).duplicate()
