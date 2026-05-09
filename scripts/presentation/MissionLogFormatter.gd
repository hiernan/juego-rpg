extends RefCounted

class_name MissionLogFormatter


static func join_lines(lines: Array) -> String:
	var output := ""
	var first := true
	for line in lines:
		if first:
			output += String(line)
			first = false
		else:
			output += "\n" + String(line)
	return output


static func format_loot_log(game_data, rewards: Dictionary) -> String:
	var lines: Array = []
	lines.append("[b]Oro:[/b] %d" % int(rewards.get("gold", 0)))
	lines.append("[b]XP:[/b] %d" % int(rewards.get("xp", 0)))
	lines.append("[b]Bolsa:[/b]")

	var counts: Dictionary = {}
	for entry in game_data.loot_bag:
		var item_id: String = String(entry)
		counts[item_id] = int(counts.get(item_id, 0)) + 1

	for item_id in counts.keys():
		var name: String = game_data.get_item_display_name(String(item_id))
		var amount: int = int(counts[item_id])
		var label: String = name if amount <= 1 else "%s (x%d)" % [name, amount]
		lines.append(" • " + label)

	return join_lines(lines)


static func format_result_summary(game_data, rewards: Dictionary, result_bag: Array, lost: bool) -> String:
	var lines: Array = []
	if lost:
		lines.append("Perdiste todo el botín de esta misión.")
		return join_lines(lines)

	lines.append("Botín obtenido:")
	lines.append(" • Oro: %d" % int(rewards.get("gold", 0)))
	lines.append(" • XP: %d" % int(rewards.get("xp", 0)))

	var source_bag: Array = result_bag if not result_bag.is_empty() else Array(rewards.get("items", []))
	var counts: Dictionary = {}
	for entry in source_bag:
		var item_id: String = String(entry)
		counts[item_id] = int(counts.get(item_id, 0)) + 1

	if counts.is_empty():
		lines.append(" • Objetos: (ninguno)")
		return join_lines(lines)

	lines.append(" • Objetos:")
	for item_id in counts.keys():
		var name: String = game_data.get_item_display_name(String(item_id))
		var amount: int = int(counts[item_id])
		var line: String = "    - %s" % name if amount <= 1 else "    - %s (x%d)" % [name, amount]
		lines.append(line)

	return join_lines(lines)
