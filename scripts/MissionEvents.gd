extends Node

# --- Eventos básicos de misión ---
# Cada función devuelve un Array de eventos (dictionaries)
# que Mission.gd ya sabe procesar (room_flavor, search_room, enemy, trap, etc.)

class_name MissionEvents


# 🪙 Depósito / búsqueda
static func event_deposito(loc: Dictionary) -> Array[Dictionary]:
	var seq: Array[Dictionary] = []

	# En vez de poner el room_flavor acá, pasamos la descripción al evento search_room.
	seq.append({
		"type": "search_room",
		"loot_table_id": String(loc.get("loot_table_id", "")),
		"desc": "Llegás a lo que parece ser un depósito polvoriento."
	})

	# 20% chance de enemigo sorpresa
	if randf() < 0.2:
		var monster_ids: Array = loc.get("monster_ids", [])
		if not monster_ids.is_empty():
			var mid: String = GameData.pick_random(monster_ids)
			if not GameData.enemies.has(mid):
				mid = "goblin"
			seq.append({"type": "enemy", "id": mid})

	return seq

# 🚶 Pasillo vacío
static func event_pasillo(loc: Dictionary) -> Array[Dictionary]:
	var seq: Array[Dictionary] = []

	# Narración inicial
	seq.append({"type": "room_flavor", "text": "Avanzás por un pasillo oscuro y silencioso."})

	# 15% chance de trampa
	if randf() < 0.15:
		seq.append({"type": "trap", "dmg_min": 1, "dmg_max": 3})

	return seq


# ⚔️ Encuentro enemigo
static func event_enemigo(loc: Dictionary) -> Array[Dictionary]:
	var seq: Array[Dictionary] = []

	# Narración inicial
	seq.append({"type": "room_flavor", "text": "De repente, algo se mueve entre las sombras."})

	# Elegir 1 enemigo de la locación
	var monster_ids: Array = loc.get("monster_ids", [])
	if not monster_ids.is_empty():
		var mid: String = GameData.pick_random(monster_ids)
		if not GameData.enemies.has(mid):
			mid = "goblin"
		seq.append({"type": "enemy", "id": mid})

		# 20% chance de que aparezca un segundo enemigo
		if randf() < 0.2:
			var mid2: String = GameData.pick_random(monster_ids)
			if not GameData.enemies.has(mid2):
				mid2 = "goblin"
			seq.append({"type": "enemy", "id": mid2})

	return seq
