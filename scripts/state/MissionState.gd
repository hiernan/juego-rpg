extends RefCounted

class_name MissionState

const SEARCH_DOTS_MARKER := "[DO_SEARCH_DOTS]"
const INLINE_PREFIX := "[INLINE]"

var events: Array[Dictionary] = []
var waiting_dots: bool = false
var line_queue: Array = []
var next_delay: float = 1.5
var dots_plan: Dictionary = {}
var dots_remaining: int = 0
var result_bag: Array = []
var current_enemy: Dictionary = {
	"id": "",
	"name": "",
	"hp": 0,
	"hp_max": 0,
	"dmg_min": 0,
	"dmg_max": 0,
	"gold_min": 0,
	"gold_max": 0,
	"xp": 0,
	"evasion": 0.05,
	"level": 1,
}


func set_events(event_list: Array) -> void:
	events.clear()
	for event_entry in event_list:
		events.append(event_entry)


func has_pending_events() -> bool:
	return not events.is_empty()


func pop_event() -> Dictionary:
	if events.is_empty():
		return {}
	return events.pop_front() as Dictionary


func enqueue_lines(lines: Array, delay_sec: float = 0.9) -> void:
	for line in lines:
		line_queue.append(line)
	next_delay = delay_sec


func enqueue_node(node: Variant) -> void:
	line_queue.append(node)


func has_pending_lines() -> bool:
	return not line_queue.is_empty()


func pop_line() -> Variant:
	if line_queue.is_empty():
		return null
	return line_queue.pop_front()


func prepare_search_room(ev: Dictionary, avatar_line: String, min_dots: int = 5, max_dots: int = 10) -> void:
	enqueue_node(INLINE_PREFIX + avatar_line)
	dots_plan = {"min": min_dots, "max": max_dots, "ev": ev}
	enqueue_node(SEARCH_DOTS_MARKER)


func start_search_dots() -> void:
	waiting_dots = true
	var min_dots: int = int(dots_plan.get("min", 5))
	var max_dots: int = int(dots_plan.get("max", 10))
	dots_remaining = randi_range(min_dots, max_dots)


func consume_search_dot() -> bool:
	if dots_remaining <= 0:
		return false
	dots_remaining -= 1
	return true


func finish_search_dots() -> Dictionary:
	enqueue_node(INLINE_PREFIX + "\n")
	waiting_dots = false
	dots_remaining = 0
	var ev: Dictionary = dots_plan.get("ev", {})
	dots_plan = {}
	return ev


func set_result_bag(bag: Array) -> void:
	result_bag = bag.duplicate()


func clear_result_bag() -> void:
	result_bag = []


func set_current_enemy(enemy_data: Dictionary) -> void:
	current_enemy = enemy_data.duplicate()


func clear_current_enemy() -> void:
	current_enemy = {
		"id": "",
		"name": "",
		"hp": 0,
		"hp_max": 0,
		"dmg_min": 0,
		"dmg_max": 0,
		"gold_min": 0,
		"gold_max": 0,
		"xp": 0,
		"evasion": 0.05,
		"level": 1,
	}
