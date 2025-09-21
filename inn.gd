extends Control

@onready var sheet: PanelContainer = %SheetPanel
@onready var btn_chest: BaseButton = %ChestButton
@onready var btn_close: Button = %BtnCerrar

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

func _ready() -> void:
	
	print("[Inn] Autoload GameData? ", Engine.has_singleton("GameData"))
	print("[Inn] weapons:", GameData.weapons.size(), " armors:", GameData.armors.size())
	print("[Inn] avatar keys:", GameData.avatar.keys())
	print("[Inn] avatar raw:", GameData.avatar)

	# panel oculto al iniciar
	sheet.visible = false

	inv_list.item_selected.connect(_on_inv_selected)
	baul_list.item_selected.connect(_on_baul_selected)

	btn_equipar.pressed.connect(_on_equipar_pressed)
	btn_enviar_baul.pressed.connect(_on_enviar_baul_pressed)
	btn_retirar.pressed.connect(_on_retirar_pressed)

	# conectar botones
	btn_chest.pressed.connect(_on_chest_pressed)
	btn_close.pressed.connect(_on_close_pressed)

	# (opcional) precargar UI si querés ver algo al entrar
	_update_info()
	inv_list.add_item("DEBUG: inventario vivo")
	baul_list.add_item("DEBUG: baúl vivo")
	_update_lists()
	_update_equipment_slots()

func _on_chest_pressed() -> void:
	sheet.visible = true
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
	print("[Equipar] id=", item_id, "  in weapons=", GameData.weapons.has(item_id), "  in armors=", GameData.armors.has(item_id))

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
	print("[Equipar] weapon_id=", av.get("weapon_id", ""), " armor_id=", av.get("armor_id", ""))

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

	# Inventario: agregar con metadata = item_id
	for id_val in inv:
		var id: String = _norm_id(str(id_val))
		var idx: int = inv_list.add_item(_display_name(id))
		inv_list.set_item_metadata(idx, id)

	# Baúl: idem
	for id_val in stash:
		var id: String = _norm_id(str(id_val))
		var idx: int = baul_list.add_item(_display_name(id))
		baul_list.set_item_metadata(idx, id)

	# Reset de selección y botones
	inv_list.deselect_all()
	baul_list.deselect_all()
	btn_equipar.disabled = true
	btn_enviar_baul.disabled = true
	btn_retirar.disabled = true

func _update_equipment_slots() -> void:
	var av: Dictionary = GameData.avatar

	var wid: String = str(av.get("weapon_id", ""))
	var aid: String = str(av.get("armor_id", ""))

	# Texto del botón = nombre del ítem, o (vacío)
	slot_weapon.text = _display_name(wid) if wid != "" else "(sin arma)"
	slot_armor.text  = _display_name(aid) if aid != "" else "(sin armadura)"

	# (Opcional) Tooltip con stats básicos
	if wid != "":
		var w: Dictionary = GameData.weapons.get(wid, {})
		if w.size() > 0:
			slot_weapon.tooltip_text = "%s\nDaño: %d–%d" % [
				str(w.get("name", wid)),
				int(w.get("dmg_min", 1)),
				int(w.get("dmg_max", 2))
			]
		else:
			slot_weapon.tooltip_text = "Mano principal vacía"
	else:
		slot_weapon.tooltip_text = "Mano principal vacía"

	if aid != "":
		var a: Dictionary = GameData.armors.get(aid, {})
		if a.size() > 0:
			var armor_val: int = int(a.get("armor", a.get("defense", 0)))
			slot_armor.tooltip_text = "%s\nArmadura: %d" % [
				str(a.get("name", aid)),
				armor_val
			]
		else:
			slot_armor.tooltip_text = "Sin armadura"
	else:
		slot_armor.tooltip_text = "Sin armadura"

func _display_name(id: String) -> String:
	if GameData.weapons.has(id):
		return str(GameData.weapons[id].get("name", id))
	if GameData.armors.has(id):
		return str(GameData.armors[id].get("name", id))
	return id

func _norm_id(x: String) -> String:
	return x.strip_edges()
