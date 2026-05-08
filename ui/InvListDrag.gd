extends ItemList

# Paso 2 — señales hacia inn.gd
signal grabbed(id: String, from: String, kind: String, origin_ref: Node)
signal drop_on_inventory()

@export var source_name: String = "inventory"	# En BaulList poné "stash"

func _get_drag_data(at_position: Vector2) -> Variant:
	# resolver índice
	var idx := get_item_at_position(at_position, true)
	if idx == -1:
		var sel := get_selected_items()
		if sel.is_empty():
			return null
		idx = sel[0]
		
	# cachear texto/preview ANTES de emitir
	var preview_text := get_item_text(idx)
	var canonical_id := String(get_item_metadata(idx))
	var kind: String = GameData.get_item_kind(canonical_id)
	
	# emitir (inn.gd quitará del origen)
	grabbed.emit(canonical_id, source_name, kind, self)
	
	# usar el texto cacheado para el preview (sin tocar la lista)
	var lbl := Label.new()
	lbl.text = preview_text
	set_drag_preview(lbl)
	
		# drag data estándar
	var data := {
		"id": canonical_id,
		"from": source_name,
		"kind": kind
	}
	return data

func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY:
		return false
	var d: Dictionary = data
	return d.has("id") and d.has("from")

func _drop_data(at_position: Vector2, data: Variant) -> void:
	# Paso 2 — avisar al controlador
	drop_on_inventory.emit()
	return
	if typeof(data) != TYPE_DICTIONARY:
		return
	var d: Dictionary = data
	var id: String = str(d.get("id", ""))
	var from_src: String = str(d.get("from", ""))
	if id == "":
		return

	# Caso 1: viene desde el baúl → mover a inventario
	if from_src == "stash":
		var ok1: bool = GameData.move_item("stash", "inventory", id, 1)
		print("[DROP->INV] stash -> inventory  id=", id, " ok=", ok1)

	# Caso 2: viene desde arma equipada → desequipar y mandar al inventario
	elif from_src == "equipped_weapon":
		print("[DROP->INV] unequip weapon -> inventory  id=", id)
		GameData.set_equipped_weapon_id("")
		GameData.avatar["inventory"].append(id)

	# Caso 3: viene desde armadura equipada → desequipar y mandar al inventario
	elif from_src == "equipped_armor":
		GameData.set_equipped_armor_id("")
		GameData.avatar["inventory"].append(id)
		print("[DROP->INV] unequip armor -> inventory  id=", id)

	# Otros casos (ya cubrimos ‘inventory’→inventory y ‘weapon/armor’ list no aplican aquí)
	# Actualizar UI
	var root := get_tree().current_scene
	if root and root.has_method("_update_lists"):
		root._update_lists()
	if root and root.has_method("_update_equipment_slots"):
		root._update_equipment_slots()
