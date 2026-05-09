extends RefCounted

class_name MissionRunnerService

const Combat = preload("res://scripts/Combat.gd")

static func resolve_search_room(game_data, event_data: Dictionary) -> Dictionary:
	var lines: Array[String] = []
	var rewards := {
		"gold": 0,
		"xp": 0,
		"items": [],
	}

	var loot_table_id: String = String(event_data.get("loot_table_id", ""))
	if loot_table_id != "" and game_data.has_loot_table(loot_table_id):
		var entries: Array = game_data.get_loot_table_entries(loot_table_id)
		var pick: Dictionary = game_data.pick_weighted(entries)
		var item_id: String = String(pick.get("item_id", ""))

		if item_id == "" or item_id == "nothing":
			lines.append("No encontrás nada.")
		else:
			match item_id:
				"gold_small":
					var amount := randi_range(8, 12)
					lines.append("Encontrás %d de oro." % amount)
					rewards["gold"] = amount
				"gold_medium":
					var amount2 := randi_range(20, 30)
					lines.append("Encontrás %d de oro." % amount2)
					rewards["gold"] = amount2
				"potion_small":
					lines.append("Encontrás una poción menor de curación.")
					(rewards["items"] as Array).append("potion_small")
				_:
					var item_kind: String = game_data.get_item_kind(item_id)
					if item_kind == "weapon":
						lines.append("Encontrás un %s." % game_data.get_item_display_name(item_id))
						(rewards["items"] as Array).append(item_id)
					elif item_kind == "armor":
						lines.append("Encontrás %s." % game_data.get_item_display_name(item_id))
						(rewards["items"] as Array).append(item_id)
					else:
						lines.append("Encontrás algo interesante.")
	else:
		lines.append("Encontrás 9 de oro.")
		rewards["gold"] = 9

	return {
		"lines": lines,
		"rewards": rewards,
	}


static func build_enemy_instance(game_data, enemy_id: String) -> Dictionary:
	var enemy_data: Dictionary = game_data.get_enemy(enemy_id)
	var enemy := {
		"id": enemy_id,
		"name": String(enemy_data.get("name", enemy_id.capitalize())),
		"hp_max": int(enemy_data.get("hp_max", enemy_data.get("hp", 8))),
		"hp": int(enemy_data.get("hp_min", 6)),
		"dmg_min": int(enemy_data.get("dmg_min", 1)),
		"dmg_max": int(enemy_data.get("dmg_max", 3)),
		"armor": int(enemy_data.get("armor", enemy_data.get("defense", 0))),
		"gold_min": int(enemy_data.get("gold_min", 1)),
		"gold_max": int(enemy_data.get("gold_max", 4)),
		"xp": int(enemy_data.get("xp", 3)),
		"evasion": float(enemy_data.get("evasion", Combat.DODGE_ENEMY_DEFAULT)),
		"level": int(enemy_data.get("level", 1)),
	}

	var hp_min := int(enemy_data.get("hp_min", enemy["hp"]))
	var hp_max := int(enemy_data.get("hp_max", max(hp_min, int(enemy["hp_max"]))))
	enemy["hp"] = randi_range(hp_min, hp_max)
	enemy["hp_max"] = hp_max
	return enemy
