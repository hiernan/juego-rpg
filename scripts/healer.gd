extends Control

const SHOP_ID := "healer"  # usa shop_healer.csv

@onready var popup_cantidad: AcceptDialog = $"HealerContainer/PopupCantidad"
@onready var label_cantidad: Label = $"HealerContainer/PopupCantidad/LabelCantidad"
@onready var spin_cantidad:  SpinBox = $"HealerContainer/PopupCantidad/SpinCantidad"

var _qty_ctx := {
	"mode": "",   # "buy" | "sell"
	"id": "",
	"shop": SHOP_ID,
	"max": 1
}

@onready var HealerContainer: Control = $"Healer"
@onready var list_shop: ItemList = $"HealerContainer/HealerVBox/HealerHBox/HealerShopPanel/HealerShopVBox/HealerShopList"
@onready var list_inv:  ItemList = $"HealerContainer/HealerVBox/HealerHBox/HealerInvPanel/HealerInvVBox/HealerInvList"
@onready var lbl_gold:  Label    = $"HealerContainer/HealerVBox/TopBar/GoldLabel"
@onready var btn_close: BaseButton = $"HealerContainer/HealerVBox/TopBar/BtnCerrar"
@onready var btn_heal:  BaseButton = $"HealerContainer/HealerVBox/TopBar/BtnCurar"  # añadí este botón en la TopBar

func _ready() -> void:
	_refresh_gold()
	_refresh_shop_list()
	_refresh_inventory_list()

	if btn_close and not btn_close.is_connected("pressed", Callable(self, "_on_close_pressed")):
		btn_close.connect("pressed", Callable(self, "_on_close_pressed"))

	if btn_heal and not btn_heal.is_connected("pressed", Callable(self, "_on_heal_pressed")):
		btn_heal.connect("pressed", Callable(self, "_on_heal_pressed"))
	
	if not list_inv.is_connected("drop_on_healer", Callable(self, "_on_drop_healer_from_shop")):
		list_inv.connect("drop_on_healer", Callable(self, "_on_drop_healer_from_shop"))
	if not list_shop.is_connected("drop_on_shop", Callable(self, "_on_drop_shop_from_inventory")):
		list_shop.connect("drop_on_shop", Callable(self, "_on_drop_shop_from_inventory"))
	
	if popup_cantidad and not popup_cantidad.is_connected("confirmed", Callable(self, "_on_qty_confirmed")):
		popup_cantidad.connect("confirmed", Callable(self, "_on_qty_confirmed"))
	if popup_cantidad and not popup_cantidad.is_connected("canceled", Callable(self, "_on_qty_canceled")):
		popup_cantidad.connect("canceled", Callable(self, "_on_qty_canceled"))


# ---------- Poblar listas ----------
func _refresh_shop_list() -> void:
	if list_shop == null:
		return
	list_shop.clear()
	var ids: Array = GameData.get_shop_items(SHOP_ID)
	for v in ids:
		var id := String(v)
		var name := GameData.get_item_display_name(id)
		var price := GameData.get_shop_price(SHOP_ID, id)
		var label := "%s  (%d oro)" % [name, price]
		var idx := list_shop.add_item(label)
		list_shop.set_item_metadata(idx, id)
		var tip := GameData.get_item_tooltip(id)
		if tip != "":
			list_shop.set_item_tooltip(idx, tip)

func _refresh_inventory_list() -> void:
	if list_inv == null:
		return
	list_inv.clear()

	# Solo mostrar curativas (subkind=heal) que estén en el inventario
	var counts := {}
	var inv: Array = GameData.get_container_items("inventory")
	for v in inv:
		var id := String(v)
		var row: Dictionary = GameData.items.get(id, {})
		if row.get("subkind", "") != "heal":
			continue
		counts[id] = int(counts.get(id, 0)) + 1

	for id_key in counts.keys():
		var id := String(id_key)
		var n := int(counts[id])
		var label := GameData.get_item_display_name(id)
		if n > 1:
			label = "%s (x%d)" % [label, n]
		var idx := list_inv.add_item(label)
		list_inv.set_item_metadata(idx, id)
		var tip := GameData.get_item_tooltip(id)
		if tip != "":
			list_inv.set_item_tooltip(idx, tip)

func _refresh_gold() -> void:
	if lbl_gold:
		lbl_gold.text = "Oro: %d" % GameData.get_gold()

# ---------- Botones ----------
func _on_close_pressed() -> void:
	get_tree().change_scene_to_file("res://Town.tscn")

func _on_heal_pressed() -> void:
	# costo simple (luego lo sacamos a CSV si querés)
	var COST := 10
	var hp := GameData.get_hp()
	var max_hp := GameData.get_max_hp()

	if max_hp <= 0:
		return
	if hp >= max_hp:
		print("[HEALER] Ya estás al máximo.")
		return
	if not GameData.can_afford(COST):
		print("[HEALER] Te falta oro. Necesitás %d." % COST)
		return

	GameData.pay_gold(COST)
	GameData.heal(max_hp)
	print("[HEALER] Curado por %d oro → HP %d/%d" % [COST, max_hp, max_hp])

	_refresh_gold()
	_refresh_inventory_list()  # por si más adelante consumimos algo

func _on_drop_healer_from_shop(id: String) -> void:
	# Si es stackeable y hay stock > 1, abrimos popup
	if _is_stackable(id):
		var stock: int = GameData.get_shop_stock(SHOP_ID, id)  # -1 = infinito
		var max_sel: int = stock if stock >= 1 else 20  # por cortesía, si es infinito, capea a 20
		if max_sel > 1:
			_open_qty_popup("buy", id, max_sel)
			return
	# Default: comprar 1
	var ok := GameData.shop_buy(SHOP_ID, id, 1)
	print("[HEALER] buy id=%s -> %s" % [id, ok])
	_refresh_gold(); _refresh_shop_list(); _refresh_inventory_list()

func _on_drop_shop_from_inventory(id: String) -> void:
	# Solo vender curativas acá (lo que mostrás en la lista); si quisieras vender otras,
	# sacá este filtro.
	var row: Dictionary = GameData.items.get(id, {})
	if String(row.get("subkind", "")) != "heal":
		return
	if _is_stackable(id):
		var cnt: int = _count_in_inventory(id)
		if cnt > 1:
			_open_qty_popup("sell", id, cnt)
			return
	# Default: vender 1
	var ok := GameData.shop_sell(SHOP_ID, id, 1)
	print("[HEALER] sell id=%s -> %s" % [id, ok])
	_refresh_gold(); _refresh_shop_list(); _refresh_inventory_list()

func _is_stackable(id: String) -> bool:
	var row: Dictionary = GameData.items.get(id, {})
	return bool(row.get("stackable", false))

func _count_in_inventory(id: String) -> int:
	return GameData.count_in_container("inventory", id)

func _open_qty_popup(mode: String, id: String, max_sel: int) -> void:
	_qty_ctx.mode = mode
	_qty_ctx.id = id
	_qty_ctx.shop = SHOP_ID
	_qty_ctx.max = max(1, max_sel)
	if label_cantidad:
		label_cantidad.visible = false
	if spin_cantidad:
		spin_cantidad.min_value = 1
		spin_cantidad.max_value = _qty_ctx.max
		spin_cantidad.value = _qty_ctx.max
	if popup_cantidad:
		popup_cantidad.popup_centered()

func _on_qty_confirmed() -> void:
	var id: String = String(_qty_ctx.id)
	var amount: int = int(spin_cantidad.value)
	amount = clamp(amount, 1, int(_qty_ctx.max))

	var ok: bool = false
	if _qty_ctx.mode == "buy":
		ok = GameData.shop_buy(_qty_ctx.shop, id, amount)
		print("[HEALER] buy x%d id=%s -> %s" % [amount, id, ok])
	else:
		ok = GameData.shop_sell(_qty_ctx.shop, id, amount)
		print("[HEALER] sell x%d id=%s -> %s" % [amount, id, ok])

	_qty_ctx.mode = ""; _qty_ctx.id = ""; _qty_ctx.max = 1
	_refresh_gold(); _refresh_shop_list(); _refresh_inventory_list()

func _on_qty_canceled() -> void:
	_qty_ctx.mode = ""; _qty_ctx.id = ""; _qty_ctx.max = 1
