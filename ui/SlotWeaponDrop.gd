extends Button

signal grabbed(id: String, from: String, kind: String, origin_ref: Node)
signal drop_on_slot_weapon()

func _ready() -> void:
	_refresh_text()

func _get_weapon_name(id: String) -> String:
	var name := id
	var w := GameData.get_weapon(id)
	if typeof(w) == TYPE_DICTIONARY and (w as Dictionary).has("name") and typeof((w as Dictionary)["name"]) == TYPE_STRING:
		name = String((w as Dictionary)["name"])
	return name

func _refresh_text() -> void:
	var eq_id: String = GameData.get_equipped_weapon_id()
	if eq_id == "":
		text = "(sin arma)"
	else:
		text = _get_weapon_name(eq_id)

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY:
		return false
	var d := data as Dictionary
	if not d.has("id") or not d.has("kind"):
		return false
	# solo aceptamos armas
	return String(d["kind"]) == "weapon"

func _drop_data(at_position: Vector2, data: Variant) -> void:
	drop_on_slot_weapon.emit()
	# Validación del payload
	#var is_dict: bool = typeof(data) == TYPE_DICTIONARY
	#var has_id: bool = is_dict and data.has("id")
	#if not has_id:
		#return
#
	#var id: String = String(data.id)
	#var from_src: String = ""
	#if data.has("from") and typeof(data.from) == TYPE_STRING:
		#from_src = String(data.from)
#
	## Acceso al avatar
	#var av: Dictionary = GameData.avatar
	#var inv: Array = av.get("inventory", []) as Array
	#var stash: Array = av.get("stash", []) as Array
#
	## 1) Borrar del origen (inventory o stash/baúl)
	#match from_src:
		#"inventory":
			#inv.erase(id)
		#"stash", "baul", "chest":
			#stash.erase(id)
		#_:
			## Por si el payload trae un alias raro: intentamos en ambos
			#inv.erase(id)
			#stash.erase(id)
#
	## 2) Hacer swap: arma previa -> inventario
	#var old_weapon: String = String(av.get("weapon_id", ""))
	#av["weapon_id"] = id
	#if old_weapon != "":
		#inv.append(old_weapon)
#
	## 3) Guardar listas actualizadas
	#av["inventory"] = inv
	#av["stash"] = stash
#
	## 4) Refrescar UI (usa los métodos del script de Inn)
	#var root := get_tree().current_scene
	#if root:
		#if root.has_method("_update_lists"):
			#root._update_lists()
		#if root.has_method("_update_equipment_slots"):
			#root._update_equipment_slots()

func _get_drag_data(at_position: Vector2) -> Variant:
	var wid: String = str(GameData.avatar.get("weapon_id", ""))
	if wid == "":
		return null
	# Paso 3 — avisar al controlador
	grabbed.emit(wid, "equipped_weapon", "weapon", self)
	var payload := {
		"id": wid,                 # el id del arma equipada
		"from": "equipped_weapon", # <- IMPORTANTE: este string exacto
		"kind": "weapon"
	}

	var lbl := Label.new()
	var nm: String = wid
	if GameData.weapons.has(wid):
		nm = String(GameData.weapons[wid].get("name", wid))
	lbl.text = nm

	set_drag_preview(lbl)

	print("[WEAPON SLOT] drag -> ", payload)
	return payload
