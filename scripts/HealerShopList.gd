extends ItemList
signal drop_on_shop(id: String)   # vender: inv → shop

func _get_drag_data(at_position: Vector2):
	var idx := get_selected_items()
	if idx.is_empty(): return null
	var id := String(get_item_metadata(idx[0]))
	if id == "": return null
	var preview := Label.new()
	preview.text = get_item_text(idx[0])
	set_drag_preview(preview)
	return {"id": id, "from": "healer_shop"}

func _can_drop_data(at_position: Vector2, data) -> bool:
	return typeof(data) == TYPE_DICTIONARY \
		and data.has("id") and data.has("from") \
		and String(data["from"]) == "healer_inv"

func _drop_data(at_position: Vector2, data) -> void:
	if not _can_drop_data(at_position, data): return
	emit_signal("drop_on_shop", String(data["id"]))  # vender 1
