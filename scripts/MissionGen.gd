extends Node

const MissionEvents = preload("res://scripts/MissionEvents.gd")

# Generador de misiones aleatorias
# Retorna un Array de eventos [{type, ...}, ...]

static func build_sequence(location_id: String, length_tag: String = "short") -> Array[Dictionary]:
	var seq: Array[Dictionary] = []

	# Ver locación
	if not GameData.has_location(location_id):
		print("[MissionGen] WARNING: location_id no existe:", location_id)
		return [
			{"type": "room_flavor", "text": "Avanzás por un pasillo oscuro."},
			{"type": "search_room"},
			{"type": "enemy", "id": "goblin"},
			{"type": "end"}
		]

	var loc: Dictionary = GameData.get_location(location_id)

	# Duración objetivo (en segundos de 'pacing', no reloj exacto)
	var max_time := 0
	match length_tag:
		"short":
			max_time = randi_range(120, 180)	# 2–3 min
		"normal":
			max_time = randi_range(300, 480)	# 5–8 min
		_:
			max_time = randi_range(150, 240)

	# Intro (una sola vez)
	var loc_name: String = String(loc.get("name", "el lugar…"))
	var intro_text := GameData.pick_text(loc.get("flavor_ids", []), "Te internás en " + loc_name)
	seq.append({"type": "room_flavor", "text": intro_text})

	# Pool de eventos
	var event_pool: Array = loc.get("event_ids", [])
	if event_pool.is_empty():
		event_pool = ["deposito", "pasillo", "enemigo"]

	var elapsed := 0
	var steps := 0
	var max_steps := 20		# guardarraíl para no pasarnos

	print("[MissionGen] INICIO → objetivo:", max_time, "s; pool:", event_pool)

	while elapsed < max_time and steps < max_steps:
		var choice: String = (GameData.pick_random(event_pool) as String)

		var ev_seq: Array[Dictionary] = []
		var cost := 0

		match choice:
			"deposito":
				ev_seq = MissionEvents.event_deposito(loc)
				cost = randi_range(6, 10)
			"pasillo":
				ev_seq = MissionEvents.event_pasillo(loc)
				cost = randi_range(4, 7)
			"enemigo":
				ev_seq = MissionEvents.event_enemigo(loc)
				cost = randi_range(8, 12)
			_:
				# fallback
				ev_seq = MissionEvents.event_pasillo(loc)
				cost = 5

		seq += ev_seq
		elapsed += cost
		steps += 1

		print("[MissionGen] step:", steps, " choice:", choice, " +", cost, "s → elapsed:", elapsed, "/", max_time)

	# Cierre
	seq.append({"type": "end"})
	print("[MissionGen] FIN: steps=", steps, " elapsed=", elapsed, "/", max_time, " eventos_total=", seq.size())

	return seq
