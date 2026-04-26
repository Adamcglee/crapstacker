extends Node2D
class_name Truck

# Dimensions — set these before add_child() so _ready() picks up upgrade values
var bed_width:    float = 308.0
var bed_depth:    float = 8.0
var floor_thick:  float = 18.0
var wall_thick:   float = 14.0
var cab_width:    float = 59.0
var cab_height:   float = 105.0
var wheel_r:      float = 26.0
var bed_friction: float = 4.0

var _lwall_vis: ColorRect
var _rwall_vis: ColorRect

func _ready() -> void:
	_build_visuals()
	_build_physics()

# ── Visuals ──────────────────────────────────────────────────────────────────

func _build_visuals() -> void:
	var bed_bg := ColorRect.new()
	bed_bg.color = Color(0.22, 0.18, 0.13)
	bed_bg.size = Vector2(bed_width, bed_depth)
	bed_bg.position = Vector2(-bed_width / 2.0, -bed_depth)
	add_child(bed_bg)

	var cab := ColorRect.new()
	cab.color = Color(0.28, 0.48, 0.78)
	cab.size = Vector2(cab_width, cab_height)
	cab.position = Vector2(-bed_width / 2.0 - cab_width, -cab_height + floor_thick)
	add_child(cab)

	var win := ColorRect.new()
	win.color = Color(0.55, 0.78, 1.0, 0.75)
	win.size = Vector2(cab_width * 0.55, cab_height * 0.38)
	win.position = Vector2(-bed_width / 2.0 - cab_width + cab_width * 0.18,
		-cab_height + floor_thick + 12.0)
	add_child(win)

	var floor_vis := ColorRect.new()
	floor_vis.color = Color(0.30, 0.24, 0.16)
	floor_vis.size = Vector2(bed_width + wall_thick, floor_thick)
	floor_vis.position = Vector2(-bed_width / 2.0, 0.0)
	add_child(floor_vis)

	_lwall_vis = ColorRect.new()
	_lwall_vis.color = Color(0.34, 0.27, 0.18)
	_lwall_vis.size = Vector2(wall_thick, bed_depth + floor_thick)
	_lwall_vis.position = Vector2(-bed_width / 2.0 - wall_thick, -bed_depth)
	add_child(_lwall_vis)

	var chassis := ColorRect.new()
	chassis.color = Color(0.20, 0.20, 0.22)
	chassis.size = Vector2(bed_width + cab_width, 14.0)
	chassis.position = Vector2(-bed_width / 2.0 - cab_width, floor_thick)
	add_child(chassis)

	_make_wheel(-bed_width / 2.0 + 50.0)
	_make_wheel(bed_width / 2.0 - 50.0)

func _make_wheel(cx: float) -> void:
	var wheel := ColorRect.new()
	wheel.color = Color(0.12, 0.12, 0.12)
	wheel.size = Vector2(wheel_r * 2.0, wheel_r * 2.0)
	wheel.position = Vector2(cx - wheel_r, floor_thick)
	add_child(wheel)

	var hub := ColorRect.new()
	hub.color = Color(0.55, 0.55, 0.55)
	hub.size = Vector2(wheel_r * 0.55, wheel_r * 0.55)
	hub.position = Vector2(cx - wheel_r * 0.275, floor_thick + wheel_r * 0.725)
	add_child(hub)

# ── Physics ──────────────────────────────────────────────────────────────────

func _build_physics() -> void:
	var mat := PhysicsMaterial.new()
	mat.friction = bed_friction
	mat.rough    = true
	mat.bounce   = 0.0

	var floor_body := StaticBody2D.new()
	floor_body.collision_layer = 1
	floor_body.collision_mask  = 0
	floor_body.physics_material_override = mat
	var fs := RectangleShape2D.new()
	fs.size = Vector2(bed_width + wall_thick * 2.0, floor_thick)
	var fc := CollisionShape2D.new()
	fc.shape = fs
	floor_body.add_child(fc)
	floor_body.position = Vector2(0.0, floor_thick / 2.0)
	add_child(floor_body)

	var lwall := StaticBody2D.new()
	lwall.collision_layer = 1
	lwall.collision_mask  = 0
	lwall.physics_material_override = mat
	var lws := RectangleShape2D.new()
	lws.size = Vector2(wall_thick, bed_depth + floor_thick)
	var lwc := CollisionShape2D.new()
	lwc.shape = lws
	lwall.add_child(lwc)
	lwall.position = Vector2(
		-bed_width / 2.0 - wall_thick / 2.0,
		(-bed_depth + floor_thick) / 2.0
	)
	add_child(lwall)

	add_right_wall()
	_add_cab_wall()

func add_right_wall() -> void:
	if get_node_or_null("RightWall"):
		return
	var rwall := StaticBody2D.new()
	rwall.name = "RightWall"
	rwall.collision_layer = 1
	rwall.collision_mask  = 0
	var rws := RectangleShape2D.new()
	rws.size = Vector2(wall_thick, bed_depth + floor_thick)
	var rwc := CollisionShape2D.new()
	rwc.shape = rws
	rwall.add_child(rwc)
	rwall.position = Vector2(
		bed_width / 2.0 + wall_thick / 2.0,
		(-bed_depth + floor_thick) / 2.0
	)

	_rwall_vis = ColorRect.new()
	_rwall_vis.color = Color(0.34, 0.27, 0.18)
	_rwall_vis.size = Vector2(wall_thick, bed_depth + floor_thick)
	_rwall_vis.position = Vector2(bed_width / 2.0, -bed_depth)
	add_child(_rwall_vis)

	add_child(rwall)

func _add_cab_wall() -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask  = 0
	var s := RectangleShape2D.new()
	# Full cab box so items can land on the roof and can't pass through the side
	s.size = Vector2(cab_width, cab_height)
	var c := CollisionShape2D.new()
	c.shape = s
	body.add_child(c)
	# Center matches the cab visual: top-left corner is (-bed_width/2 - cab_width, -cab_height + floor_thick)
	body.position = Vector2(
		-bed_width / 2.0 - cab_width / 2.0,
		floor_thick - cab_height / 2.0
	)
	add_child(body)

func set_rail_opacity(alpha: float) -> void:
	if _lwall_vis:
		_lwall_vis.modulate.a = alpha
	if _rwall_vis:
		_rwall_vis.modulate.a = alpha
