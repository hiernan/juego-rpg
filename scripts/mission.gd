extends Control

const MissionGen = preload("res://scripts/MissionGen.gd")
const Combat = preload("res://scripts/Combat.gd")

# UI base
@onready var label_titulo: Label = %LabelTitulo
@onready var log: RichTextLabel = %RichTextLog
@onready var btn_abandonar: Button = %ButtonAbandonar

# Timers y audio
@onready var timer_tick: Timer = %TimerTick
@onready var timer_dots: Timer = %TimerDots
@onready var bell: AudioStreamPlayer = %AudioBell

# (Si ya creaste el panel derecho y el overlay)
@onready var loot_log: RichTextLabel = %RunLootLog
@onready var overlay: PanelContainer = %ResultOverlay
@onready var overlay_title: Label = %ResultTitle
@onready var overlay_summary: RichTextLabel = %ResultSummary

var run_rewards := {
	"gold": 0,
	"xp": 0,
	"items": []			# Array[String] de item_id
}

var events: Array[Dictionary] = []        # cola de eventos de la misión
var waiting_dots := false
var dots_elapsed := 0
var dots_target := 0
var pending_event: Dictionary = {}        # guardamos el evento que requiere espera
var line_queue: Array = []     # cola de renglones a imprimir
var next_delay: float = 1.5            # delay entre líneas (lo maneja TimerTick)
var dots_plan: Dictionary = {}	# guarda {min,max,ev} para iniciar puntos en el próximo tick
var dots_remaining: int = 0

# Cola de líneas/efectos ya la tenés como line_queue (usamos Variant)
var effect_queue: Array = []	# por si preferís separar (no obligatorio)

# Enemigo actual (cuando hay combate)
var current_enemy := {
	"id": "",
	"name": "",
	"hp": 0,
	"hp_max": 0,
	"dmg_min": 0,
	"dmg_max": 0,
	"gold_min": 0,
	"gold_max": 0,
	"xp": 0,
	"evasion": 0.05,	# default; luego lo podremos leer de CSV
	"level": 1
}

func _enqueue_lines(lines: Array, delay_sec: float = 0.9) -> void:
	for line in lines:
		line_queue.append(line)
	next_delay = delay_sec
	if not waiting_dots and not timer_tick.is_stopped():
		timer_tick.stop()
		timer_tick.start(next_delay)


func _ready() -> void:
	label_titulo.text = "Misión en curso"
	_build_demo_sequence()     # por ahora una secuencia fake de prueba
	timer_tick.start()         # arranca el loop de eventos
	overlay.visible = false
	_reward_clear()

# ---------- Helpers de log ----------
func _append_line(t: String) -> void:
	log.append_text(t + "\n")
	_scroll_to_bottom()

func _append_gm(t: String) -> void:
	_append_line("[b]GM:[/b] " + t)

func _append_avatar(t: String) -> void:
	_append_line("[i]Avatar:[/i] " + t)

func _fmt_gm(t: String) -> String:
	return "[b]GM:[/b] " + t

func _fmt_avatar(t: String) -> String:
	return "[i]Avatar:[/i] " + t

func _build_demo_sequence() -> void:
	var loc_id: String = GameData.current_location_id
	events = MissionGen.build_sequence(loc_id, "short")
	print("[Mission] eventos recibidos:", events.size())

# ---------- Loop de misión ----------
func _on_timer_tick_timeout() -> void:
	if waiting_dots:
		return

	# 1) Si hay líneas pendientes, imprimimos una y rearmamos el timer
	if not line_queue.is_empty():
		var node = line_queue.pop_front()

		# 1) Si es un marcador de efecto, aplicarlo y programar próximo tick corto
		if typeof(node) == TYPE_DICTIONARY and (node as Dictionary).has("apply"):
			_apply_marker(node)
			timer_tick.start(0.1)
			return

		# 2) Si es string (línea de texto), manejar marcadores y texto
		if typeof(node) == TYPE_STRING:
			var line: String = (node as String)

			# marcador: no imprimir, arrancar puntos
			if line == "[DO_SEARCH_DOTS]":
				_start_search_dots()
				timer_tick.start(0.1)
				return

			# inline o normal
			if line.begins_with("[INLINE]"):
				_append_inline(line.substr(8))
			else:
				_append_line(line)

			timer_tick.start(next_delay)
			return

		# 3) fallback por si llega otro tipo
		_append_line(String(node))
		timer_tick.start(next_delay)
		return

	# 2) Si no hay líneas, consumimos un evento de la misión
	if events.is_empty():
		_finish_mission()
		return

	var ev: Dictionary = events.pop_front() as Dictionary
	match ev.get("type", ""):
		"room_flavor":
			# Encolamos una sola línea del GM con pausa suave
			_enqueue_lines([_fmt_gm(ev.get("text", "Avanzás con cautela…"))], 1.4)
		"search_room":
			var desc: String = String(ev.get("desc", "Llegás a una sala silenciosa."))
			# 1) descripción del GM
			_enqueue_lines([_fmt_gm(desc)], 0.8)
			# 2) línea del Avatar con INLINE para que los puntos vayan en la misma línea
			line_queue.append("[INLINE]" + _fmt_avatar("reviso a ver si hay algo interesante "))
			# 3) preparar plan de puntos con el evento (ev) dentro
			dots_plan = {"min": 5, "max": 10, "ev": ev}
			# 4) marcador que activa los puntos (no se imprime)
			line_queue.append("[DO_SEARCH_DOTS]")
			next_delay = 0.6
			return
		"enemy":
			_resolve_enemy_as_lines(ev)
		"trap":
			_enqueue_lines([
				_fmt_gm("Una trampa de dardos se activa. Te roza (1 de daño).")
			], 1.3)
			# TODO: aplicar daño real
		"loot":
			_enqueue_lines([
				_fmt_gm("Encontrás un cofre con 7 de oro.")
			], 1.2)
		"end":
			_finish_mission()
		_:
			_enqueue_lines([_fmt_gm("Nada relevante ocurre…")], 1.0)

func _start_search_dots() -> void:
	# activar estado de puntos
	waiting_dots = true

	# setear cantidad
	var min := int(dots_plan.get("min", 5))
	var max := int(dots_plan.get("max", 10))
	dots_remaining = randi_range(min, max)

	# arrancar timer de puntos
	timer_dots.start(0.5)

	# mientras hay puntos, no seguimos procesando la cola
	# (el _on_timer_tick_timeout() ya retorna si waiting_dots = true)

# ---------- Puntos suspensivos ----------
func _start_dots_rng(min_s: int, max_s: int, ev: Dictionary) -> void:
	waiting_dots = true
	dots_elapsed = 0
	dots_target = randi_range(min_s, max_s)
	pending_event = ev
	timer_tick.stop()
	timer_dots.start()  # 1 punto por segundo

func _on_timer_dots_timeout() -> void:
	if dots_remaining > 0:
		_append_inline(".")
		dots_remaining -= 1
		return

	# Terminar puntos y resolver búsqueda
	timer_dots.stop()
	# romper la línea inline antes del resultado
	line_queue.append("[INLINE]\n")
	
	var ev: Dictionary = dots_plan.get("ev", {})
	var result_lines: Array = []

	# loot table (nuevo esquema item_id)
	var lt_id: String = String(ev.get("loot_table_id", ""))
	if lt_id != "" and GameData.loot_tables.has(lt_id):
		var entries: Array = GameData.loot_tables[lt_id] as Array
		var pick := GameData.pick_weighted(entries)
		var item_id: String = String(pick.get("item_id", ""))

		if item_id == "" or item_id == "nothing":
			result_lines.append(_fmt_gm("No encontrás nada."))
			# no aplicar nada
		else:
			match item_id:
				"gold_small":
					var amount := randi_range(8, 12)
					result_lines.append(_fmt_gm("Encontrás %d de oro." % amount))
					_enqueue_apply_reward(amount, 0, [])
				"gold_medium":
					var amount2 := randi_range(20, 30)
					result_lines.append(_fmt_gm("Encontrás %d de oro." % amount2))
					_enqueue_apply_reward(amount2, 0, [])
				"potion_small":
					result_lines.append(_fmt_gm("Encontrás una poción menor de curación."))
					_enqueue_apply_reward(0, 0, ["potion_small"])
				_:
					if GameData.weapons.has(item_id):
						var wname: String = String(GameData.weapons[item_id].get("name", "arma"))
						result_lines.append(_fmt_gm("Encontrás un %s." % wname))
						_enqueue_apply_reward(0, 0, [item_id])
					elif GameData.armors.has(item_id):
						var aname: String = String(GameData.armors[item_id].get("name", "armadura"))
						result_lines.append(_fmt_gm("Encontrás %s." % aname))
						_enqueue_apply_reward(0, 0, [item_id])
					else:
						result_lines.append(_fmt_gm("Encontrás algo interesante."))
						# sin aplicar (desconocido)
	else:
		# Fallback (por si la locación no trajo loot_table)
		result_lines.append(_fmt_gm("Encontrás 9 de oro."))
		_enqueue_apply_reward(9, 0, [])

	_enqueue_lines(result_lines, 1.0)
		# reanudar el loop
	waiting_dots = false
	timer_tick.start(0.2)

func _append_inline(t: String) -> void:
	log.append_text(t)
	_scroll_to_bottom()

func _scroll_to_bottom() -> void:
	log.scroll_to_line(log.get_line_count() - 1)

# ---------- Resoluciones simples ----------
func _resolve_enemy_as_lines(ev: Dictionary) -> void:
	# 1) Cargar definición
	var enemy_id: String = String(ev.get("id", "goblin"))
	var def: Dictionary = GameData.enemies.get(enemy_id, {})
	current_enemy = {
		"id": enemy_id,
		"name": String(def.get("name", enemy_id.capitalize())),
		"hp_max": int(def.get("hp_max", def.get("hp", 8))),	# por si tus CSV tenían "hp"
		"hp": int(def.get("hp_min", 6)),						# elegimos dentro del rango
		"dmg_min": int(def.get("dmg_min", 1)),
		"dmg_max": int(def.get("dmg_max", 3)),
		"gold_min": int(def.get("gold_min", 1)),
		"gold_max": int(def.get("gold_max", 4)),
		"xp": int(def.get("xp", 3)),
		"evasion": float(def.get("evasion", Combat.DODGE_ENEMY_DEFAULT)),
		"level": int(def.get("level", 1))
	}
	# Si tenés hp_min/hp_max en CSV, usá ambos:
	var hpmin := int(def.get("hp_min", current_enemy["hp"]))
	var hpmax := int(def.get("hp_max", max(hpmin, int(current_enemy["hp_max"]))))
	current_enemy["hp"] = randi_range(hpmin, hpmax)
	current_enemy["hp_max"] = hpmax

	var enemy_name: String = String(current_enemy["name"])

	# 2) Presentación
	_enqueue_lines([_fmt_gm("Un %s aparece de golpe." % enemy_name)], 0.8)

	# --- ARRANCAR RONDAS DE COMBATE ---
	line_queue.append({"apply": {"type": "combat_next"}})
	return

func _resolve_trap(ev: Dictionary) -> void:
	_append_gm("Una trampa de dardos se activa. Te roza (1 de daño).")
	# TODO: aplicar daño real

func _resolve_loot(ev: Dictionary) -> void:
	_append_gm("Encontrás un cofre con 7 de oro.")
	# TODO: sumar oro real

# ---------- Finalización / abandono ----------
func _finish_mission() -> void:
	timer_tick.stop()
	timer_dots.stop()
	if bell.stream:
		bell.play()
	_show_result_overlay("¡Victoria!", false)  # lost = false

func _on_button_abandonar_pressed() -> void:
	timer_tick.stop()
	timer_dots.stop()
	_show_result_overlay("Misión abandonada", false)  # lost = false

func _finish_death() -> void:
	timer_tick.stop()
	timer_dots.stop()
	if bell.stream:
		bell.play()
	_show_result_overlay("Tu avatar murió", true)  # lost = true

func _on_button_volver_pressed() -> void:
	overlay.visible = false
	if GameData.is_dead():
		# Muerte: perder botín y respawn en bolas (con HP llena, nivel se mantiene)
		GameData.on_death()
	else:
		# Éxito o abandono: aplicar botín
		_apply_rewards_to_avatar()
	# Limpio botín para la próxima misión
	_reward_clear()
	get_tree().change_scene_to_file("res://Town.tscn")

func _reward_add_gold(n: int) -> void:
	run_rewards["gold"] = int(run_rewards["gold"]) + max(0, n)
	_refresh_loot_ui()

func _reward_add_xp(n: int) -> void:
	run_rewards["xp"] = int(run_rewards["xp"]) + max(0, n)
	_refresh_loot_ui()

func _reward_add_item(item_id: String) -> void:
	var arr: Array = run_rewards["items"]
	arr.append(item_id)
	run_rewards["items"] = arr
	_refresh_loot_ui()

func _reward_clear() -> void:
	run_rewards = {"gold": 0, "xp": 0, "items": []}
	_refresh_loot_ui()

func _refresh_loot_ui() -> void:
	if loot_log == null: return
	var lines: Array = []
	lines.append("[b]Oro:[/b] %d" % int(run_rewards["gold"]))
	lines.append("[b]XP:[/b] %d" % int(run_rewards["xp"]))
	lines.append("[b]Objetos:[/b]")
	for id in run_rewards["items"]:
		var name: String = String(id)
		if GameData.weapons.has(id):
			name = String(GameData.weapons[id].get("name", id))
		elif GameData.armors.has(id):
			name = String(GameData.armors[id].get("name", id))
		elif id == "potion_small":
			name = "Poción menor de curación"
		lines.append(" • " + name)
	loot_log.clear()
	loot_log.append_text(_join_lines(lines))

func _pick_avatar_ouch() -> String:
	var quips: Array = ["¡Eh! Eso dolió.", "¡Auch!", "¡Ojo!", "¡Uff!", "¡Ay!"]
	return String(quips[randi() % quips.size()])

func _compose_summary_text(lost: bool) -> String:
	var sb: Array = []
	if lost:
		sb.append("Perdiste todo el botín de esta misión.")
	else:
		sb.append("Botín obtenido:")
		sb.append(" • Oro: %d" % int(run_rewards["gold"]))
		sb.append(" • XP: %d" % int(run_rewards["xp"]))
		if (run_rewards["items"] as Array).is_empty():
			sb.append(" • Objetos: (ninguno)")
		else:
			sb.append(" • Objetos:")
			for id in run_rewards["items"]:
				var name: String = String(id)
				if GameData.weapons.has(id):
					name = String(GameData.weapons[id].get("name", id))
				elif GameData.armors.has(id):
					name = String(GameData.armors[id].get("name", id))
				elif id == "potion_small":
					name = "Poción menor de curación"
				sb.append("    - " + name)
	return _join_lines(sb)

func _show_result_overlay(title: String, lost: bool) -> void:
	timer_tick.stop()
	timer_dots.stop()
	if overlay:
		overlay_title.text = title
		overlay_summary.clear()
		overlay_summary.append_text(_compose_summary_text(lost))
		overlay.visible = true

func _apply_rewards_to_avatar() -> void:
	GameData.avatar["gold"] = int(GameData.avatar["gold"]) + int(run_rewards["gold"])
	GameData.avatar["xp"] = int(GameData.avatar["xp"]) + int(run_rewards["xp"])
	var inv: Array = GameData.avatar["inventory"]
	for id in run_rewards["items"]:
		inv.append(id)
	GameData.avatar["inventory"] = inv

func _join_lines(arr: Array) -> String:
	var out := ""
	var first := true
	for v in arr:
		if first:
			out += String(v)
			first = false
		else:
			out += "\n" + String(v)
	return out
# Encolá un efecto para aplicar tras mostrar su línea asociada
func _enqueue_apply_reward(gold: int, xp: int, items: Array) -> void:
	line_queue.append({"apply": {"type": "reward", "gold": gold, "xp": xp, "items": items}})

func _enqueue_consume_item(item_id: String, heal: int) -> void:
	line_queue.append({"apply": {"type": "consume", "item_id": item_id, "heal": heal}})

func _apply_marker(d: Dictionary) -> void:
	var ap: Dictionary = d.get("apply", {})
	var typ: String = String(ap.get("type", ""))
	match typ:
		"finish_death":
			call_deferred("_finish_death")
		"combat_next":
			_combat_round()
		"reward":
			_reward_add_gold(int(ap.get("gold", 0)))
			_reward_add_xp(int(ap.get("xp", 0)))
			for id in (ap.get("items", []) as Array):
				_reward_add_item(String(id))
		"consume":
			# curar avatar y remover ítem de inventario de la run (prioridad run)
			var heal := int(ap.get("heal", 0))
			GameData.avatar["hp"] = min(int(GameData.avatar["max_hp"]), int(GameData.avatar["hp"]) + heal)
			var id := String(ap.get("item_id", ""))
			# sacar primero de run_rewards.items si existe
			var arr: Array = run_rewards["items"]
			var idx := arr.find(id)
			if idx >= 0:
				arr.remove_at(idx)
				run_rewards["items"] = arr
			else:
				# si no está en run, intentar del inventario del avatar
				var inv: Array = GameData.avatar.get("inventory", [])
				var idx2 := inv.find(id)
				if idx2 >= 0:
					inv.remove_at(idx2)
					GameData.avatar["inventory"] = inv
			_refresh_loot_ui()

func _auto_potion_if_needed() -> void:
	var hp := int(GameData.avatar.get("hp", 1))
	var hp_max := int(GameData.avatar.get("hp_max", 1))
	if hp_max <= 0: return
	if float(hp) / float(hp_max) > 0.25: return

	# ¿tenemos poción? preferimos ítem de la RUN; si no, del inventario del avatar
	var has := false
	for id in (run_rewards["items"] as Array):
		if id == "potion_small":
			has = true
			break
	if not has:
		for id2 in (GameData.avatar.get("inventory", []) as Array):
			if id2 == "potion_small":
				has = true
				break
	if not has: return

	# mostrá la línea y encolá el consumo (APPLY luego del texto)
	_enqueue_lines([_fmt_avatar("Tomo una poción…")], 0.8)
	_enqueue_consume_item("potion_small", 5)

func _combat_round() -> void:
	# Seguridad: si no hay enemigo activo, no hacer nada
	if String(current_enemy.get("id", "")) == "":
		return

	var enemy_name: String = String(current_enemy["name"])

	# --- 1) Enemigo ataca ---
	var armor_val := GameData.get_armor_value()
	var e_lvl := int(current_enemy["level"])
	var a_lvl := Combat.get_avatar_level()

	if Combat.roll_hit(e_lvl, a_lvl, 0.0, 0.0):
		# crítico del enemigo (activado). Si querés desactivarlo por ahora:
		# var crit_enemy := false
		var crit_enemy := Combat.roll_crit()

		# daño base y mitigación
		var dmg_e := Combat.compute_enemy_damage(int(current_enemy["dmg_min"]), int(current_enemy["dmg_max"]), armor_val)
		if crit_enemy:
			dmg_e = int(ceil(float(dmg_e) * Combat.CRIT_MULT))

		# aplicar daño
		GameData.apply_damage(dmg_e)

		# construir línea de ataque SIN operador ternario
		var enemy_line: String
		if crit_enemy:
			enemy_line = _fmt_gm("¡Golpe crítico del %s! (%d)" % [enemy_name, dmg_e])
		else:
			enemy_line = _fmt_gm("El %s te hiere (%d)." % [enemy_name, dmg_e])

		# 1) SIEMPRE mostramos el golpe primero
		_enqueue_lines([enemy_line], 0.8)

		# 2) Si te mató, mostramos despedida y cerramos vía marcador (respeta orden)
		if GameData.is_dead():
			_enqueue_lines([_fmt_gm("Tus fuerzas te abandonan…")], 1.0)
			line_queue.append({"apply": {"type": "finish_death"}})
			return

		# 3) Si seguís vivo, recién ahí va la queja del Avatar
		_enqueue_lines([_fmt_avatar(_pick_avatar_ouch())], 0.8)

	else:
		_enqueue_lines([_fmt_gm("El %s ataca, pero falla." % enemy_name)], 0.8)


	# Autopoción si corresponde (tras recibir daño)
	_auto_potion_if_needed()

	# Muerte del avatar
	if GameData.is_dead():
		_enqueue_lines([_fmt_gm("Tus fuerzas te abandonan…")], 1.2)
		call_deferred("_finish_death")
		return
	# si ya estás bajo de vida aunque el enemigo falló, intentá poción ahora
	_auto_potion_if_needed()

	# --- 2) Avatar ataca ---
	if not Combat.roll_hit(Combat.get_avatar_level(), e_lvl, 0.0, 0.0):
		_enqueue_lines([_fmt_gm("Atacás… fallás.")], 0.8)
		# Encolar próxima ronda
		line_queue.append({"apply": {"type": "combat_next"}})
		return

	# Evasión del enemigo
	if Combat.roll_dodge(float(current_enemy["evasion"])):
		_enqueue_lines([_fmt_gm("Atacás… ¡pero el %s esquiva!" % enemy_name)], 0.9)
		# Encolar próxima ronda
		line_queue.append({"apply": {"type": "combat_next"}})
		return

	# Crítico + daño
	var w := GameData.get_weapon_damage_range()
	var crit := Combat.roll_crit()
	var dmg_you := Combat.compute_avatar_damage(w.x, w.y, 0, crit)

	var attack_line: String
	if crit:
		attack_line = _fmt_gm("¡Golpe crítico! (%d)" % dmg_you)
	else:
		attack_line = _fmt_gm("Atacás con tu arma (%d)." % dmg_you)

		current_enemy["hp"] = max(0, int(current_enemy["hp"]) - dmg_you)
		_enqueue_lines([attack_line], 0.9)

	# ¿Murió?
	if int(current_enemy["hp"]) <= 0:
		var gold_gain := randi_range(int(current_enemy["gold_min"]), int(current_enemy["gold_max"]))
		var xp_gain := int(current_enemy["xp"])
		_enqueue_lines([_fmt_gm("El %s cae. +%d oro, +%d XP" % [enemy_name, gold_gain, xp_gain])], 1.0)
		# Aplicar DESPUÉS del texto
		_enqueue_apply_reward(gold_gain, xp_gain, [])
		# Limpieza del enemigo actual
		current_enemy["id"] = ""
		return

	# Si sigue vivo, encolar otra ronda
	line_queue.append({"apply": {"type": "combat_next"}})
