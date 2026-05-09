extends RefCounted

class_name ShopService

static func get_shop_items(game_data, shop: String) -> Array:
	var shop_data: Dictionary = game_data.shops.get(shop, {})
	return shop_data.keys()


static func get_shop_stock(game_data, shop: String, id: String) -> int:
	var shop_data: Dictionary = game_data.shops.get(shop, {})
	if not shop_data.has(id):
		return 0
	return int((shop_data[id] as Dictionary).get("stock", -1))


static func get_item_price(game_data, id: String) -> int:
	var kind: String = game_data.get_item_kind(id)
	if kind == "weapon" and game_data.weapons.has(id):
		return int((game_data.weapons[id] as Dictionary).get("price", 0))
	if kind == "armor" and game_data.armors.has(id):
		return int((game_data.armors[id] as Dictionary).get("price", 0))
	if kind == "item" and game_data.items.has(id):
		return int((game_data.items[id] as Dictionary).get("price", 0))
	return 0


static func get_shop_price(game_data, shop: String, id: String) -> int:
	var shop_data: Dictionary = game_data.shops.get(shop, {})
	var base: int = get_item_price(game_data, id)
	if not shop_data.has(id):
		return base
	var price_override := int((shop_data[id] as Dictionary).get("price_override", -1))
	return base if price_override < 0 else price_override


static func can_afford(game_data, cost: int) -> bool:
	return int(game_data.avatar.get("gold", 0)) >= cost


static func pay_gold(game_data, cost: int) -> bool:
	if cost <= 0:
		return true
	var gold := int(game_data.avatar.get("gold", 0))
	if gold < cost:
		return false
	game_data.avatar["gold"] = gold - cost
	return true


static func add_gold(game_data, amount: int) -> void:
	if amount <= 0:
		return
	game_data.avatar["gold"] = int(game_data.avatar.get("gold", 0)) + amount


static func shop_buy(game_data, shop: String, id: String, amount: int = 1) -> bool:
	if amount <= 0:
		return false
	var shop_data: Dictionary = game_data.shops.get(shop, {})
	if not shop_data.has(id):
		return false

	var stock := int((shop_data[id] as Dictionary).get("stock", -1))
	if stock != -1 and stock < amount:
		return false

	var unit_price := get_shop_price(game_data, shop, id)
	var total := unit_price * amount
	if not pay_gold(game_data, total):
		return false

	game_data.give_item("inventory", id, amount)

	if stock != -1:
		(shop_data[id] as Dictionary)["stock"] = stock - amount
		game_data.shops[shop] = shop_data

	return true


static func shop_sell(game_data, shop: String, id: String, amount: int = 1) -> bool:
	if amount <= 0:
		return false

	var have: int = game_data.count_in_container("inventory", id)
	if have < amount:
		return false

	if not game_data.take_item("inventory", id, amount):
		return false

	var unit_price := get_shop_price(game_data, shop, id)
	var unit_sell := int(floor(float(unit_price) * game_data.sell_ratio))
	add_gold(game_data, unit_sell * amount)

	var shop_data: Dictionary = game_data.shops.get(shop, {})
	if shop_data.has(id):
		var stock := int((shop_data[id] as Dictionary).get("stock", -1))
		if stock != -1:
			(shop_data[id] as Dictionary)["stock"] = stock + amount
			game_data.shops[shop] = shop_data

	return true


static func heal_full(game_data, cost: int) -> bool:
	var hp_max := int(game_data.avatar.get("hp_max", game_data.avatar.get("max_hp", 0)))
	if hp_max <= 0:
		return false
	if not pay_gold(game_data, cost):
		return false
	game_data.avatar["hp"] = hp_max
	return true
