extends Button

signal grabbed(id: String, from: String, kind: String, origin_ref: Node)
signal drop_on_slot_armor()

func _can_drop_data(_pos: Vector2, data: Variant) -> bool:
	# Igual que en SlotWeaponDrop pero filtrando kind = "armor"
	if typeof(data) != TYPE_DICTIONARY:
		return false
	var d: Dictionary = data
	var kind: String = String(d.get("kind", ""))
	var can: bool = (kind == "armor")
	mouse_default_cursor_shape = Control.CURSOR_CAN_DROP if can else Control.CURSOR_FORBIDDEN
	return can


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	drop_on_slot_armor.emit()
	return
	## Validación mínima
	#if typeof(data) != TYPE_DICTIONARY:
		#return
	#var d: Dictionary = data as Dictionary
	#if not (d.has("id") and d.has("from")):
		#return
	#var id: String = String(d.id)
	#var from_src: String = String(d.from)
	#var kind: String = String(d.kind) if (d.has("kind") and typeof(d.kind) == TYPE_STRING) else ""
#
	## Aceptamos solo armaduras en este slot
	#if kind != "armor":
		#return
#
	## Usamos el pipeline unificado: de inventario/baúl -> equipado_armor (con swap interno)
	## Esto debe quitar del origen y, si había armadura equipada, mandarla al inventario.
	#if from_src == "inventory" or from_src == "stash":
		#var ok: bool = GameData.move_item_between_containers(from_src, "equipped_armor", id, 1)
		#print("[ARMOR] equip from %s -> %s (ok=%s)" % [from_src, "equipped_armor", str(ok)])
	#else:
		## Si viene de otra cosa (o del mismo slot), no hacemos nada aquí.
		#return
#
	## Refresco de UI (buscamos el nodo Inn por grupo)
	#var inn := get_tree().get_first_node_in_group("Inn")
	#if inn and inn.has_method("_update_lists"):
		#inn._update_lists()
	#if inn and inn.has_method("_update_equipment_slots"):
		#inn._update_equipment_slots()

# Arrastrar DESDE el slot (para desequipar por drag)
#func _get_drag_data(_at_position: Vector2) -> Variant:
	#var aid: String = GameData.get_equipped_armor_id()
	#if aid == "":
		#return null
	## Paso 3 — avisar al controlador
	#grabbed.emit(aid, "equipped_armor", "armor", self)
#
	#var payload := {
		#"id": aid,
		#"from": "equipped_armor",
		#"kind": "armor",
	#}
#
	#var lbl := Label.new()
	#lbl.text = GameData.get_item_display_name(aid)
	#set_drag_preview(lbl)
#
	#return payload

func _get_drag_data(at_position: Vector2):
	print("[DROP] armor slot _get_drag_data start")
	# si no hay armadura equipada, no empieza el drag
	var aid := GameData.get_equipped_id("armor")
	if aid == "":
		return null

	# cachear texto ANTES del emit (así no queda "sin armadura")
	var preview_text := self.text
	var lbl := Label.new()
	lbl.text = preview_text
	set_drag_preview(lbl)

	# avisar al controlador (Variante A: ya quitamos al agarrar)
	grabbed.emit(aid, "equipped_armor", "armor", self)

	# payload estándar
	var data := {
		"id": aid,
		"from": "equipped_armor",
		"kind": "armor"
	}
	return data
