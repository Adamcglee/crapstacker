extends Node

enum GamePhase { MENU, LOADING, TRAVEL, RESULTS }

signal phase_changed(phase: GamePhase)
signal money_changed(amount: float)
signal items_count_changed(placed: int, total: int)
signal item_fell_off(item_name: String, lost_value: float)
signal all_items_loaded()

var current_phase: GamePhase = GamePhase.MENU
var money: float = 0.0
var level: int = 1
var total_items: int = 0
var items_placed: int = 0

func start_level(lvl: int) -> void:
	level = lvl
	total_items = _get_item_count(lvl)
	items_placed = 0
	set_phase(GamePhase.MENU)

func begin_loading() -> void:
	set_phase(GamePhase.LOADING)

func set_phase(new_phase: GamePhase) -> void:
	current_phase = new_phase
	phase_changed.emit(new_phase)

func on_item_placed() -> void:
	items_placed += 1
	items_count_changed.emit(items_placed, total_items)
	if items_placed >= total_items:
		all_items_loaded.emit()

func set_starting_money(amount: float) -> void:
	money = amount
	money_changed.emit(money)

func add_earnings(amount: float) -> void:
	money += amount
	money_changed.emit(money)

func on_item_fell(item_name: String, value: float) -> void:
	item_fell_off.emit(item_name, value)

func _get_item_count(lvl: int) -> int:
	return 5 + (lvl - 1) * 2

# ── Level-difficulty accessors ────────────────────────────────────────────────

func level_speed_scale() -> float:
	return 1.0 + (level - 1) * 0.10   # +10 % max speed per level

func level_bump_scale() -> float:
	return 1.0 + (level - 1) * 0.15   # +15 % bump amplitude per level
