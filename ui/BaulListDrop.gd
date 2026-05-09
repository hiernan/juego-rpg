extends ItemList

# Paso 2 — señales hacia inn.gd
signal grabbed(id: String, from: String, kind: String, origin_ref: Node)
signal drop_on_stash()

@export var source_name: String = "stash"

func _ready() -> void:
	# Capturamos el mouse para recibir drop
	mouse_filter = Control.MOUSE_FILTER_STOP

func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	return true

func _drop_data(at_position: Vector2, data: Variant) -> void:
	# Paso 2 — avisar al controlador
	drop_on_stash.emit()
	return
	if typeof(data) != TYPE_DICTIONARY:
		return
	var d: Dictionary = data
	var id: String = str(d.get("id", ""))
	var from_src: String = str(d.get("from", ""))
	if id == "":
		return

	# Este ItemList es el baúl, así que el destino es "stash"
	var to_src: String = "stash"
	var ok: bool = GameData.move_item(from_src, to_src, id, 1)
	print("[DROP->BAUL] ", id, "  ", from_src, " -> ", to_src, "  ok=", ok)

	# Refrescar la UI (Inn) si está presente
	var root := get_tree().current_scene
	if root and root.has_method("_update_lists"):
		root._update_lists()

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
