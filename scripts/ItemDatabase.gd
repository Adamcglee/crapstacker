extends Node

class ItemDef:
	var id: String
	var display_name: String
	var value: float
	var mass: float
	var size: Vector2
	var color: Color

	func _init(
		p_id: String, p_name: String, p_value: float,
		p_mass: float, p_size: Vector2, p_color: Color
	) -> void:
		id = p_id
		display_name = p_name
		value = p_value
		mass = p_mass
		size = p_size
		color = p_color

var _items: Dictionary = {}

func _ready() -> void:
	_register_all()

func _register_all() -> void:
	_add("washer",    "Washer",    150.0, 80.0,  Vector2(80,  90),  Color(0.85, 0.85, 0.85))
	_add("fridge",    "Fridge",    200.0, 100.0, Vector2(70,  140), Color(0.90, 0.90, 0.92))
	_add("sofa",      "Sofa",      120.0, 60.0,  Vector2(140, 60),  Color(0.60, 0.40, 0.30))
	_add("suitcase",  "Suitcase",  30.0,  15.0,  Vector2(60,  45),  Color(0.20, 0.20, 0.60))
	_add("box_small", "Box (S)",   20.0,  10.0,  Vector2(40,  40),  Color(0.80, 0.60, 0.20))
	_add("box_large", "Box (L)",   40.0,  20.0,  Vector2(70,  60),  Color(0.75, 0.55, 0.15))
	_add("tv",        "TV",        100.0, 40.0,  Vector2(90,  55),  Color(0.15, 0.15, 0.15))
	_add("lamp",      "Lamp",      25.0,  8.0,   Vector2(20,  100), Color(0.90, 0.85, 0.60))
	_add("chair",     "Chair",     35.0,  15.0,  Vector2(55,  70),  Color(0.50, 0.35, 0.25))
	_add("dresser",   "Dresser",   80.0,  50.0,  Vector2(80,  100), Color(0.60, 0.45, 0.30))

func _add(
	id: String, item_name: String, value: float,
	mass: float, size: Vector2, color: Color
) -> void:
	_items[id] = ItemDef.new(id, item_name, value, mass, size, color)

func get_item(id: String):
	return _items.get(id)

func get_all_ids() -> Array:
	return _items.keys()

func build_level_queue(_level: int, count: int) -> Array[String]:
	var result: Array[String] = []
	var keys: Array = _items.keys()
	for i in count:
		result.append(keys[randi() % keys.size()])
	return result
