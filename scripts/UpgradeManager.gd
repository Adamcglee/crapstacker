extends Node

enum Type { BED_EXTENSION, RAISED_RAILS, SUSPENSION, GRIP_TAPE }

class UpgradeDef:
	var display_name: String
	var description: String
	var max_level: int
	var costs: Array

	func _init(n: String, d: String, ml: int, c: Array) -> void:
		display_name = n
		description  = d
		max_level    = ml
		costs        = c

signal upgraded(type: int, new_level: int)

var _defs:   Dictionary = {}
var _levels: Dictionary = {}

func _ready() -> void:
	_register()
	for t in Type.values():
		_levels[t] = 0

func _register() -> void:
	_defs[Type.BED_EXTENSION] = UpgradeDef.new(
		"Bed Extension",
		"Widens the truck bed, giving more room to stack.",
		3, [300, 1200, 4800]
	)
	_defs[Type.RAISED_RAILS] = UpgradeDef.new(
		"Raised Rails",
		"Taller bed rails help stop items sliding over the sides.",
		3, [200, 800, 3200]
	)
	_defs[Type.SUSPENSION] = UpgradeDef.new(
		"Suspension",
		"Smoother ride. Reduces road-bump intensity each level.",
		3, [350, 1400, 5600]
	)
	_defs[Type.GRIP_TAPE] = UpgradeDef.new(
		"Grip Tape",
		"Non-slip bed liner. Items slide less during delivery.",
		2, [250, 1000]
	)

func get_def(type: int) -> UpgradeDef:
	return _defs.get(type)

func get_level(type: int) -> int:
	return _levels.get(type, 0)

func is_maxed(type: int) -> bool:
	return get_level(type) >= _defs[type].max_level

func get_cost(type: int) -> int:
	if is_maxed(type):
		return 0
	return _defs[type].costs[get_level(type)]

func can_afford(type: int) -> bool:
	return not is_maxed(type) and GameManager.money >= get_cost(type)

func purchase(type: int) -> bool:
	if not can_afford(type):
		return false
	GameManager.money -= get_cost(type)
	GameManager.money_changed.emit(GameManager.money)
	_levels[type] += 1
	upgraded.emit(type, _levels[type])
	return true

# ── Effect accessors ─────────────────────────────────────────────────────────

func bed_width_bonus() -> float:
	return get_level(Type.BED_EXTENSION) * 60.0

func rail_height_bonus() -> float:
	return get_level(Type.RAISED_RAILS) * 16.0

func bump_multiplier() -> float:
	return 1.0 - get_level(Type.SUSPENSION) * 0.25

func floor_friction() -> float:
	return 4.0 + get_level(Type.GRIP_TAPE) * 4.0
