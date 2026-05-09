extends ItemList
signal drop_on_shop(id: String)

func _get_drag_data(at_position: Vector2) -> Variant:
	print("[BSM] get_drag_data on ", self.name)
	var idx: int = get_item_at_position(at_position, true)
	if idx < 0: return null
	var id := String(get_item_metadata(idx))
	if id == "": return null
	var label := Label.new()
	label.text = get_item_text(idx)  # o GameData.get_item_display_name(id)
	set_drag_preview(label)
	return { "id": id, "from": "shop_blacksmith" }

func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY: return false
	var id := String(data.get("id", ""))
	var from := String(data.get("from", ""))
	if id == "" or from != "inventory": return false
	var k := GameData.get_item_kind(id)
	return k == "weapon" or k == "armor"

func _drop_data(at_position: Vector2, data: Variant) -> void:
	var id := String(data.get("id", ""))
	if id == "": return
	emit_signal("drop_on_shop", id)
