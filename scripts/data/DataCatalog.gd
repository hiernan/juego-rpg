extends RefCounted

const DataLoadersScript = preload("res://scripts/data/DataLoaders.gd")

const DEFAULT_PATHS := {
	"enemies": "res://data/enemies.csv",
	"weapons": "res://data/weapons.csv",
	"armors": "res://data/armors.csv",
	"items": "res://data/items.csv",
	"locations": "res://data/locations.csv",
	"loot_tables": "res://data/loot_tables.csv",
	"texts": "res://data/texts.csv",
	"combat_constants": "res://data/combat_constants.csv",
	"shops": {
		"blacksmith": "res://data/shop_blacksmith.csv",
		"healer": "res://data/shop_healer.csv",
		"tavern": "res://data/shop_tavern.csv",
	},
}

static func load_all(paths: Dictionary = DEFAULT_PATHS) -> Dictionary:
	var shop_paths: Dictionary = paths.get("shops", {})
	var shops := {}
	for shop_id in shop_paths.keys():
		shops[String(shop_id)] = DataLoadersScript.load_shop(String(shop_paths[shop_id]))

	return {
		"enemies": DataLoadersScript.load_enemies(String(paths.get("enemies", ""))),
		"weapons": DataLoadersScript.load_weapons(String(paths.get("weapons", ""))),
		"armors": DataLoadersScript.load_armors(String(paths.get("armors", ""))),
		"items": DataLoadersScript.load_items(String(paths.get("items", ""))),
		"locations": DataLoadersScript.load_locations(String(paths.get("locations", ""))),
		"loot_tables": DataLoadersScript.load_loot_tables(String(paths.get("loot_tables", ""))),
		"texts": DataLoadersScript.load_texts(String(paths.get("texts", ""))),
		"combat_constants": DataLoadersScript.load_combat_constants(String(paths.get("combat_constants", ""))),
		"shops": shops,
	}
