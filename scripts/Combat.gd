extends Node
class_name Combat

const LOG_COMBAT := true

# --- Constantes de balance (fáciles de tunear) ---
const HIT_BASE: float = 0.60				# base de pegar
const HIT_PER_LEVEL: float = 0.05			# modificador por diferencia de nivel (att - def)
const DODGE_ENEMY_DEFAULT: float = 0.05		# evasión base de enemigo
const CRIT_CHANCE: float = 0.10
const CRIT_MULT: float = 1.5

static func _ccf(key: String, def: float) -> float:
	var row: Dictionary = GameData.combat_constants.get("global", {})
	return float(row.get(key, def))

# Nivel “oculto” del avatar (por ahora 1; ajusta si ya lo guardás en GameData.avatar.level)
static func get_avatar_level() -> int:
	return GameData.get_level()

# Nivel “oculto” del enemigo (si no está en CSV, 1)
static func get_enemy_level(def: Dictionary) -> int:
	return int(def.get("level", 1))

static func _map_action_to_P_S(action_type: String, attacker: Dictionary) -> Dictionary:
	var st := {
		"STR": int(attacker.get("str", attacker.get("STR", 0))),
		"DEX": int(attacker.get("dex", attacker.get("DEX", 0))),
		"INT": int(attacker.get("int", attacker.get("INT", 0))),
	}
	return GameData.get_primary_secondary_for_action(action_type, st)

static func _damage_from_atk_def(atk_total: float, def_total: float) -> int:
	var k: float = _ccf("k", 1.0)
	var s: float = _ccf("spread_s", 0.10)
	var capf: float = _ccf("dmg_cap_factor", 2.5)

	var atk = max(1.0, atk_total)
	var defv = max(0.0, def_total)

	# m = 1 / (1 + DEF/ATK)
	var m = 1.0 / (1.0 + (defv / atk))
	var core = atk * pow(m, k)

	# spread simétrico ±s
	var delta = core * s
	var low := int(floor(core - delta))
	var high := int(ceil(core + delta))
	var base := randi_range(max(1, low), max(1, high))

	# cap por factor del ATK
	var cap := int(ceil(atk * capf))
	return clamp(base, 1, cap)

# Probabilidad de pegar (antes de dodge). Clamp 5%..95%.
static func roll_hit(avatar_lvl: int, enemy_lvl: int, weapon_acc: float = 0.0, enemy_hit_def: float = 0.0) -> bool:
	
	# clampf devuelve float; tipamos p como float para evitar Variant
	var p: float = clampf(
		HIT_BASE + HIT_PER_LEVEL * float(avatar_lvl - enemy_lvl) + weapon_acc - enemy_hit_def,
		0.05, 0.95
	)
	return randf() < p

# Evasión del objetivo (solo si el golpe “pegó”)
static func roll_dodge(evasion: float = DODGE_ENEMY_DEFAULT) -> bool:
	return randf() < evasion

# Crítico
static func roll_crit() -> bool:
	return randf() < CRIT_CHANCE

# Daño del avatar con arma (rango), crítico opcional, luego se resta armadura (mín 1)
static func compute_avatar_damage(wmin: int, wmax: int, armor: int, crit: bool) -> int:
	var base := randi_range(wmin, wmax)
	if crit:
		base = int(ceil(float(base) * CRIT_MULT))
	return max(1, base - armor)

# Daño de enemigo (rango), menos armadura del avatar (mín 1)
static func compute_enemy_damage(emin: int, emax: int, armor: int) -> int:
	var base := randi_range(emin, emax)
	return max(1, base - armor)

# --- Telemetría / cálculo de ATK/DEF por acción (no cambia tu daño actual) ---
func resolve_hit(attacker: Dictionary, defender: Dictionary, action_type: String) -> void:
	# Elegir P (primario) y S (secundario promedio) según acción
	var pm := _map_action_to_P_S(action_type, attacker)
	var P: float = float(pm.get("P", 0.0))
	var S: float = float(pm.get("S", 0.0))

	# Construir ATK/DEF usando helpers de GameData
	var atk_total: float = GameData.build_offense(attacker, P, S)
	var def_total: float = GameData.build_defense(defender)

	if LOG_COMBAT:
		var aLV := int(attacker.get("level", 1))
		var aSTR := int(attacker.get("str", attacker.get("STR", 0)))
		var aDEX := int(attacker.get("dex", attacker.get("DEX", 0)))
		var aINT := int(attacker.get("int", attacker.get("INT", 0)))
		print("[COMBAT] action=%s LV=%d STR=%d DEX=%d INT=%d  P=%.1f S=%.1f  ATK=%.1f DEF(target)=%.1f" % [
			action_type, aLV, aSTR, aDEX, aINT, P, S, atk_total, def_total
		])

# --- Nuevo: daño del avatar con ATK/DEF y acción (no toca tu fórmula antigua) ---
static func compute_avatar_hit_damage(attacker: Dictionary, defender: Dictionary, action_type: String) -> int:
	var pm := _map_action_to_P_S(action_type, attacker)
	var P: float = float(pm.get("P", 0.0))
	var S: float = float(pm.get("S", 0.0))

	var atk_total: float = GameData.build_offense(attacker, P, S)
	var def_total: float = GameData.build_defense(defender)

	var dmg := _damage_from_atk_def(atk_total, def_total)

	# modificadores de evento (bloqueo, graze, crítico)
	var p_block: float = _ccf("p_block", 0.10)
	var mult_block: float = _ccf("mult_block", 0.50)
	if randf() < p_block:
		dmg = int(ceil(float(dmg) * mult_block))

	var p_graze: float = _ccf("p_graze", 0.15)
	var mult_graze: float = _ccf("mult_graze", 0.70)
	if randf() < p_graze:
		dmg = int(ceil(float(dmg) * mult_graze))

	var p_crit: float = _ccf("p_crit", 0.10)
	var mult_crit: float = _ccf("mult_crit", 1.80)
	if randf() < p_crit:
		dmg = int(ceil(float(dmg) * mult_crit))

	return max(1, dmg)

# --- Nuevo: daño del enemigo contra el avatar (acción por defecto: MELEE) ---
static func compute_enemy_hit_damage(attacker: Dictionary, defender: Dictionary, action_type: String = "MELEE") -> int:
	var pm := _map_action_to_P_S(action_type, attacker)
	var P: float = float(pm.get("P", 0.0))
	var S: float = float(pm.get("S", 0.0))

	var atk_total: float = GameData.build_offense(attacker, P, S)
	var def_total: float = GameData.build_defense(defender)

	var dmg := _damage_from_atk_def(atk_total, def_total)

	var p_block: float = _ccf("p_block", 0.10)
	var mult_block: float = _ccf("mult_block", 0.50)
	if randf() < p_block:
		dmg = int(ceil(float(dmg) * mult_block))

	var p_graze: float = _ccf("p_graze", 0.15)
	var mult_graze: float = _ccf("mult_graze", 0.70)
	if randf() < p_graze:
		dmg = int(ceil(float(dmg) * mult_graze))

	var p_crit: float = _ccf("p_crit", 0.10)
	var mult_crit: float = _ccf("mult_crit", 1.80)
	if randf() < p_crit:
		dmg = int(ceil(float(dmg) * mult_crit))

	return max(1, dmg)

# --- Nuevo: versiones con flags para sincronizar textos (no rompen las existentes) ---
static func compute_avatar_hit_detail(attacker: Dictionary, defender: Dictionary, action_type: String) -> Dictionary:
	var pm := _map_action_to_P_S(action_type, attacker)
	var P: float = float(pm.get("P", 0.0))
	var S: float = float(pm.get("S", 0.0))

	var atk_total: float = GameData.build_offense(attacker, P, S)
	var def_total: float = GameData.build_defense(defender)

	var base := _damage_from_atk_def(atk_total, def_total)

	var flags := { "block": false, "graze": false, "crit": false }
	var dmg := base

	var p_block: float = _ccf("p_block", 0.10)
	var mult_block: float = _ccf("mult_block", 0.50)
	if randf() < p_block:
		flags["block"] = true
		dmg = int(ceil(float(dmg) * mult_block))

	var p_graze: float = _ccf("p_graze", 0.15)
	var mult_graze: float = _ccf("mult_graze", 0.70)
	if randf() < p_graze:
		flags["graze"] = true
		dmg = int(ceil(float(dmg) * mult_graze))

	var p_crit: float = _ccf("p_crit", 0.10)
	var mult_crit: float = _ccf("mult_crit", 1.80)
	if randf() < p_crit:
		flags["crit"] = true
		dmg = int(ceil(float(dmg) * mult_crit))

	return {
		"dmg": max(1, dmg),
		"flags": flags,
		"atk": atk_total,
		"def": def_total
	}

static func compute_enemy_hit_detail(attacker: Dictionary, defender: Dictionary, action_type: String = "MELEE") -> Dictionary:
	var pm := _map_action_to_P_S(action_type, attacker)
	var P: float = float(pm.get("P", 0.0))
	var S: float = float(pm.get("S", 0.0))

	var atk_total: float = GameData.build_offense(attacker, P, S)
	var def_total: float = GameData.build_defense(defender)

	var base := _damage_from_atk_def(atk_total, def_total)

	var flags := { "block": false, "graze": false, "crit": false }
	var dmg := base

	var p_block: float = _ccf("p_block", 0.10)
	var mult_block: float = _ccf("mult_block", 0.50)
	if randf() < p_block:
		flags["block"] = true
		dmg = int(ceil(float(dmg) * mult_block))

	var p_graze: float = _ccf("p_graze", 0.15)
	var mult_graze: float = _ccf("mult_graze", 0.70)
	if randf() < p_graze:
		flags["graze"] = true
		dmg = int(ceil(float(dmg) * mult_graze))

	var p_crit: float = _ccf("p_crit", 0.10)
	var mult_crit: float = _ccf("mult_crit", 1.80)
	if randf() < p_crit:
		flags["crit"] = true
		dmg = int(ceil(float(dmg) * mult_crit))

	return {
		"dmg": max(1, dmg),
		"flags": flags,
		"atk": atk_total,
		"def": def_total
	}
