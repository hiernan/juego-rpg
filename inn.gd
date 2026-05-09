extends Control

# ─────────────────────────────────────────────────────────────────────
# Inventario — Controlador central de DnD (Paso 1: esqueleto/logs)
var current_drag: Dictionary = {
	"id": "",
	"kind": "",
	"from": "",
	"origin_ref": null,
	"removed_from_origin": false
}
# Paso 4.1 — controlador central (commit al soltar) deshabilitado por defecto
var _controller_enabled: bool = true
var _drag_committed: bool = false
var _handling_drop: bool = false
# ─────────────────────────────────────────────────────────────────────

@onready var sheet: PanelContainer = %SheetPanel
@onready var btn_chest: BaseButton = %ChestButton
@onready var btn_close: Button = %BtnCerrar
@onready var glow_chest: Sprite2D = $GlowChest

# Info
@onready var lbl_name: Label  = %LabelName
@onready var lbl_level: Label = %LabelLevel
@onready var lbl_hp: Label    = %LabelHP
@onready var lbl_gold: Label  = %LabelGold
@onready var lbl_stats: Label = %LabelStats

# Inventario (PJ)
@onready var inv_list: ItemList = %InvList
@onready var btn_equipar: Button = %BtnEquipar
@onready var btn_enviar_baul: Button = %BtnEnviarBaul

# Baúl (stash)
@onready var baul_list: ItemList = %BaulList
@onready var btn_retirar: Button = %BtnRetirar

# Slots de equipo
@onready var slot_weapon: BaseButton = %Slot_Weapon
@onready var slot_armor: BaseButton  = %Slot_Armor

# Paso 2 — referencias a listas
@onready var _inv_list  = get_node("SheetPanel/SheetVBox/RootSplit/LeftSide/BottomSplit/InvPanel/MarginContainer/InvVBox/InvList")
@onready var _stash_list = get_node("SheetPanel/SheetVBox/RootSplit/BaulPanel/MarginContainer/BaulVBox/BaulList")
@onready var _slot_weapon = get_node("SheetPanel/SheetVBox/RootSplit/LeftSide/BottomSplit/EquipPanel/MarginContainer/EquipGrid/Slot_Weapon")
@onready var _slot_armor  = get_node("SheetPanel/SheetVBox/RootSplit/LeftSide/BottomSplit/EquipPanel/MarginContainer/EquipGrid/Slot_Armor")

@onready var return_arrow: Sprite2D = $ReturnArrow
@onready var glow_arrow: Sprite2D = $GlowArrow
@onready var arrow_button: BaseButton = $ArrowButton

@onready var popup_cantidad: AcceptDialog = $PopupCantidad
@onready var spin_cantidad: SpinBox = $PopupCantidad/SpinCantidad
@onready var label_cantidad: Label = $PopupCantidad/LabelCantidad

@onready var tavern_shop_list: ItemList = $"ShopContainer/ShopVBox/ShopHBox/TavernShopPanel/TavernShopVBox/TavernShopList"
@onready var tavern_inv_list: ItemList = $"ShopContainer/ShopVBox/ShopHBox/TavernInvPanel/TavernInvVBox/TavernInvList"

@onready var GlowLady: Node = $"GlowLady"
@onready var LadyButton: BaseButton = $"LadyButton"
@onready var tavern_shop_panel: Control = $"ShopContainer/ShopVBox/ShopHBox/TavernShopPanel"
@onready var tavern_inv_panel: Control = $"ShopContainer/ShopVBox/ShopHBox/TavernInvPanel"
@onready var ShopContainer: Control = $"ShopContainer"

@onready var GoldLabel: Label = $"ShopContainer/ShopVBox/TopBar/GoldLabel"
@onready var BtnCerrar: BaseButton = $"ShopContainer/ShopVBox/TopBar/BtnCerrar"
@onready var Bg_Parchment: Sprite2D = $"BgParchment"

@onready var lbl_atk: Label = $"SheetPanel/SheetVBox/RootSplit/LeftSide/InfoPanel/MarginContainer/StatsVBoxContainer2/LabelAttack"
@onready var lbl_def: Label = $"SheetPanel/SheetVBox/RootSplit/LeftSide/InfoPanel/MarginContainer/StatsVBoxContainer2/LabelDefense"

const LOG_INN := false

var _stack_pending := {
	"id": "",
	"from": "",
	"to": "",
	"max": 1,
	"removed_one": false	# true si ya habíamos “tomado 1” al agarrar
}

var _qty_ctx := {   # contexto solo para compras/ventas en shop
	"mode": "",     # "buy" | "sell"
	"shop": "tavern",
	"id": "",
	"max": 1
}

func _ready() -> void:
	
		# Chest glow: estado inicial + conexiones
	glow_chest.visible = false

	if not btn_chest.is_connected("mouse_entered", Callable(self, "_on_chest_mouse_entered")):
		btn_chest.connect("mouse_entered", Callable(self, "_on_chest_mouse_entered"))
	if not btn_chest.is_connected("mouse_exited", Callable(self, "_on_chest_mouse_exited")):
		btn_chest.connect("mouse_exited", Callable(self, "_on_chest_mouse_exited"))
	
		# Conectar ok/cancel popup cantidad
	if not popup_cantidad.is_connected("confirmed", Callable(self, "_on_popup_cantidad_confirmed")):
		popup_cantidad.connect("confirmed", Callable(self, "_on_popup_cantidad_confirmed"))
	if not popup_cantidad.is_connected("canceled", Callable(self, "_on_popup_cantidad_canceled")):
		popup_cantidad.connect("canceled", Callable(self, "_on_popup_cantidad_canceled"))
	
		# Paso 2 — conectar señales de listas (solo logs; los handlers ya existen del Paso 1)
	if _inv_list and _inv_list.has_signal("grabbed"):
		_inv_list.connect("grabbed", Callable(self, "on_grabbed"))
	if _inv_list and _inv_list.has_signal("drop_on_inventory"):
		_inv_list.connect("drop_on_inventory", Callable(self, "on_drop_inventory"))

	if _stash_list and _stash_list.has_signal("grabbed"):
		_stash_list.connect("grabbed", Callable(self, "on_grabbed"))
	if _stash_list and _stash_list.has_signal("drop_on_stash"):
		_stash_list.connect("drop_on_stash", Callable(self, "on_drop_stash"))
	
	if _slot_weapon and _slot_weapon.has_signal("grabbed"):
		_slot_weapon.connect("grabbed", Callable(self, "on_grabbed"))
	if _slot_weapon and _slot_weapon.has_signal("drop_on_slot_weapon"):
		_slot_weapon.connect("drop_on_slot_weapon", Callable(self, "on_drop_slot_weapon"))

	if _slot_armor and _slot_armor.has_signal("grabbed"):
		_slot_armor.connect("grabbed", Callable(self, "on_grabbed"))
	if _slot_armor and _slot_armor.has_signal("drop_on_slot_armor"):
		_slot_armor.connect("drop_on_slot_armor", Callable(self, "on_drop_slot_armor"))
	
	add_to_group("inn")

	if LOG_INN: print("[Inn] Autoload GameData? ", Engine.has_singleton("GameData"))
	if LOG_INN: print("[Inn] weapons:", GameData.weapons.size(), " armors:", GameData.armors.size())
	if LOG_INN: print("[Inn] avatar keys:", GameData.avatar.keys())
	if LOG_INN: print("[Inn] avatar raw:", GameData.avatar)

	# Flecha volver al pueblo
	glow_arrow.visible = false
	arrow_button.flat = true
	arrow_button.text = ""
	arrow_button.focus_mode = Control.FOCUS_NONE
	arrow_button.mouse_filter = Control.MOUSE_FILTER_STOP

	if not arrow_button.is_connected("mouse_entered", Callable(self, "_on_arrow_mouse_entered")):
		arrow_button.connect("mouse_entered", Callable(self, "_on_arrow_mouse_entered"))
	if not arrow_button.is_connected("mouse_exited", Callable(self, "_on_arrow_mouse_exited")):
		arrow_button.connect("mouse_exited", Callable(self, "_on_arrow_mouse_exited"))
	if not arrow_button.is_connected("pressed", Callable(self, "_on_arrow_pressed")):
		arrow_button.connect("pressed", Callable(self, "_on_arrow_pressed"))

	# panel oculto al iniciar
	sheet.visible = false
	Bg_Parchment.visible = false

	inv_list.item_selected.connect(_on_inv_selected)
	baul_list.item_selected.connect(_on_baul_selected)

	btn_equipar.pressed.connect(_on_equipar_pressed)
	btn_enviar_baul.pressed.connect(_on_enviar_baul_pressed)
	btn_retirar.pressed.connect(_on_retirar_pressed)

	# conectar botones
	btn_chest.pressed.connect(_on_chest_pressed)
	btn_close.pressed.connect(_on_close_pressed)
	
	_refresh_tavern_shop_list()
	_refresh_tavern_inventory_list()
	_update_atk_def()

	# (opcional) precargar UI si querés ver algo al entrar
	_update_info()
	inv_list.add_item("DEBUG: inventario vivo")
	baul_list.add_item("DEBUG: baúl vivo")
	_update_lists()
	_update_equipment_slots()
	
	# Tabernera: estado inicial
	if GlowLady:
		GlowLady.visible = false

	# Si querés que la tienda esté oculta hasta hacer click, dejá visible=false
	if ShopContainer:
		ShopContainer.visible = false
	# Top bar de shop
	_refresh_gold_label()
	if BtnCerrar and not BtnCerrar.is_connected("pressed", Callable(self, "_on_shop_close_pressed")):
		BtnCerrar.connect("pressed", Callable(self, "_on_shop_close_pressed"))

	# Conexiones (idempotentes)
	if LadyButton and not LadyButton.is_connected("mouse_entered", Callable(self, "_on_lady_mouse_entered")):
		LadyButton.connect("mouse_entered", Callable(self, "_on_lady_mouse_entered"))
	if LadyButton and not LadyButton.is_connected("mouse_exited", Callable(self, "_on_lady_mouse_exited")):
		LadyButton.connect("mouse_exited", Callable(self, "_on_lady_mouse_exited"))
	if LadyButton and not LadyButton.is_connected("pressed", Callable(self, "_on_lady_pressed")):
		LadyButton.connect("pressed", Callable(self, "_on_lady_pressed"))

func _on_chest_pressed() -> void:
	sheet.visible = true
	Bg_Parchment.visible = true
	ShopContainer.visible = false
	_update_info()
	_update_lists()
	_update_equipment_slots()

func _on_inv_selected(index: int) -> void:
	# Al seleccionar en inventario, habilitar solo sus acciones
	btn_equipar.disabled = false
	btn_enviar_baul.disabled = false
	# Deshabilitar botón de baúl y deseleccionar el otro lado
	btn_retirar.disabled = true
	baul_list.deselect_all()

func _refresh_gold_label() -> void:
	if GoldLabel:
		GoldLabel.text = "Oro: %d" % int(GameData.avatar.get("gold", 0))

func _on_baul_selected(index: int) -> void:
	btn_retirar.disabled = false
	# Deshabilitar acciones de inventario y deseleccionar el otro lado
	btn_equipar.disabled = true
	btn_enviar_baul.disabled = true
	inv_list.deselect_all()

func _on_equipar_pressed() -> void:
	var selected := inv_list.get_selected_items()
	if selected.is_empty():
		return
	var idx: int = selected[0]
	var raw_id := str(inv_list.get_item_metadata(idx))
	var item_id: String = _norm_id(raw_id)

	var av: Dictionary = GameData.avatar

	# DEBUG corto para ver qué está pasando (podés borrarlo luego)
	if LOG_INN: print("[Equipar] id=", item_id, "  in weapons=", GameData.weapons.has(item_id), "  in armors=", GameData.armors.has(item_id))

	if GameData.weapons.has(item_id):
		var old: String = str(av.get("weapon_id", ""))
		av["weapon_id"] = item_id
		var inv: Array = av.get("inventory", [])
		inv.erase(item_id)
		av["inventory"] = inv
		if old != "":
			av["inventory"].append(old)

	elif GameData.armors.has(item_id):
		var old: String = str(av.get("armor_id", ""))
		av["armor_id"] = item_id
		var inv2: Array = av.get("inventory", [])
		inv2.erase(item_id)
		av["inventory"] = inv2
		if old != "":
			av["inventory"].append(old)

	# refrescar UI
	_update_lists()
	_update_equipment_slots()

	# reset selección y botones
	inv_list.deselect_all()
	btn_equipar.disabled = true
	btn_enviar_baul.disabled = true

	# DEBUG: verificar que quedó seteado
	if LOG_INN: print("[Equipar] weapon_id=", av.get("weapon_id", ""), " armor_id=", av.get("armor_id", ""))

func _on_enviar_baul_pressed() -> void:
	var selected := inv_list.get_selected_items()
	if selected.is_empty():
		return
	var idx: int = selected[0]
	var item_id: String = str(inv_list.get_item_metadata(idx))

	var av: Dictionary = GameData.avatar
	av["inventory"].erase(item_id)
	av["stash"].append(item_id)

	_update_lists()

	inv_list.deselect_all()
	btn_equipar.disabled = true
	btn_enviar_baul.disabled = true

func _on_retirar_pressed() -> void:
	var selected := baul_list.get_selected_items()
	if selected.is_empty():
		return
	var idx: int = selected[0]
	var item_id: String = str(baul_list.get_item_metadata(idx))

	var av: Dictionary = GameData.avatar
	av["stash"].erase(item_id)
	av["inventory"].append(item_id)

	_update_lists()

	baul_list.deselect_all()
	btn_retirar.disabled = true

func _on_close_pressed() -> void:
	sheet.visible = false
	Bg_Parchment.visible = false
	
func _update_info() -> void:
	var av: Dictionary = GameData.avatar

	var name: String = str(av.get("name", "Avatar"))
	var lvl: int = int(av.get("level", 1))
	var xp: int = int(av.get("xp", 0))
	var xp2n: int = int(av.get("xp_to_next", 12))
	var hp: int = int(av.get("hp", 10))
	var mhp: int = int(av.get("max_hp", 10))
	var gold: int = int(av.get("gold", 0))

	var stats: Dictionary = av.get("stats", {})
	var s: int = int(av.get("str", 0))
	var d: int = int(av.get("dex", 0))
	var intel: int = int(av.get("int", 0))   # por si más adelante agregás INT
	var ini: int = int(av.get("init", 0))

	lbl_stats.text = "Stats: FUE %d   DES %d   INT %d   (INI %d)" % [s, d, intel, ini]
	lbl_name.text  = "Nombre: %s" % name
	lbl_level.text = "Nivel: %d — XP %d/%d" % [lvl, xp, xp2n]
	lbl_hp.text    = "HP: %d/%d" % [hp, mhp]
	lbl_gold.text  = "Oro: %d" % gold

func _update_lists() -> void:
	inv_list.clear()
	baul_list.clear()

	var av: Dictionary = GameData.avatar
	var inv: Array = av.get("inventory", [])
	var stash: Array = av.get("stash", [])

	_populate_grouped_list(_inv_list, "inventory")
	_populate_grouped_list(_stash_list, "stash")

	if _inv_list:
		_apply_tooltips_to_list(_inv_list)
	if _stash_list:
		_apply_tooltips_to_list(_stash_list)
	# Reset de selección y botones
	inv_list.deselect_all()
	baul_list.deselect_all()
	btn_equipar.disabled = true
	btn_enviar_baul.disabled = true
	btn_retirar.disabled = true
	
func _refresh_tavern_shop_list() -> void:
	if tavern_shop_list == null:
		return
	tavern_shop_list.clear()

	var ids: Array = GameData.get_shop_items("tavern")
	for id_val in ids:
		var id: String = String(id_val)
		var name: String = GameData.get_item_display_name(id)
		var price: int = GameData.get_shop_price("tavern", id)
		var label: String = "%s  ( %d oro )" % [name, price]
		var idx: int = tavern_shop_list.add_item(label)
		tavern_shop_list.set_item_metadata(idx, id)
		var tip: String = GameData.get_item_tooltip(id)
		if tip != "":
			tavern_shop_list.set_item_tooltip(idx, tip)

func _refresh_tavern_inventory_list() -> void:
	if tavern_inv_list == null:
		return
	tavern_inv_list.clear()

	# Contar stacks por id (solo vendibles)
	var counts: Dictionary = {}
	var inv: Array = GameData.avatar.get("inventory", [])
	for v in inv:
		var id: String = String(v)
		var kind: String = GameData.get_item_kind(id)
		if kind != "item":
			continue
		# excluir pociones (heal)
		var subkind: String = ""
		if GameData.items.has(id):
			subkind = String((GameData.items[id] as Dictionary).get("subkind", ""))
		if subkind == "heal":
			continue

		if not counts.has(id):
			counts[id] = 1
		else:
			counts[id] = int(counts[id]) + 1

	# Poblar la lista (con (xN) si corresponde)
	for id_key in counts.keys():
		var id: String = String(id_key)
		var n: int = int(counts[id])
		var name: String = GameData.get_item_display_name(id)
		var label: String = name
		if n > 1:
			label = "%s (x%d)" % [name, n]
		var idx: int = tavern_inv_list.add_item(label)
		tavern_inv_list.set_item_metadata(idx, id)
		var tip: String = GameData.get_item_tooltip(id)
		if tip != "":
			tavern_inv_list.set_item_tooltip(idx, tip)

func _update_equipment_slots() -> void:
	var av: Dictionary = GameData.avatar

	var wid: String = str(av.get("weapon_id", ""))
	var aid: String = GameData.get_equipped_id("armor")

	if LOG_INN: print("[UI] _update_equipment_slots() wid=", wid, "  aid=", aid, "  avatar=", GameData.avatar)
	if LOG_INN: print("[UI] slot_armor ref => ", slot_armor, " class=", (slot_armor if slot_armor == null else slot_armor.get_class()))
	if slot_armor:
		slot_armor.text = "[FORZADO]"  # <- TEMP: debería verse al instante en el botón

	# Texto del botón (nombre o vacío)
	slot_weapon.text = _display_name(wid) if wid != "" else "(sin arma)"
	slot_armor.text  = _display_name(aid) if aid != "" else "(sin armadura)"

	# Tooltip arma (fuente única)
	if wid != "":
		slot_weapon.tooltip_text = GameData.get_item_tooltip(wid)
	else:
		slot_weapon.tooltip_text = "Mano principal vacía"

	# Tooltip armadura
	# Tooltip armadura (fuente única)
	if aid != "":
		slot_armor.tooltip_text = GameData.get_item_tooltip(aid)
	else:
		slot_armor.tooltip_text = "Sin armadura"

func _update_atk_def() -> void:
	var av: Dictionary = GameData.avatar

	# Stats base del avatar (STR/DEX/INT) para elegir P y S (MELEE por ahora)
	var stats := {
		"STR": int(av.get("str", 0)),
		"DEX": int(av.get("dex", 0)),
		"INT": int(av.get("int", 0)),
	}
	var pm: Dictionary = GameData.get_primary_secondary_for_action("MELEE", stats)
	var P: float = float(pm.get("P", 0.0))
	var S: float = float(pm.get("S", 0.0))

	# Construir totales usando los helpers de GameData
	var atk_total: float = GameData.build_offense(av, P, S)
	var def_total: float = GameData.build_defense(av)

	# Pintar (redondeo a entero para UI)
	if lbl_atk:
		lbl_atk.text = "Ataque: %d" % int(round(atk_total))
	if lbl_def:
		lbl_def.text = "Defensa: %d" % int(round(def_total))

func _display_name(id: String) -> String:
	if GameData.weapons.has(id):
		return str(GameData.weapons[id].get("name", id))
	if GameData.armors.has(id):
		return str(GameData.armors[id].get("name", id))
	return id

func _norm_id(x: String) -> String:
	return x.strip_edges()

# ─────────────────────────────────────────────────────────────────────
# Señales/handlers centrales (solo logs en Paso 1)

func on_grabbed(id: String, from: String, kind: String, origin_ref) -> void:
	if LOG_INN: print("[DROP] grabbed id=%s from=%s kind=%s" % [id, from, kind])
	current_drag.id = id
	current_drag.from = from
	current_drag.kind = kind
	current_drag.origin_ref = origin_ref
	current_drag.removed_from_origin = false

	if _controller_enabled:
		# NO retiramos nada en el grab: solo recordamos el id/origen
		current_drag.removed_from_origin = false
		_drag_committed = false
		if LOG_INN: print("[DROP] grab (no-take) from=%s id=%s" % [from, id])
	after_change()

func on_drop_inventory() -> void:
	if LOG_INN: print("[DROP] drop target=inventory")
	if not _controller_enabled:
		if LOG_INN: print("[DROP] controller disabled — ignoring commit (4.1)")
		after_change()
		return

	_handling_drop = true
	_drag_committed = true

	if current_drag.id == "":
		if LOG_INN: print("[DROP] no current_drag — nada que hacer")
		_handling_drop = false
		after_change()
		return

	var id: String = String(current_drag.id)
	var from: String = String(current_drag.from)
	var to: String = "inventory"

	# Evitar mover dentro del mismo contenedor (inv→inv)
	if from == to:
		reset_current_drag()
		_handling_drop = false
		after_change()
		return

	var stackable: bool = _is_stackable(id)
	var available_origin: int = _count_in_container(from, id)
	
	if LOG_INN: print("[STACK] about to open popup — from=%s, id=%s, raw=%s" % [from, id, GameData.avatar.get(from, [])])

	# Si stackea y hay más de 1 → abrir popup (NO movemos aún)
	if stackable and available_origin > 1:
		_open_stack_popup(id, from, to, available_origin, false)
		_drag_committed = false
		_handling_drop = false
		return

	# Caso normal: mover exactamente 1 (take→give)
	var ok_take: bool = GameData.take_item(from, id, 1)
	var ok_give: bool = ok_take and GameData.give_item(to, id, 1)
	if LOG_INN: print("[DROP] move 1 %s -> %s take=%s give=%s" % [from, to, ok_take, ok_give])

	reset_current_drag()
	_handling_drop = false
	after_change()

func on_drop_stash() -> void:
	if LOG_INN: print("[DROP] drop target=stash")
	if not _controller_enabled:
		if LOG_INN: print("[DROP] controller disabled — ignoring commit (4.1)")
		after_change()
		return

	_handling_drop = true
	_drag_committed = true

	if current_drag.id == "":
		if LOG_INN: print("[DROP] no current_drag — nada que hacer")
		_handling_drop = false
		after_change()
		return

	var id: String = String(current_drag.id)
	var from: String = String(current_drag.from)
	var to: String = "stash"

	# Evitar mover dentro del mismo contenedor (stash→stash)
	if from == to:
		reset_current_drag()
		_handling_drop = false
		after_change()
		return

	var stackable: bool = _is_stackable(id)
	var available_origin: int = _count_in_container(from, id)

	if LOG_INN: print("[STACK] about to open popup — from=%s, id=%s, raw=%s" % [from, id, GameData.avatar.get(from, [])])

	# Si stackea y hay más de 1 → abrir popup (NO movemos aún)
	if stackable and available_origin > 1:
		_open_stack_popup(id, from, to, available_origin, false)
		_drag_committed = false
		_handling_drop = false
		return

	# Caso normal: mover exactamente 1 (take→give)
	var ok_take: bool = GameData.take_item(from, id, 1)
	var ok_give: bool = ok_take and GameData.give_item(to, id, 1)
	if LOG_INN: print("[DROP] move 1 %s -> %s take=%s give=%s" % [from, to, ok_take, ok_give])

	reset_current_drag()
	_handling_drop = false
	after_change()

func on_drop_slot_weapon() -> void:
	_handling_drop = true
	_drag_committed = true
	print("[DROP] drop target=slot_weapon")

	if not _controller_enabled or current_drag.id == "":
		_handling_drop = false
		after_change()
		return

	if current_drag.kind != "weapon":
		print("[DROP] incompatible kind for weapon slot:", current_drag.kind)
		reset_current_drag()
		_handling_drop = false
		after_change()
		return

	var id: String = String(current_drag.id)
	var from: String = String(current_drag.from)

	# 1) tomar 1 del origen
	var ok_take: bool = GameData.take_item(from, id, 1)
	if not ok_take:
		print("[WEAPON] take failed from=%s id=%s" % [from, id])
		reset_current_drag()
		_handling_drop = false
		after_change()
		return

	# 2) equipar (si falla, devolver al origen)
	var ok_swap: bool = GameData.swap_equip("weapon", id)
	print("[WEAPON] swap equip =", ok_swap)
	if not ok_swap:
		var back_ok: bool = GameData.give_item(from, id, 1)
		print("[WEAPON] revert give back ->", back_ok)

	reset_current_drag()
	_handling_drop = false
	after_change()

func on_drop_slot_armor() -> void:
	_handling_drop = true
	_drag_committed = true
	print("[DROP] drop target=slot_armor")

	if not _controller_enabled or current_drag.id == "":
		_handling_drop = false
		after_change()
		return

	if current_drag.kind != "armor":
		print("[DROP] incompatible kind for armor slot:", current_drag.kind)
		reset_current_drag()
		_handling_drop = false
		after_change()
		return

	var id: String = String(current_drag.id)
	var from: String = String(current_drag.from)

	# 1) tomar 1 del origen
	var ok_take: bool = GameData.take_item(from, id, 1)
	if not ok_take:
		print("[ARMOR] take failed from=%s id=%s" % [from, id])
		reset_current_drag()
		_handling_drop = false
		after_change()
		return

	# 2) equipar (si falla, devolver al origen)
	var ok_swap: bool = GameData.swap_equip("armor", id)
	print("[ARMOR] swap equip =", ok_swap)
	if not ok_swap:
		var back_ok: bool = GameData.give_item(from, id, 1)
		print("[ARMOR] revert give back ->", back_ok)

	reset_current_drag()
	_handling_drop = false
	after_change()

func on_drop_outside() -> void:
	if LOG_INN: print("[DROP] drop target=outside")
	if _controller_enabled and current_drag.removed_from_origin:
		var back = GameData.give_item(current_drag.from, current_drag.id, 1)
		if LOG_INN: print("[DATA] revert give_item to=%s id=%s -> %s" % [current_drag.from, current_drag.id, back])
	reset_current_drag()
	after_change()

func reset_current_drag() -> void:
	current_drag = {
		"id": "",
		"kind": "",
		"from": "",
		"origin_ref": null,
		"removed_from_origin": false
	}
	if LOG_INN: print("[DROP] reset_current_drag()")

func after_change() -> void:
	# Refresco determinista tras cada commit/revert
	if has_method("_update_lists"):
		_update_lists()
	if has_method("_update_equipment_slots"):
		_update_equipment_slots()
	if LOG_INN: print("[UI] after_change() — listas y slots refrescados")
	_refresh_tavern_shop_list()
	_refresh_tavern_inventory_list()
	_refresh_gold_label()
	if has_method("_update_atk_def"):
		_update_atk_def()

# ─────────────────────────────────────────────────────────────────────
func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		# Si terminó el drag y no hubo commit ni estamos en un drop handler
		if current_drag.id != "" and not _drag_committed and not _handling_drop:
			# Solo revertir si de verdad habíamos quitado 1 del origen
			if bool(current_drag.removed_from_origin):
				var back_ok: bool = GameData.give_item(current_drag.from, current_drag.id, 1)
				if LOG_INN: print("[DATA] auto-revert END-DRAG to=%s id=%s -> %s" % [current_drag.from, current_drag.id, back_ok])
			else:
				if LOG_INN: print("[DATA] auto-revert SKIP (no-removed) from=%s id=%s" % [current_drag.from, current_drag.id])
			reset_current_drag()
			after_change()

func _on_chest_mouse_entered() -> void:
	glow_chest.visible = true

func _on_chest_mouse_exited() -> void:
	glow_chest.visible = false

func _on_arrow_mouse_entered() -> void:
	glow_arrow.visible = true

func _on_arrow_mouse_exited() -> void:
	glow_arrow.visible = false

func _on_arrow_pressed() -> void:
	get_tree().change_scene_to_file("res://Town.tscn")

func _apply_tooltips_to_list(list: ItemList) -> void:
	# Recorre todos los ítems de la lista y setea el tooltip según el id guardado en metadata
	if list == null:
		return
	for i in range(list.item_count):
		var id := String(list.get_item_metadata(i))
		list.set_item_tooltip(i, GameData.get_item_tooltip(id))

func _is_stackable(id: String) -> bool:
	var items_dict = GameData.get("items")
	if typeof(items_dict) != TYPE_DICTIONARY:
		return false
	var row = items_dict.get(id, {})
	if typeof(row) != TYPE_DICTIONARY:
		return false
	return bool(row.get("stackable", false))

func _count_in_container(container: String, id: String) -> int:
	var arr: Array = []
	if container == "inventory":
		arr = GameData.avatar.get("inventory", [])
	elif container == "stash":
		arr = GameData.avatar.get("stash", [])
	elif container.begins_with("equipped"):
		var cur := String(GameData._get_container_ref(container))
		return 1 if cur == id else 0
	else:
		var any = GameData._get_container_ref(container)
		if typeof(any) == TYPE_ARRAY:
			arr = any

	var c: int = 0
	for x in arr:
		if String(x) == id:
			c += 1
	return c

func _open_stack_popup(id: String, from: String, to: String, available_total: int, removed_one: bool) -> void:
	_stack_pending.id = id
	_stack_pending.from = from
	_stack_pending.to = to
	_stack_pending.max = max(1, available_total)
	_stack_pending.removed_one = removed_one

	spin_cantidad.min_value = 1
	spin_cantidad.max_value = _stack_pending.max
	spin_cantidad.value = _stack_pending.max

	var nice := GameData.get_item_display_name(id)
	label_cantidad.visible = false
	popup_cantidad.popup_centered()

func _open_qty_popup_shop(mode: String, id: String, max_units: int) -> void:
	_qty_ctx.mode = mode
	_qty_ctx.shop = "tavern"
	_qty_ctx.id = id
	_qty_ctx.max = max(1, max_units)

	# Reutilizamos el mismo popup/label/spin
	label_cantidad.visible = false
	spin_cantidad.min_value = 1
	spin_cantidad.max_value = _qty_ctx.max
	spin_cantidad.step = 1
	spin_cantidad.value = _qty_ctx.max
	popup_cantidad.popup_centered()

func _on_popup_cantidad_confirmed() -> void:
	# --- Prioridad: contexto de SHOP (buy/sell) ---
	if String(_qty_ctx.mode) != "":
		var amount: int = int(spin_cantidad.value)
		amount = max(1, min(amount, int(_qty_ctx.max)))
		var ok: bool = false
		if _qty_ctx.mode == "buy":
			ok = GameData.shop_buy(_qty_ctx.shop, _qty_ctx.id, amount)
			if LOG_INN: print("[SHOP] buy id=%s x%d -> %s" % [_qty_ctx.id, amount, ok])
		elif _qty_ctx.mode == "sell":
			ok = GameData.shop_sell(_qty_ctx.shop, _qty_ctx.id, amount)
			if LOG_INN: print("[SHOP] sell id=%s x%d -> %s" % [_qty_ctx.id, amount, ok])

		# limpiar contexto shop y refrescar
		_qty_ctx.mode = ""
		_qty_ctx.id = ""
		_qty_ctx.max = 1
		after_change()
		return

	# --- Si no es SHOP, es el flujo de stacks INV↔STASH (tu lógica existente) ---
	var id: String = String(_stack_pending.id)
	var from: String = String(_stack_pending.from)
	var to: String = String(_stack_pending.to)
	var want: int = int(spin_cantidad.value)

	# Estado real antes de mover
	var total_before: int = _count_in_container(from, id)
	if LOG_INN: print("[STACK] debug before list=", from, " -> ", GameData.avatar.get(from, []))
	want = clamp(want, 1, max(1, total_before))

	# Mover EXACTAMENTE 'want' unidades (take→give)
	var moved: int = 0
	while moved < want:
		var ok_take: bool = GameData.take_item(from, id, 1)
		if not ok_take:
			if LOG_INN: print("[STACK] WARN: take falló en moved=%d (from=%s id=%s)" % [moved, from, id])
			break
		var ok_give: bool = GameData.give_item(to, id, 1)
		if not ok_give:
			GameData.give_item(from, id, 1)  # rollback si falla el give
			if LOG_INN: print("[STACK] ERROR: give falló; rollback 1 (from=%s id=%s)" % [from, id])
			break
		moved += 1

	var left_after: int = _count_in_container(from, id)
	if LOG_INN: print("[STACK] confirm want=%d, moved=%d, before=%d, left_after=%d  (%s → %s id=%s)" % [
		want, moved, total_before, left_after, from, to, id
	])

	_stack_pending.id = ""
	reset_current_drag()
	_update_lists()
	_update_equipment_slots()

func _on_popup_cantidad_canceled() -> void:
	_stack_pending.id = ""
	reset_current_drag()
	_update_lists()
	_update_equipment_slots()

func _populate_grouped_list(list: ItemList, container: String) -> void:
	if list == null:
		return
	list.clear()

	# 1) contar por id
	var counts := {}
	var arr = GameData._get_container_ref(container)
	if typeof(arr) == TYPE_ARRAY:
		for x in arr:
			var iid: String = String(x)
			counts[iid] = int(counts.get(iid, 0)) + 1

	# 2) poblar: solo stackeables muestran (xN); los no-stackeables salen en filas separadas
	for iid in counts.keys():
		var n: int = int(counts[iid])
		var is_stackable: bool = _is_stackable(iid)

		if is_stackable and n > 1:
			# una fila agregada
			var label_agg: String = GameData.get_item_display_name(iid)
			label_agg = "%s (x%d)" % [label_agg, n]
			var idx_agg: int = list.add_item(label_agg)
			list.set_item_metadata(idx_agg, iid)
			list.set_item_tooltip(idx_agg, GameData.get_item_tooltip(iid))
		else:
			# n filas individuales
			for i in range(n):
				var label_one: String = GameData.get_item_display_name(iid)
				var idx_one: int = list.add_item(label_one)
				list.set_item_metadata(idx_one, iid)
				list.set_item_tooltip(idx_one, GameData.get_item_tooltip(iid))

func on_drop_inventory_from_tavern(id: String) -> void:
	var price: int = GameData.get_shop_price("tavern", id)
	var gold: int = int(GameData.avatar.get("gold", 0))
	var stock: int = GameData.get_shop_stock("tavern", id)  # -1 = infinito
	var stackable: bool = GameData.is_stackable(id)

	var max_by_gold: int = (gold / price) if price > 0 else 9999
	var max_by_stock: int = (stock if stock >= 0 else 9999)
	var max_possible: int = min(max_by_gold, max_by_stock)

	if max_possible < 1:
		if LOG_INN: print("[SHOP] buy rejected: sin oro o sin stock (id=%s)" % id)
		return

	if stackable and max_possible > 1:
		_open_qty_popup_shop("buy", id, max_possible)
	else:
		var ok: bool = GameData.shop_buy("tavern", id, 1)
		if LOG_INN: print("[SHOP] buy id=%s x1 -> %s" % [id, ok])
		after_change()

func on_drop_tavern_from_inventory(id: String) -> void:
	var stackable: bool = GameData.is_stackable(id)
	var have: int = _count_in_container("inventory", id)

	if have < 1:
		if LOG_INN: print("[SHOP] sell rejected: no hay '%s' en inventario" % id)
		return

	if stackable and have > 1:
		_open_qty_popup_shop("sell", id, have)
	else:
		var ok: bool = GameData.shop_sell("tavern", id, 1)
		if LOG_INN: print("[SHOP] sell id=%s x1 -> %s" % [id, ok])
		after_change()

func _on_lady_mouse_entered() -> void:
	if GlowLady:
		GlowLady.visible = true

func _on_lady_mouse_exited() -> void:
	if GlowLady:
		GlowLady.visible = false

func _on_lady_pressed() -> void:
	# Mostrar paneles de tienda y refrescar listas
	ShopContainer.visible = true
	Bg_Parchment.visible = true
	sheet.visible = false
	_refresh_tavern_shop_list()
	_refresh_tavern_inventory_list()
	_refresh_gold_label()	# <- agregar esta línea

func _on_shop_close_pressed() -> void:
	if ShopContainer:
		ShopContainer.visible = false
		Bg_Parchment.visible = false
		
	# opcional: apagar el glow si quedó prendido
	if GlowLady:
		GlowLady.visible = false
