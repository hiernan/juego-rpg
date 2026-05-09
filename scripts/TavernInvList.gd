extends ItemList

func _get_drag_data(at_position: Vector2):
	var sel: PackedInt32Array = get_selected_items()
	var idx: int = sel[0] if sel.size() > 0 else -1
	if idx < 0:
		return null
	var id: String = String(get_item_metadata(idx))
	var kind: String = GameData.get_item_kind(id)

	var preview := Label.new()
	preview.text = GameData.get_item_display_name(id)
	set_drag_preview(preview)

	return { "id": id, "from": "inventory", "kind": kind }

func _can_drop_data(at_position: Vector2, data) -> bool:
	if typeof(data) != TYPE_DICTIONARY:
		return false
	if not data.has("from") or not data.has("id"):
		return false
	var from: String = String(data["from"])
	var kind: String = String(data.get("kind", ""))
	# Acepta drops DESDE la tienda (comprar)
	return from == "shop_tavern" and kind == "item"

func _drop_data(at_position: Vector2, data) -> void:
	if not _can_drop_data(at_position, data):
		return
	var id: String = String(data["id"])
	var scene := get_tree().current_scene
	if scene and scene.has_method("on_drop_inventory_from_tavern"):
		scene.call("on_drop_inventory_from_tavern", id)
