extends RigidBody2D
class_name HouseholdItem

enum State { STAGED, HELD, PLACED, FALLEN }

signal placed(item: HouseholdItem)
signal fell(item: HouseholdItem)

var item_id: String = ""
var display_name: String = ""
var value: float = 0.0
var state: State = State.STAGED
var interactive: bool = true

var _half_size: Vector2 = Vector2.ZERO
var _drag_touch: int = -1
var _rotate_touch: int = -1
var _drag_offset: Vector2 = Vector2.ZERO
var _rotate_ref_x: float = 0.0
var _rotate_start_angle: float = 0.0

func setup(def) -> void:
	item_id = def.id
	display_name = def.display_name
	value = def.value
	mass = def.mass
	_half_size = def.size / 2.0

	var rect := RectangleShape2D.new()
	rect.size = def.size
	var col := CollisionShape2D.new()
	col.shape = rect
	add_child(col)

	# Zero bounce so item-to-item contacts are inelastic — no springy rebound
	# that fights the solver and causes visible compression.
	var item_mat := PhysicsMaterial.new()
	item_mat.friction = 0.8
	item_mat.rough    = true
	item_mat.bounce   = 0.0
	physics_material_override = item_mat

	# Dark border behind the color fill
	var border := ColorRect.new()
	border.color = Color(0.0, 0.0, 0.0, 0.55)
	border.size = def.size + Vector2(4, 4)
	border.position = -_half_size - Vector2(2, 2)
	add_child(border)

	var bg := ColorRect.new()
	bg.color = def.color
	bg.size = def.size
	bg.position = -_half_size
	add_child(bg)

	var lbl := Label.new()
	lbl.text = def.display_name
	lbl.size = def.size
	lbl.position = -_half_size
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 9)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	add_child(lbl)

	_enter_staged()

# ── State transitions ───────────────────────────────────────────────────────

func _enter_staged() -> void:
	state = State.STAGED
	freeze = true
	freeze_mode = RigidBody2D.FREEZE_MODE_STATIC
	gravity_scale = 0.0
	collision_layer = 0
	collision_mask = 0

func _enter_held(touch_id: int, world_pos: Vector2) -> void:
	state = State.HELD
	_drag_touch = touch_id
	_drag_offset = global_position - world_pos
	freeze = true
	freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
	gravity_scale = 0.0
	# Layer 4 so held item can nudge placed items (layer 2) and interact with truck (layer 1)
	collision_layer = 4
	collision_mask = 3
	z_index = 10

func _enter_placed() -> void:
	state = State.PLACED
	_drag_touch = -1
	_rotate_touch = -1
	freeze = false
	gravity_scale = 1.0
	collision_layer = 2
	collision_mask = 3
	z_index = 0
	placed.emit(self)

func mark_fallen() -> void:
	if state == State.FALLEN:
		return
	state = State.FALLEN
	_drag_touch = -1
	_rotate_touch = -1
	# Freeze in place so item stays visible on the road, red
	freeze = true
	freeze_mode = RigidBody2D.FREEZE_MODE_STATIC
	collision_layer = 0
	collision_mask = 0
	modulate = Color(1.0, 0.3, 0.3, 0.85)
	fell.emit(self)

# ── Input ───────────────────────────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	if not interactive or state == State.FALLEN:
		return

	if event is InputEventScreenTouch:
		_handle_touch(event as InputEventScreenTouch)
	elif event is InputEventScreenDrag:
		_handle_drag(event as InputEventScreenDrag)

func _handle_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		if state == State.STAGED and _drag_touch == -1:
			var wp := _to_world(event.position)
			if _contains(wp):
				_enter_held(event.index, wp)
				get_viewport().set_input_as_handled()
		elif state == State.HELD and _rotate_touch == -1 and event.index != _drag_touch:
			_rotate_touch = event.index
			_rotate_ref_x = event.position.x
			_rotate_start_angle = rotation
			get_viewport().set_input_as_handled()
	else:
		if state == State.HELD and event.index == _drag_touch:
			_enter_placed()
			get_viewport().set_input_as_handled()
		elif event.index == _rotate_touch:
			_rotate_touch = -1
			get_viewport().set_input_as_handled()

func _handle_drag(event: InputEventScreenDrag) -> void:
	if state != State.HELD:
		return
	if event.index == _drag_touch:
		global_position = _to_world(event.position) + _drag_offset
		get_viewport().set_input_as_handled()
	elif event.index == _rotate_touch:
		rotation = _rotate_start_angle + (event.position.x - _rotate_ref_x) * 0.018
		get_viewport().set_input_as_handled()

# ── Helpers ──────────────────────────────────────────────────────────────────

func _to_world(screen_pos: Vector2) -> Vector2:
	return get_viewport().canvas_transform.affine_inverse() * screen_pos

func _contains(world_pos: Vector2) -> bool:
	var local := to_local(world_pos)
	return abs(local.x) <= _half_size.x and abs(local.y) <= _half_size.y
