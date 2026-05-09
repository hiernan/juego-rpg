extends Node

const InventoryServiceScript = preload("res://scripts/services/InventoryService.gd")
const ShopServiceScript = preload("res://scripts/services/ShopService.gd")
const CombatFormulaServiceScript = preload("res://scripts/services/CombatFormulaService.gd")
const LootBagServiceScript = preload("res://scripts/services/LootBagService.gd")
const ItemCatalogServiceScript = preload("res://scripts/services/ItemCatalogService.gd")
const AvatarServiceScript = preload("res://scripts/services/AvatarService.gd")
const DataLoadersScript = preload("res://scripts/data/DataLoaders.gd")
const DataCatalogScript = preload("res://scripts/data/DataCatalog.gd")

# --- Diccionarios globales (por id) ---
var enemies: Dictionary = {}			# id: {name, hp_min, hp_max, ...}
var weapons: Dictionary = {}			# id: {name, slot, dmg_min, ...}
var armors: Dictionary = {}				# id: {name, slot, armor, ...}
var locations: Dictionary = {}			# id: {name, flavor_ids[], monster_ids[], ...}
var loot_tables: Dictionary = {}		# id: [{type, weight}, ...]
var texts: Dictionary = {}				# id: {type, text_es}
var items: Dictionary = {}
var loot_bag: Array = []
var auto_potion_threshold: float = 0.25	# 25%
var auto_potion_item_id: String = "potion_small"
var _auto_potion_suppressed: bool = false	# evita spameo hasta salir del umbral
var combat_constants := {}

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
	return AvatarServiceScript.get_weapon_damage_range(self)

func get_armor_value() -> int:
	return AvatarServiceScript.get_armor_value(self)

func apply_damage(amount: int) -> void:
	AvatarServiceScript.apply_damage(self, amount)

func heal(amount: int) -> void:
	AvatarServiceScript.heal(self, amount)

func is_dead() -> bool:
	return AvatarServiceScript.is_dead(self)

func on_death() -> void:
	AvatarServiceScript.on_death(self)

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
	var catalog := DataCatalogScript.load_all()
	enemies = catalog.get("enemies", {})
	weapons = catalog.get("weapons", {})
	armors = catalog.get("armors", {})
	items = catalog.get("items", {})
	locations = catalog.get("locations", {})
	loot_tables = catalog.get("loot_tables", {})
	texts = catalog.get("texts", {})
	combat_constants = catalog.get("combat_constants", {})
	shops = catalog.get("shops", {})

# --- Tiendas / Economía ---
var shops: Dictionary = {
	"blacksmith": {},	# id -> { stock:int, price_override:int|-1 }
	"healer": {},
	"tavern": {}
}
var sell_ratio: float = 0.60	# el jugador vende al 60% del precio de compra
var heal_full_cost: int = 15	# costo base de curar al 100% (overrideable más adelante)

func _load_shop(shop: String, path: String) -> void:
	shops[shop] = DataLoadersScript.load_shop(path)

func get_shop_items(shop: String) -> Array:
	return ShopServiceScript.get_shop_items(self, shop)

func get_shop_stock(shop: String, id: String) -> int:
	return ShopServiceScript.get_shop_stock(self, shop, id)

func get_shop_price(shop: String, id: String) -> int:
	return ShopServiceScript.get_shop_price(self, shop, id)


# --- Loaders específicos ---
func _load_enemies(path: String) -> void:
	enemies = DataLoadersScript.load_enemies(path)

func _load_weapons(path: String) -> void:
	weapons = DataLoadersScript.load_weapons(path)

func _load_armors(path: String) -> void:
	armors = DataLoadersScript.load_armors(path)

func get_item_by_id(id: String) -> Dictionary:
	return ItemCatalogServiceScript.get_item_by_id(self, id)

func _load_locations(path: String) -> void:
	locations = DataLoadersScript.load_locations(path)

func _load_loot_tables(path: String) -> void:
	loot_tables = DataLoadersScript.load_loot_tables(path)

func _load_texts(path: String) -> void:
	texts = DataLoadersScript.load_texts(path)

func get_equipped_armor_id() -> String:
	return AvatarServiceScript.get_equipped_armor_id(self)

func set_equipped_armor_id(id: String) -> void:
	AvatarServiceScript.set_equipped_armor_id(self, id)

func equip_weapon(id: String, from_src: String) -> void:
	move_item(from_src, "equipped_weapon", id, 1)

func get_equipped_weapon_id() -> String:
	return AvatarServiceScript.get_equipped_weapon_id(self)

func set_equipped_weapon_id(id: String) -> void:
	AvatarServiceScript.set_equipped_weapon_id(self, id)

func inventory_add(id: String) -> void:
	give_item("inventory", id, 1)

func inventory_remove_first(id: String) -> bool:
	return take_item("inventory", id, 1)

func stash_remove_first(id: String) -> bool:
	return take_item("stash", id, 1)

func add_item_to_inventory(id: String, qty: int = 1) -> void:
	give_item("inventory", id, qty)

func add_item_to_stash(id: String, qty: int = 1) -> void:
	give_item("stash", id, qty)

func remove_item_from_inventory(id: String, qty: int = 1) -> void:
	take_item("inventory", id, qty)

func remove_item_from_stash(id: String, qty: int = 1) -> void:
	take_item("stash", id, qty)

func remove_item_from_source(id: String, from_src: String, qty: int = 1) -> void:
	match from_src:
		"inventory":
			take_item("inventory", id, qty)
		"stash", "baul":
			take_item("stash", id, qty)

# Devuelve el diccionario de un arma por id (o {} si no existe).
func get_weapon(id: String) -> Dictionary:
	return ItemCatalogServiceScript.get_weapon(self, id)

# (Opcional, por paridad con armas; no rompe nada dejarla.)
func get_armor(id: String) -> Dictionary:
	return ItemCatalogServiceScript.get_armor(self, id)

func get_item_name_by_id(id: String) -> String:
	return ItemCatalogServiceScript.get_item_name_by_id(self, id)

func get_item_tooltip(id: String) -> String:
	return ItemCatalogServiceScript.get_item_tooltip(self, id)

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
	return ItemCatalogServiceScript.get_item_kind(self, id)

func move_item_between_containers(from: String, to: String, id: String, amount: int) -> bool:
	return InventoryServiceScript.move_item_between_containers(self, from, to, id, amount)


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
	return InventoryServiceScript.move_item(self, from, to, id, qty)

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
	return InventoryServiceScript.swap_equip(self, slot_kind, new_id)


# ─────────────────────────────────────────────────────────────────────

func get_equipped_id(slot_kind: String) -> String:
	return InventoryServiceScript.get_equipped_id(self, slot_kind)


# ─────────────────────────────────────────────────────────────────────
# LOOT BAG — bolsa temporal de botín durante misión

func count_in_container(container: String, id: String) -> int:
	return InventoryServiceScript.count_in_container(self, container, id)

func get_container_items(container: String) -> Array:
	var ref: Variant = _get_container_ref(container)
	if typeof(ref) == TYPE_ARRAY:
		return (ref as Array).duplicate()
	return []

func get_gold() -> int:
	return int(avatar.get("gold", 0))

func add_xp(amount: int) -> void:
	avatar["xp"] = int(avatar.get("xp", 0)) + max(0, amount)

func loot_bag_reset() -> void:
	LootBagServiceScript.reset(self)

func loot_bag_add(id: String) -> void:
	LootBagServiceScript.add(self, id)

func consolidate_loot_bag_to_inventory() -> void:
	LootBagServiceScript.consolidate_to_inventory(self)

func on_mission_success() -> void:
	LootBagServiceScript.on_mission_success(self)

func on_mission_abandon() -> void:
	LootBagServiceScript.on_mission_abandon(self)

func on_mission_death() -> void:
	LootBagServiceScript.on_mission_death(self)

func transfer_inventory_to_bag() -> void:
	LootBagServiceScript.transfer_inventory_to_bag(self)

func bag_count(id: String) -> int:
	return LootBagServiceScript.count(self, id)

func bag_has(id: String, amount: int = 1) -> bool:
	return LootBagServiceScript.has(self, id, amount)

func bag_consume(id: String, amount: int = 1) -> bool:
	return LootBagServiceScript.consume(self, id, amount)

func apply_potion_effect(id: String) -> int:
	return LootBagServiceScript.apply_potion_effect(self, id)

func is_healing_item(id: String) -> bool:
	return LootBagServiceScript.is_healing_item(self, id)

func get_heal_amount_from_item(id: String, hp_max: int) -> int:
	return LootBagServiceScript.get_heal_amount_from_item(self, id, hp_max)

func bag_list_healing() -> Array:
	return LootBagServiceScript.list_healing(self)

func pick_best_heal_from_bag() -> String:
	return LootBagServiceScript.pick_best_heal_from_bag(self)

func _load_items(path: String) -> void:
	items = DataLoadersScript.load_items(path)

# Nombre de display unificado para cualquier id (items/weapons/armors)
func get_item_display_name(id: String) -> String:
	return ItemCatalogServiceScript.get_item_display_name(self, id)

func loot_bag_to_inventory() -> void:
	LootBagServiceScript.bag_to_inventory(self)

# ========== Combat Helpers (ATK/DEF + DR) ==========
func _cc_get(key: String, defval: float) -> float:
	return CombatFormulaServiceScript.cc_get(self, key, defval)

func DR(x: float) -> float:
	return CombatFormulaServiceScript.damage_reduction(self, x)

func _stats_from_actor(actor: Dictionary) -> Dictionary:
	return CombatFormulaServiceScript.stats_from_actor(actor)

func _equipped_weapon_avg(actor: Dictionary) -> float:
	return CombatFormulaServiceScript.equipped_weapon_avg(self, actor)

func _equipped_armor_def(actor: Dictionary) -> float:
	return CombatFormulaServiceScript.equipped_armor_def(self, actor)

func get_primary_secondary_for_action(action_type: String, actor_stats: Dictionary) -> Dictionary:
	return CombatFormulaServiceScript.get_primary_secondary_for_action(action_type, actor_stats)

func build_offense(actor: Dictionary, P: float, S: float) -> float:
	return CombatFormulaServiceScript.build_offense(self, actor, P, S)

func build_defense(actor: Dictionary) -> float:
	return CombatFormulaServiceScript.build_defense(self, actor)
# ===================================================

func _load_combat_constants(path: String) -> void:
	combat_constants.clear()
	combat_constants = DataLoadersScript.load_combat_constants(path)
