extends Node
class_name Combat

# --- Constantes de balance (fáciles de tunear) ---
const HIT_BASE: float = 0.60				# base de pegar
const HIT_PER_LEVEL: float = 0.05			# modificador por diferencia de nivel (att - def)
const DODGE_ENEMY_DEFAULT: float = 0.05		# evasión base de enemigo
const CRIT_CHANCE: float = 0.10
const CRIT_MULT: float = 1.5

# Nivel “oculto” del avatar (por ahora 1; ajusta si ya lo guardás en GameData.avatar.level)
static func get_avatar_level() -> int:
	return int(GameData.avatar.get("level", 1))

# Nivel “oculto” del enemigo (si no está en CSV, 1)
static func get_enemy_level(def: Dictionary) -> int:
	return int(def.get("level", 1))

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
