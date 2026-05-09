extends RefCounted

static func cc_get(game_data, key: String, default_value: float) -> float:
	var row: Dictionary = game_data.combat_constants.get("global", {})
	return float(row.get(key, default_value))


static func damage_reduction(game_data, value: float) -> float:
	var k_dr: float = cc_get(game_data, "K_DR", 50.0)
	return value / (value + k_dr) if value > 0.0 else 0.0


static func stats_from_actor(actor: Dictionary) -> Dictionary:
	return {
		"LV": int(actor.get("level", 1)),
		"STR": int(actor.get("str", actor.get("STR", 0))),
		"DEX": int(actor.get("dex", actor.get("DEX", 0))),
		"INT": int(actor.get("int", actor.get("INT", 0))),
	}


static func equipped_weapon_avg(game_data, actor: Dictionary) -> float:
	var weapon_id := String(actor.get("weapon_id", ""))
	if weapon_id != "" and game_data.weapons.has(weapon_id):
		var weapon: Dictionary = game_data.weapons.get(weapon_id, {})
		return (float(weapon.get("dmg_min", 0)) + float(weapon.get("dmg_max", 0))) / 2.0
	return 0.0


static func equipped_armor_def(game_data, actor: Dictionary) -> float:
	var total := 0.0
	if actor.has("armor"):
		total += float(actor.get("armor", 0))

	var armor_id := String(actor.get("armor_id", ""))
	if armor_id != "" and game_data.armors.has(armor_id):
		var armor: Dictionary = game_data.armors.get(armor_id, {})
		total += float(armor.get("armor", armor.get("defense", 0)))

	return total


static func get_primary_secondary_for_action(action_type: String, actor_stats: Dictionary) -> Dictionary:
	var strength: float = float(actor_stats.get("STR", 0))
	var dexterity: float = float(actor_stats.get("DEX", 0))
	var intelligence: float = float(actor_stats.get("INT", 0))
	var primary := 0.0
	var secondary := 0.0

	match action_type:
		"MELEE":
			primary = strength
			secondary = (dexterity + intelligence) / 2.0
		"RANGED":
			primary = dexterity
			secondary = (strength + intelligence) / 2.0
		"MAGIC":
			primary = intelligence
			secondary = (strength + dexterity) / 2.0
		_:
			primary = strength
			secondary = (dexterity + intelligence) / 2.0

	return { "P": primary, "S": secondary }


static func build_offense(game_data, actor: Dictionary, primary: float, secondary: float) -> float:
	var stats := stats_from_actor(actor)
	var level: float = float(stats["LV"])
	var atk0: float = cc_get(game_data, "atk0", 10.0)
	var atk_lv: float = cc_get(game_data, "atk_lv", 3.0)
	var m_primary: float = cc_get(game_data, "mP", 0.8)
	var m_secondary: float = cc_get(game_data, "mS", 0.3)
	var weapon_scale: float = cc_get(game_data, "wpn_scale", 1.0)
	var no_weapon_mult: float = cc_get(game_data, "no_weapon_mult", 0.6)
	var improv_scale: float = cc_get(game_data, "improv_scale", 0.1)

	var atk_base := atk0 + atk_lv * level
	var primary_dr := damage_reduction(game_data, primary)
	var secondary_dr := damage_reduction(game_data, secondary)
	var stat_mult := 1.0 + m_primary * primary_dr + m_secondary * secondary_dr

	var weapon_avg := equipped_weapon_avg(game_data, actor)
	if weapon_avg > 0.0:
		var core_offense := atk_base + weapon_scale * weapon_avg
		return max(1.0, core_offense * stat_mult)

	var improv := improv_scale * primary
	var core_offense_no_weapon := (atk_base + improv) * no_weapon_mult
	return max(1.0, core_offense_no_weapon * stat_mult)


static func build_defense(game_data, actor: Dictionary) -> float:
	var stats := stats_from_actor(actor)
	var level: float = float(stats["LV"])
	var strength: float = float(stats["STR"])
	var intelligence: float = float(stats["INT"])
	var def0: float = cc_get(game_data, "def0", 8.0)
	var def_lv: float = cc_get(game_data, "def_lv", 2.5)
	var d_strength: float = cc_get(game_data, "dSTR", 20.0)
	var d_intelligence: float = cc_get(game_data, "dINT", 20.0)

	var def_base := def0 + def_lv * level
	var armor_def := equipped_armor_def(game_data, actor)
	var stat_def := d_strength * damage_reduction(game_data, strength) + d_intelligence * damage_reduction(game_data, intelligence)
	var core_def := def_base + armor_def + stat_def
	return max(0.0, core_def)
