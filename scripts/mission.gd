extends Control

var mission_time_scale: float = 2.0	# 1.0 normal, 2.0 el doble, 0.5 más lento
const MissionGen = preload("res://scripts/MissionGen.gd")
const Combat = preload("res://scripts/Combat.gd")
const MissionStateScript = preload("res://scripts/state/MissionState.gd")
const MissionRunnerServiceScript = preload("res://scripts/services/MissionRunnerService.gd")
const MissionRewardServiceScript = preload("res://scripts/services/MissionRewardService.gd")
const MissionLogFormatterScript = preload("res://scripts/presentation/MissionLogFormatter.gd")

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

var run_rewards := MissionRewardServiceScript.empty_rewards()
var mission_state := MissionStateScript.new()

func _enqueue_lines(lines: Array, delay_sec: float = 0.9) -> void:
	mission_state.enqueue_lines(lines, delay_sec)
	if not mission_state.waiting_dots and not timer_tick.is_stopped():
		timer_tick.stop()
		timer_tick.start(mission_state.next_delay)


func _ready() -> void:
	GameData.loot_bag_reset()
	print("[LOOT] mission start → loot_bag reset")
	GameData.transfer_inventory_to_bag()
	print("[DEBUG] bag at start:", GameData.loot_bag.size(), GameData.loot_bag)
	print("[LOOT] mission start → inventory moved to bag (size=", GameData.loot_bag.size(), ")")
	_refresh_loot_ui()
	label_titulo.text = "Misión en curso"
	Engine.time_scale = mission_time_scale
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
	mission_state.set_events(MissionGen.build_sequence(loc_id, "short"))
	print("[Mission] eventos recibidos:", mission_state.events.size())

# ---------- Loop de misión ----------
func _on_timer_tick_timeout() -> void:
	if mission_state.waiting_dots:
		return

	# 1) Si hay líneas pendientes, imprimimos una y rearmamos el timer
	if mission_state.has_pending_lines():
		var node = mission_state.pop_line()

		# 1) Si es un marcador de efecto, aplicarlo y programar próximo tick corto
		if typeof(node) == TYPE_DICTIONARY and (node as Dictionary).has("apply"):
			_apply_marker(node)
			timer_tick.start(0.1)
			return

		# 2) Si es string (línea de texto), manejar marcadores y texto
		if typeof(node) == TYPE_STRING:
			var line: String = (node as String)

			# marcador: no imprimir, arrancar puntos
			if line == MissionStateScript.SEARCH_DOTS_MARKER:
				_start_search_dots()
				timer_tick.start(0.1)
				return

			# inline o normal
			if line.begins_with(MissionStateScript.INLINE_PREFIX):
				_append_inline(line.substr(8))
			else:
				_append_line(line)

			timer_tick.start(mission_state.next_delay)
			return

		# 3) fallback por si llega otro tipo
		_append_line(String(node))
		timer_tick.start(mission_state.next_delay)
		return

	# 2) Si no hay líneas, consumimos un evento de la misión
	if not mission_state.has_pending_events():
		_finish_mission()
		return

	var ev: Dictionary = mission_state.pop_event()
	match ev.get("type", ""):
		"room_flavor":
			# Encolamos una sola línea del GM con pausa suave
			_enqueue_lines([_fmt_gm(ev.get("text", "Avanzás con cautela…"))], 1.4)
		"search_room":
			var desc: String = String(ev.get("desc", "Llegás a una sala silenciosa."))
			# 1) descripción del GM
			_enqueue_lines([_fmt_gm(desc)], 0.8)
			# 2) línea del Avatar con INLINE para que los puntos vayan en la misma línea
			mission_state.prepare_search_room(ev, _fmt_avatar("reviso a ver si hay algo interesante "))
			mission_state.next_delay = 0.6
			return
		"enemy":
			_resolve_enemy_as_lines(ev)
		"trap":
			var trap_result: Dictionary = MissionRunnerServiceScript.resolve_trap_event(GameData, ev)
			var trap_damage: int = int(trap_result.get("damage", 0))
			if trap_damage > 0:
				GameData.apply_damage(trap_damage)
			var trap_lines: Array = []
			for line in (trap_result.get("lines", []) as Array):
				trap_lines.append(_fmt_gm(String(line)))
			_enqueue_lines(trap_lines, 1.3)
		"loot":
			var loot_result: Dictionary = MissionRunnerServiceScript.resolve_loot_event(GameData, ev)
			var loot_lines: Array = []
			for line in (loot_result.get("lines", []) as Array):
				loot_lines.append(_fmt_gm(String(line)))
			var loot_rewards: Dictionary = loot_result.get("rewards", {})
			_enqueue_apply_reward(
				int(loot_rewards.get("gold", 0)),
				int(loot_rewards.get("xp", 0)),
				(loot_rewards.get("items", []) as Array).duplicate()
			)
			_enqueue_lines(loot_lines, 1.2)
		"end":
			_finish_mission()
		_:
			_enqueue_lines([_fmt_gm("Nada relevante ocurre…")], 1.0)

func _start_search_dots() -> void:
	mission_state.start_search_dots()
	# arrancar timer de puntos
	timer_dots.start(0.5)

	# mientras hay puntos, no seguimos procesando la cola
	# (el _on_timer_tick_timeout() ya retorna si waiting_dots = true)

func _on_timer_dots_timeout() -> void:
	if mission_state.consume_search_dot():
		_append_inline(".")
		return

	# Terminar puntos y resolver búsqueda
	timer_dots.stop()
	var ev: Dictionary = mission_state.finish_search_dots()
	var resolution: Dictionary = MissionRunnerServiceScript.resolve_search_room(GameData, ev)
	var result_lines: Array = []
	for line in (resolution.get("lines", []) as Array):
		result_lines.append(_fmt_gm(String(line)))

	var rewards: Dictionary = resolution.get("rewards", {})
	var reward_gold: int = int(rewards.get("gold", 0))
	var reward_xp: int = int(rewards.get("xp", 0))
	var reward_items: Array = (rewards.get("items", []) as Array).duplicate()
	if reward_gold > 0 or reward_xp > 0 or not reward_items.is_empty():
		_enqueue_apply_reward(reward_gold, reward_xp, reward_items)

	_enqueue_lines(result_lines, 1.0)
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
	mission_state.set_current_enemy(MissionRunnerServiceScript.build_enemy_instance(GameData, enemy_id))

	var enemy_name: String = String(mission_state.current_enemy["name"])

	# 2) Presentación
	_enqueue_lines([_fmt_gm("Un %s aparece de golpe." % enemy_name)], 0.8)

	# --- ARRANCAR RONDAS DE COMBATE ---
	mission_state.enqueue_node({"apply": {"type": "combat_next"}})
	return

# ---------- Finalización / abandono ----------
func _finish_mission() -> void:
	timer_tick.stop()
	timer_dots.stop()
	if bell.stream:
		bell.play()
	mission_state.set_result_bag(GameData.loot_bag)
	GameData.loot_bag_to_inventory()
	_show_result_overlay("¡Victoria!", false)  # lost = false

func _on_button_abandonar_pressed() -> void:
	timer_tick.stop()
	timer_dots.stop()
	mission_state.set_result_bag(GameData.loot_bag)
	GameData.loot_bag_to_inventory()
	_show_result_overlay("Misión abandonada", false)  # lost = false

func _finish_death() -> void:
	timer_tick.stop()
	timer_dots.stop()
	if bell.stream:
		bell.play()

	# Conservar la XP ganada en la misión (aunque se pierda la bolsa/oro)
	var gained_xp: int = int(run_rewards.get("xp", 0))
	GameData.add_xp(gained_xp)

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
	MissionRewardServiceScript.add_gold(run_rewards, n)
	_refresh_loot_ui()

func _reward_add_xp(n: int) -> void:
	MissionRewardServiceScript.add_xp(run_rewards, n)
	_refresh_loot_ui()

func _reward_add_item(item_id: String) -> void:
	MissionRewardServiceScript.add_item(GameData, run_rewards, item_id)
	_refresh_loot_ui()

func _reward_clear() -> void:
	run_rewards = MissionRewardServiceScript.empty_rewards()
	_refresh_loot_ui()

func _refresh_loot_ui() -> void:
	if loot_log == null:
		return
	loot_log.clear()
	loot_log.append_text(MissionLogFormatterScript.format_loot_log(GameData, run_rewards))

func _pick_avatar_ouch() -> String:
	var quips: Array = ["¡Eh! Eso dolió.", "¡Auch!", "¡Ojo!", "¡Uff!", "¡Ay!"]
	return String(quips[randi() % quips.size()])

func _show_result_overlay(title: String, lost: bool) -> void:
	timer_tick.stop()
	timer_dots.stop()
	if overlay:
		overlay_title.text = title
		overlay_summary.clear()
		overlay_summary.append_text(
			MissionLogFormatterScript.format_result_summary(GameData, run_rewards, mission_state.result_bag, lost)
		)
		overlay.visible = true

func _apply_rewards_to_avatar() -> void:
	MissionRewardServiceScript.apply_to_avatar(GameData, run_rewards)
# Encolá un efecto para aplicar tras mostrar su línea asociada
func _enqueue_apply_reward(gold: int, xp: int, items: Array) -> void:
	mission_state.enqueue_node({"apply": {"type": "reward", "gold": gold, "xp": xp, "items": items}})

func _enqueue_consume_item(item_id: String, heal: int) -> void:
	mission_state.enqueue_node({"apply": {"type": "consume", "item_id": item_id, "heal": heal}})

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
			var id := String(ap.get("item_id", ""))
			MissionRewardServiceScript.consume_item(GameData, run_rewards, id, heal)
			_refresh_loot_ui()

func _combat_round() -> void:
	# Seguridad: si no hay enemigo activo, no hacer nada
	if String(mission_state.current_enemy.get("id", "")) == "":
		return

	var enemy_name: String = String(mission_state.current_enemy["name"])

	# --- 1) Enemigo ataca ---
	var e_lvl := int(mission_state.current_enemy["level"])
	var a_lvl := Combat.get_avatar_level()

	if Combat.roll_hit(e_lvl, a_lvl, 0.0, 0.0):
		# Daño con ATK/DEF + flags (block/graze/crit)
		var res_e := Combat.compute_enemy_hit_detail(mission_state.current_enemy, GameData.get_avatar_state())
		var dmg_e: int = int(res_e["dmg"])
		var flags_e: Dictionary = res_e["flags"]

		# aplicar daño
		GameData.apply_damage(dmg_e)

		# construir línea de ataque según flags (prioridad: block > graze > crit > normal)
		var enemy_line: String
		if bool(flags_e.get("block", false)):
			enemy_line = _fmt_gm("¡Bloqueás parcialmente el golpe del %s! (%d)" % [enemy_name, dmg_e])
		elif bool(flags_e.get("graze", false)):
			enemy_line = _fmt_gm("El %s te roza… (%d)" % [enemy_name, dmg_e])
		elif bool(flags_e.get("crit", false)):
			enemy_line = _fmt_gm("¡Golpe crítico del %s! (%d)" % [enemy_name, dmg_e])
		else:
			enemy_line = _fmt_gm("El %s te hiere (%d)." % [enemy_name, dmg_e])

		# 1) SIEMPRE mostramos el golpe primero
		_enqueue_lines([enemy_line], 0.8)

		# 2) Si te mató, mostramos despedida y cerramos vía marcador (respeta orden)
		if GameData.is_dead():
			_enqueue_lines([_fmt_gm("Tus fuerzas te abandonan…")], 1.0)
			mission_state.enqueue_node({"apply": {"type": "finish_death"}})
			return

		# 3) Si seguís vivo, recién ahí va la queja del Avatar
		_enqueue_lines([_fmt_avatar(_pick_avatar_ouch())], 0.8)

	else:
		_enqueue_lines([_fmt_gm("El %s ataca, pero falla." % enemy_name)], 0.8)

	# Muerte del avatar
	if GameData.is_dead():
		_enqueue_lines([_fmt_gm("Tus fuerzas te abandonan…")], 1.2)
		call_deferred("_finish_death")
		return

	# --- 2) Avatar ataca ---
	if not Combat.roll_hit(Combat.get_avatar_level(), e_lvl, 0.0, 0.0):
		_enqueue_lines([_fmt_gm("Atacás… fallás.")], 0.8)
		# Encolar próxima ronda
		mission_state.enqueue_node({"apply": {"type": "combat_next"}})
		return

	# Evasión del enemigo
	if Combat.roll_dodge(float(mission_state.current_enemy["evasion"])):
		_enqueue_lines([_fmt_gm("Atacás… ¡pero el %s esquiva!" % enemy_name)], 0.9)
		# Encolar próxima ronda
		mission_state.enqueue_node({"apply": {"type": "combat_next"}})
		return

	# Daño con ATK/DEF + flags (block/graze/crit)
	var res_you := Combat.compute_avatar_hit_detail(GameData.get_avatar_state(), mission_state.current_enemy, "MELEE")
	var dmg_you: int = int(res_you["dmg"])
	var flags_you: Dictionary = res_you["flags"]

	# construir línea de ataque según flags (prioridad: block > graze > crit > normal)
	var attack_line: String
	if bool(flags_you.get("block", false)):
		attack_line = _fmt_gm("¡El enemigo bloquea en parte tu golpe! (%d)" % [dmg_you])
	elif bool(flags_you.get("graze", false)):
		attack_line = _fmt_gm("Tu ataque apenas lo roza… (%d)" % [dmg_you])
	elif bool(flags_you.get("crit", false)):
		attack_line = _fmt_gm("¡Golpe crítico! (%d)" % [dmg_you])
	else:
		attack_line = _fmt_gm("Atacás con tu arma (%d)." % [dmg_you])

	# aplicar daño al enemigo
	mission_state.current_enemy["hp"] = max(0, int(mission_state.current_enemy["hp"]) - dmg_you)
	_enqueue_lines([attack_line], 0.9)

	# ¿Murió?
	if int(mission_state.current_enemy["hp"]) <= 0:
		var defeat_result: Dictionary = MissionRunnerServiceScript.resolve_enemy_defeat(mission_state.current_enemy)
		var defeat_lines: Array = []
		for line in (defeat_result.get("lines", []) as Array):
			defeat_lines.append(_fmt_gm(String(line)))
		var defeat_rewards: Dictionary = defeat_result.get("rewards", {})
		_enqueue_lines(defeat_lines, 1.0)
		_enqueue_apply_reward(
			int(defeat_rewards.get("gold", 0)),
			int(defeat_rewards.get("xp", 0)),
			(defeat_rewards.get("items", []) as Array).duplicate()
		)
		# Limpieza del enemigo actual
		mission_state.clear_current_enemy()
		return

	# Si sigue vivo, encolar otra ronda
	mission_state.enqueue_node({"apply": {"type": "combat_next"}})

func _exit_tree() -> void:
	Engine.time_scale = 1.0
