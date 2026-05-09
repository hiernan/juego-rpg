extends Control

const SHOP_ID := "blacksmith"

@onready var BlacksmithContainer: Control = $"Blacksmith"
@onready var list_shop: ItemList = $"BlacksmithContainer/BlacksmithVBox/BlacksmithHBox/BlacksmithShopPanel/BlacksmithShopVBox/BlacksmithShopList"
@onready var list_inv:  ItemList = $"BlacksmithContainer/BlacksmithVBox/BlacksmithHBox/BlacksmithInvPanel/BlacksmithInvVBox/BlacksmithInvList"
@onready var lbl_gold:  Label    = $"BlacksmithContainer/BlacksmithVBox/TopBar/GoldLabel"
@onready var btn_close: BaseButton = $"BlacksmithContainer/BlacksmithVBox/TopBar/BtnCerrar"

func _ready() -> void:
	_refresh_gold()
	_refresh_shop_list()
	_refresh_inventory_list()

	# Drag & Drop: vender desde inventario → tienda
	if list_shop and not list_shop.is_connected("drop_on_shop", Callable(self, "_on_drop_shop_from_inventory")):
		list_shop.connect("drop_on_shop", Callable(self, "_on_drop_shop_from_inventory"))
	# Drag & Drop: comprar desde tienda → inventario
	if list_inv and not list_inv.is_connected("drop_on_blacksmith", Callable(self, "_on_drop_blacksmith_from_shop")):
		list_inv.connect("drop_on_blacksmith", Callable(self, "_on_drop_blacksmith_from_shop"))

	if btn_close and not btn_close.is_connected("pressed", Callable(self, "_on_close_pressed")):
		btn_close.connect("pressed", Callable(self, "_on_close_pressed"))

	if not list_shop.is_connected("drop_on_shop", Callable(self, "_on_drop_shop_from_inventory")):
		list_shop.connect("drop_on_shop", Callable(self, "_on_drop_shop_from_inventory"))

	if not list_inv.is_connected("drop_on_blacksmith", Callable(self, "_on_drop_blacksmith_from_shop")):
		list_inv.connect("drop_on_blacksmith", Callable(self, "_on_drop_blacksmith_from_shop"))

# --------- Poblar listas ---------
func _refresh_shop_list() -> void:
	if list_shop == null:
		return
	list_shop.clear()
	var ids: Array = GameData.get_shop_items(SHOP_ID)
	for v in ids:
		var id: String = String(v)
		var name: String = GameData.get_item_display_name(id)
		var price: int = GameData.get_shop_price(SHOP_ID, id)
		var label: String = "%s  (%d oro)" % [name, price]
		var idx: int = list_shop.add_item(label)
		list_shop.set_item_metadata(idx, id)
		var tip: String = GameData.get_item_tooltip(id)
		if tip != "":
			list_shop.set_item_tooltip(idx, tip)

func _refresh_inventory_list() -> void:
	if list_inv == null:
		return
	list_inv.clear()

	var inv: Array = GameData.get_container_items("inventory")
	for v in inv:
		var id: String = String(v)
		# Mostrar SOLO armas y armaduras (no stackean)
		var kind: String = GameData.get_item_kind(id)
		if kind != "weapon" and kind != "armor":
			continue
		var label: String = GameData.get_item_display_name(id)
		var idx: int = list_inv.add_item(label)
		list_inv.set_item_metadata(idx, id)
		var tip: String = GameData.get_item_tooltip(id)
		if tip != "":
			list_inv.set_item_tooltip(idx, tip)

func _refresh_gold() -> void:
	if lbl_gold:
		lbl_gold.text = "Oro: %d" % GameData.get_gold()

# --------- Handlers DnD ---------
# Comprar 1 (tienda → inventario)
func _on_drop_blacksmith_from_shop(id: String) -> void:
	# Armas/armaduras no stackean: siempre 1
	var ok: bool = GameData.shop_buy(SHOP_ID, id, 1)
	print("[BLACKSMITH] buy id=%s -> %s" % [id, ok])
	_refresh_gold()
	_refresh_shop_list()
	_refresh_inventory_list()

# Vender 1 (inventario → tienda)
func _on_drop_shop_from_inventory(id: String) -> void:
	# Sólo vender armas/armaduras acá
	var k: String = GameData.get_item_kind(id)
	if k != "weapon" and k != "armor":
		return
	var ok: bool = GameData.shop_sell(SHOP_ID, id, 1)
	print("[BLACKSMITH] sell id=%s -> %s" % [id, ok])
	_refresh_gold()
	_refresh_shop_list()
	_refresh_inventory_list()

# --------- Cerrar ---------
func _on_close_pressed() -> void:
	get_tree().change_scene_to_file("res://Town.tscn")
