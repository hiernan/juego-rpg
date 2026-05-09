extends RefCounted

class_name MissionRewardService


static func empty_rewards() -> Dictionary:
	return {
		"gold": 0,
		"xp": 0,
		"items": [],
	}


static func add_gold(rewards: Dictionary, amount: int) -> void:
	rewards["gold"] = int(rewards.get("gold", 0)) + max(amount, 0)


static func add_xp(rewards: Dictionary, amount: int) -> void:
	rewards["xp"] = int(rewards.get("xp", 0)) + max(amount, 0)


static func add_item(game_data, rewards: Dictionary, item_id: String) -> void:
	if item_id == "":
		return

	var items: Array = rewards.get("items", [])
	items.append(item_id)
	rewards["items"] = items
	game_data.loot_bag_add(item_id)


static func clear() -> Dictionary:
	return empty_rewards()


static func apply_to_avatar(game_data, rewards: Dictionary) -> void:
	game_data.avatar["gold"] = int(game_data.avatar.get("gold", 0)) + int(rewards.get("gold", 0))
	game_data.avatar["xp"] = int(game_data.avatar.get("xp", 0)) + int(rewards.get("xp", 0))

	var inventory: Array = game_data.avatar.get("inventory", [])
	for item_id in rewards.get("items", []):
		inventory.append(String(item_id))
	game_data.avatar["inventory"] = inventory


static func consume_item(game_data, rewards: Dictionary, item_id: String, heal: int) -> void:
	if item_id == "":
		return

	if heal > 0:
		game_data.heal(heal)

	if game_data.bag_has(item_id, 1):
		game_data.bag_consume(item_id, 1)

	var reward_items: Array = rewards.get("items", [])
	var reward_index: int = reward_items.find(item_id)
	if reward_index >= 0:
		reward_items.remove_at(reward_index)
		rewards["items"] = reward_items
		return

	var inventory: Array = game_data.avatar.get("inventory", [])
	var inventory_index: int = inventory.find(item_id)
	if inventory_index >= 0:
		inventory.remove_at(inventory_index)
		game_data.avatar["inventory"] = inventory
