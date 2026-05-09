extends RefCounted

class_name MissionLogFormatter

static func join_lines(lines: Array) -> String:
	var out := ""
	var first := true
	for value in lines:
		if first:
			out += String(value)
			first = false
		else:
			out += "\n" + String(value)
	return out


static func format_loot_log(game_data, rewards: Dictionary) -> String:
	var lines: Array = []
	lines.append("[b]Oro:[/b] %d" % int(rewards.get("gold", 0)))
	lines.append("[b]XP:[/b] %d" % int(rewards.get("xp", 0)))
	lines.append("[b]Bolsa:[/b]")

	var counts: Dictionary = {}
	for item in game_data.loot_bag:
		var item_id := String(item)
		counts[item_id] = int(counts.get(item_id, 0)) + 1

	for item_id in counts.keys():
		var count: int = int(counts[item_id])
		var name: String = game_data.get_item_display_name(String(item_id))
		var label: String = name if count <= 1 else "%s (x%d)" % [name, count]
		lines.append(" • " + label)

	return join_lines(lines)


static func format_result_summary(game_data, rewards: Dictionary, result_bag: Array, lost: bool) -> String:
	var lines: Array = []
	if lost:
		lines.append("Perdiste todo el botin de esta mision.")
		return join_lines(lines)

	lines.append("Botin obtenido:")
	lines.append(" • Oro: %d" % int(rewards.get("gold", 0)))
	lines.append(" • XP: %d" % int(rewards.get("xp", 0)))

	var bag: Array = result_bag.duplicate()
	if bag.is_empty():
		bag = (rewards.get("items", []) as Array).duplicate()

	var counts: Dictionary = {}
	for item in bag:
		var item_id := String(item)
		counts[item_id] = int(counts.get(item_id, 0)) + 1

	if counts.size() == 0:
		lines.append(" • Objetos: (ninguno)")
		return join_lines(lines)

	lines.append(" • Objetos:")
	for item_id in counts.keys():
		var count: int = int(counts[item_id])
		var name: String = game_data.get_item_display_name(String(item_id))
		var line: String = "    - %s" % name if count <= 1 else "    - %s (x%d)" % [name, count]
		lines.append(line)

	return join_lines(lines)
