extends Node2D

const TruckScript     := preload("res://scripts/Truck.gd")
const SpawnerScript   := preload("res://scripts/ItemSpawner.gd")

const VP_W := 720.0
const VP_H := 1280.0

# Truck bed floor sits at this world Y. Items stack upward from here.
const TRUCK_Y := 920.0

# Staging slots — top of screen so items drop down onto the truck
const STAGE_POS   := Vector2(VP_W * 0.25, VP_H * 0.18)
const PREVIEW_POS := Vector2(VP_W * 0.75, VP_H * 0.18)

var truck: Truck
var spawner: ItemSpawner
var _item_container: Node2D

# HUD refs
var _money_label: Label
var _items_label: Label
var _phase_label: Label
var _go_button: Button
var _begin_button: Button
var _restart_button: Button
var _next_level_button: Button
var _shop_button: Button
var _upgrade_menu: UpgradeMenu
var _progress_bg: ColorRect
var _progress_fill: ColorRect
var _progress_label: Label
var _perfect_delivery: bool = false
var _fallen_count: int = 0
var _delivery_pct_label: Label

# Camera
var _camera: Camera2D

# Phase 2 travel state
var _is_travelling: bool = false
var _travel_elapsed: float = 0.0
var _travel_start_x: float = 0.0
var _camera_target: Vector2
var _truck_velocity: float = 0.0
const TRAVEL_DURATION := 14.0   # seconds to reach destination
const TRAVEL_MAX_SPEED := 180.0 # pixels per second at full throttle
const TRAVEL_ACCEL     := 55.0  # pixels per second² — gradual ramp avoids instant impulse
const CARRY_SPRING     := 3.0   # spring stiffness pulling items toward truck speed

func _ready() -> void:
	_build_world()
	_build_hud()
	_connect_signals()
	_on_money_changed(GameManager.money)  # sync label to persisted value on reload
	GameManager.start_level(GameManager.level)  # resume at persisted level

# ── World setup ───────────────────────────────────────────────────────────────

func _build_world() -> void:
	# Sky background — wide enough to cover the full travel path
	var sky := ColorRect.new()
	sky.color = Color(0.53, 0.80, 0.95)
	sky.size = Vector2(9000.0, VP_H)
	sky.position = Vector2(-500.0, 0.0)
	sky.z_index = -10
	add_child(sky)

	# Ground strip — extends across the full road
	var ground := ColorRect.new()
	ground.color = Color(0.38, 0.62, 0.28)
	ground.size = Vector2(9000.0, 80.0)
	ground.position = Vector2(-500.0, TRUCK_Y + 58.0)
	ground.z_index = -5
	add_child(ground)

	# Road surface
	var road := ColorRect.new()
	road.color = Color(0.30, 0.30, 0.32)
	road.size = Vector2(9000.0, 18.0)
	road.position = Vector2(-500.0, TRUCK_Y + 56.0)
	road.z_index = -4
	add_child(road)

	# Item physics container
	_item_container = Node2D.new()
	_item_container.name = "ItemContainer"
	add_child(_item_container)

	# Truck — dimensions boosted by any active upgrades
	truck = TruckScript.new()
	truck.bed_width    = 308.0 + UpgradeManager.bed_width_bonus()
	truck.bed_depth    = 8.0   + UpgradeManager.rail_height_bonus()
	truck.bed_friction = UpgradeManager.floor_friction()
	truck.position = Vector2(VP_W / 2.0, TRUCK_Y)
	truck.scale.x = -1.0
	add_child(truck)

	# Camera — starts centred on Phase 1 layout, follows truck in Phase 2
	_camera = Camera2D.new()
	_camera.position = Vector2(VP_W / 2.0, VP_H / 2.0)
	add_child(_camera)

	# More solver iterations so multiple items pressed against each other
	# fully resolve contacts each physics step instead of squishing together.
	PhysicsServer2D.space_set_param(
		get_world_2d().space,
		PhysicsServer2D.SPACE_PARAM_SOLVER_ITERATIONS,
		16
	)

	# Staging area visuals
	_draw_slot(STAGE_POS, "LOAD THIS ITEM", Color(0.15, 0.55, 0.15, 0.35))
	_draw_slot(PREVIEW_POS, "NEXT UP", Color(0.15, 0.15, 0.55, 0.25))

	# Item spawner
	spawner = SpawnerScript.new()
	add_child(spawner)
	spawner.setup(_item_container, STAGE_POS, PREVIEW_POS)
	spawner.queue_empty.connect(_on_queue_empty)

	# Physics ground — wide enough to catch falls across the full travel path
	var phys_ground := StaticBody2D.new()
	phys_ground.collision_layer = 1
	phys_ground.collision_mask = 0
	var pg_shape := RectangleShape2D.new()
	pg_shape.size = Vector2(9000.0, 20.0)
	var pg_col := CollisionShape2D.new()
	pg_col.shape = pg_shape
	phys_ground.add_child(pg_col)
	phys_ground.position = Vector2(4000.0, TRUCK_Y + 66.0)
	add_child(phys_ground)

	# Fall detector — covers the full road width
	var fall_zone := Area2D.new()
	fall_zone.collision_layer = 0
	fall_zone.collision_mask = 2
	var fz_shape := RectangleShape2D.new()
	fz_shape.size = Vector2(9000.0, 40.0)
	var fz_col := CollisionShape2D.new()
	fz_col.shape = fz_shape
	fall_zone.add_child(fz_col)
	fall_zone.position = Vector2(4000.0, TRUCK_Y + 66.0)
	fall_zone.body_entered.connect(_on_item_hit_ground)
	add_child(fall_zone)

func _draw_slot(center: Vector2, label_text: String, bg_color: Color) -> void:
	var slot_size := Vector2(160.0, 110.0)

	var bg := ColorRect.new()
	bg.color = bg_color
	bg.size = slot_size
	bg.position = center - slot_size / 2.0
	add_child(bg)

	var outline_top    := _thin_rect(Color(1,1,1,0.4), Vector2(slot_size.x, 2), center - slot_size / 2.0)
	var outline_bottom := _thin_rect(Color(1,1,1,0.4), Vector2(slot_size.x, 2), center + Vector2(-slot_size.x/2.0, slot_size.y/2.0 - 2))
	var outline_left   := _thin_rect(Color(1,1,1,0.4), Vector2(2, slot_size.y), center - slot_size / 2.0)
	var outline_right  := _thin_rect(Color(1,1,1,0.4), Vector2(2, slot_size.y), center + Vector2(slot_size.x/2.0 - 2, -slot_size.y/2.0))
	add_child(outline_top); add_child(outline_bottom)
	add_child(outline_left); add_child(outline_right)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.size = Vector2(slot_size.x, 20.0)
	lbl.position = center + Vector2(-slot_size.x / 2.0, slot_size.y / 2.0 + 4.0)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	add_child(lbl)

func _thin_rect(color: Color, sz: Vector2, pos: Vector2) -> ColorRect:
	var r := ColorRect.new()
	r.color = color
	r.size = sz
	r.position = pos
	return r

# ── HUD ───────────────────────────────────────────────────────────────────────

func _build_hud() -> void:
	var hud := CanvasLayer.new()
	hud.name = "HUD"
	add_child(hud)

	var bar := ColorRect.new()
	bar.color = Color(0.08, 0.08, 0.08, 0.70)
	bar.size = Vector2(VP_W, 44.0)
	hud.add_child(bar)

	_money_label = _hud_label("Earnings:  $0", Vector2(16.0, 10.0))
	hud.add_child(_money_label)

	_items_label = _hud_label("Items: 0 / 0", Vector2(VP_W / 2.0 - 70.0, 10.0))
	hud.add_child(_items_label)

	_phase_label = _hud_label("Loading...", Vector2(VP_W - 180.0, 10.0))
	hud.add_child(_phase_label)

	_begin_button = Button.new()
	_begin_button.text = "Load Up!"
	_begin_button.size = Vector2(200.0, 60.0)
	_begin_button.position = Vector2(VP_W / 2.0 - 100.0, VP_H / 2.0 - 30.0)
	_begin_button.visible = false
	_begin_button.pressed.connect(_on_begin_pressed)
	hud.add_child(_begin_button)

	_go_button = Button.new()
	_go_button.text = "Get Moving!"
	_go_button.size = Vector2(200.0, 60.0)
	_go_button.position = Vector2(VP_W / 2.0 - 100.0, VP_H / 2.0 - 30.0)
	_go_button.visible = false
	_go_button.pressed.connect(_on_go_pressed)
	hud.add_child(_go_button)

	_next_level_button = Button.new()
	_next_level_button.text = "Next Level"
	_next_level_button.size = Vector2(200.0, 60.0)
	_next_level_button.position = Vector2(VP_W / 2.0 - 100.0, VP_H / 2.0 - 40.0)
	_next_level_button.visible = false
	_next_level_button.pressed.connect(_on_next_level_pressed)
	hud.add_child(_next_level_button)

	_restart_button = Button.new()
	_restart_button.text = "Play Again"
	_restart_button.size = Vector2(200.0, 60.0)
	_restart_button.position = Vector2(VP_W / 2.0 - 100.0, VP_H / 2.0 + 40.0)
	_restart_button.visible = false
	_restart_button.pressed.connect(_on_restart_pressed)
	hud.add_child(_restart_button)

	_shop_button = Button.new()
	_shop_button.text = "Upgrades"
	_shop_button.size = Vector2(120.0, 52.0)
	_shop_button.position = Vector2(VP_W - 130.0, VP_H - 68.0)
	_shop_button.visible = true
	_shop_button.pressed.connect(_on_shop_pressed)
	hud.add_child(_shop_button)

	var UpgradeMenuScript := preload("res://scripts/UpgradeMenu.gd")
	_upgrade_menu = UpgradeMenuScript.new()
	_upgrade_menu.visible = false
	_upgrade_menu.closed.connect(_on_upgrade_menu_closed)
	hud.add_child(_upgrade_menu)

	# ── Delivery progress bar (shown during Phase 2 only) ────────────────────
	var prog_bar_w := VP_W - 32.0
	_delivery_pct_label = Label.new()
	_delivery_pct_label.text = "On Truck: 100%"
	_delivery_pct_label.size = Vector2(VP_W, 36.0)
	_delivery_pct_label.position = Vector2(0.0, 52.0)
	_delivery_pct_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_delivery_pct_label.add_theme_font_size_override("font_size", 22)
	_delivery_pct_label.add_theme_color_override("font_color", Color(0.25, 0.90, 0.35))
	_delivery_pct_label.visible = false
	hud.add_child(_delivery_pct_label)

	_progress_label = Label.new()
	_progress_label.text = "Destination"
	_progress_label.size = Vector2(prog_bar_w, 20.0)
	_progress_label.position = Vector2(16.0, VP_H - 76.0)
	_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_progress_label.add_theme_font_size_override("font_size", 13)
	_progress_label.add_theme_color_override("font_color", Color.WHITE)
	_progress_label.visible = false
	hud.add_child(_progress_label)

	_progress_bg = ColorRect.new()
	_progress_bg.color = Color(0.12, 0.12, 0.12, 0.9)
	_progress_bg.size = Vector2(prog_bar_w, 26.0)
	_progress_bg.position = Vector2(16.0, VP_H - 52.0)
	_progress_bg.visible = false
	hud.add_child(_progress_bg)

	_progress_fill = ColorRect.new()
	_progress_fill.color = Color(0.22, 0.78, 0.35)
	_progress_fill.size = Vector2(0.0, 22.0)
	_progress_fill.position = Vector2(18.0, VP_H - 50.0)
	_progress_fill.visible = false
	hud.add_child(_progress_fill)

func _hud_label(text: String, pos: Vector2) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.position = pos
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	return lbl

# ── Signal handlers ───────────────────────────────────────────────────────────

func _connect_signals() -> void:
	GameManager.phase_changed.connect(_on_phase_changed)
	GameManager.money_changed.connect(_on_money_changed)
	GameManager.items_count_changed.connect(_on_items_count_changed)
	GameManager.all_items_loaded.connect(_on_all_items_loaded)
	GameManager.item_fell_off.connect(_on_item_fell_off_hud)
	UpgradeManager.upgraded.connect(_on_upgrade_purchased)

func _on_phase_changed(phase: int) -> void:
	match phase:
		GameManager.GamePhase.MENU:
			_perfect_delivery = false
			_phase_label.text = "Lvl %d — Ready?" % GameManager.level
			_items_label.text = "Items: 0 / %d" % GameManager.total_items
			_shop_button.visible = true
			_begin_button.visible = true
		GameManager.GamePhase.LOADING:
			_phase_label.text = "Lvl %d" % GameManager.level
			_items_label.text = "Items: 0 / %d" % GameManager.total_items
			_shop_button.visible = false
			_begin_button.visible = false
			var queue := ItemDatabase.build_level_queue(
				GameManager.level, GameManager.total_items
			)
			spawner.load_queue(queue)
			spawner.spawn_next()
		GameManager.GamePhase.TRAVEL:
			_phase_label.text = "Lvl %d — Driving!" % GameManager.level
			_shop_button.visible = false
		GameManager.GamePhase.RESULTS:
			_phase_label.text = "Lvl %d — Delivered!" % GameManager.level
			_shop_button.visible = true
			_next_level_button.visible = _perfect_delivery
			_restart_button.visible = true

func _on_money_changed(amount: float) -> void:
	_money_label.text = "Earnings:  $%.0f" % amount

func _on_items_count_changed(placed: int, total: int) -> void:
	_items_label.text = "Items: %d / %d" % [placed, total]

func _on_all_items_loaded() -> void:
	_phase_label.text = "All loaded!"
	_go_button.visible = true

func _on_begin_pressed() -> void:
	_begin_button.visible = false
	_shop_button.visible = false
	GameManager.begin_loading()

func _on_go_pressed() -> void:
	_go_button.visible = false
	_begin_travel()

func _on_upgrade_purchased(_type: int, _level: int) -> void:
	_rebuild_truck()

func _rebuild_truck() -> void:
	var pos := truck.position
	truck.queue_free()
	truck = TruckScript.new()
	truck.bed_width    = 308.0 + UpgradeManager.bed_width_bonus()
	truck.bed_depth    = 8.0   + UpgradeManager.rail_height_bonus()
	truck.bed_friction = UpgradeManager.floor_friction()
	truck.position = pos
	truck.scale.x = -1.0
	add_child(truck)

func _on_shop_pressed() -> void:
	_shop_button.visible = false
	_begin_button.visible = false
	_next_level_button.visible = false
	_restart_button.visible = false
	_upgrade_menu.visible = true

func _on_upgrade_menu_closed() -> void:
	_upgrade_menu.visible = false
	_shop_button.visible = true
	var in_menu    := GameManager.current_phase == GameManager.GamePhase.MENU
	var in_results := GameManager.current_phase == GameManager.GamePhase.RESULTS
	_begin_button.visible      = in_menu
	_next_level_button.visible = in_results and _perfect_delivery
	_restart_button.visible    = in_results

func _on_next_level_pressed() -> void:
	GameManager.level += 1
	get_tree().reload_current_scene()

func _on_restart_pressed() -> void:
	get_tree().reload_current_scene()

func _begin_travel() -> void:
	_travel_start_x = truck.position.x
	_travel_elapsed = 0.0
	_truck_velocity = 0.0
	_is_travelling = true
	_fallen_count = 0
	_progress_bg.visible = true
	_progress_fill.visible = true
	_progress_label.visible = true
	_progress_fill.size.x = 0.0
	_delivery_pct_label.text = "On Truck: 100%"
	_delivery_pct_label.add_theme_color_override("font_color", Color(0.25, 0.90, 0.35))
	_delivery_pct_label.visible = true

	# Lock rotation on every placed item so they stay flat on the bed.
	# Items can still slide and fall off — just no spinning.
	for child in _item_container.get_children():
		if child is HouseholdItem:
			var item := child as HouseholdItem
			if item.state == HouseholdItem.State.PLACED:
				item.lock_rotation = true

	GameManager.set_phase(GameManager.GamePhase.TRAVEL)

# Truck movement runs in _physics_process so AnimatableBody2D velocity is
# computed correctly each physics step, enabling proper friction on items.
func _physics_process(delta: float) -> void:
	if not _is_travelling:
		return

	_travel_elapsed += delta

	if _travel_elapsed >= TRAVEL_DURATION:
		_is_travelling = false
		truck.position.y = TRUCK_Y
		_on_arrived()
		return

	# Ramp up to full speed — avoids the instant velocity spike that caused
	# AnimatableBody2D to blast items off the truck on the first frame.
	var scaled_max := TRAVEL_MAX_SPEED * GameManager.level_speed_scale()
	_truck_velocity = minf(_truck_velocity + TRAVEL_ACCEL * delta, scaled_max)

	# Amplitude scales up with level; Suspension upgrade pushes it back down
	var bump := (sin(_travel_elapsed * 4.2) * 4.0
			  + sin(_travel_elapsed * 11.0) * 2.0
			  + sin(_travel_elapsed * 1.8) * 7.0) \
			  * GameManager.level_bump_scale() \
			  * UpgradeManager.bump_multiplier()

	truck.position.x += _truck_velocity * delta
	truck.position.y  = TRUCK_Y + bump
	_camera_target = Vector2(truck.global_position.x, VP_H / 2.0 + bump * 0.3)

	# Spring force: pull each placed item toward the truck's horizontal speed.
	# Soft force (not a hard constraint) so items slide naturally under inertia
	# and the solver never has to resolve simultaneous rigid impacts between them.
	for child in _item_container.get_children():
		if child is HouseholdItem:
			var item := child as HouseholdItem
			if item.state == HouseholdItem.State.PLACED:
				var vel_diff := _truck_velocity - item.linear_velocity.x
				item.apply_central_force(
					Vector2(vel_diff * CARRY_SPRING * item.mass, 0.0)
				)

# Camera lerp stays in _process for smooth visuals at display framerate.
func _process(delta: float) -> void:
	if is_instance_valid(truck):
		var has_placed := false
		for child in _item_container.get_children():
			if child is HouseholdItem and (child as HouseholdItem).state == HouseholdItem.State.PLACED:
				has_placed = true
				break
		truck.set_rail_opacity(0.25 if has_placed else 1.0)

	if not _is_travelling:
		return
	_camera.global_position = _camera.global_position.lerp(_camera_target, delta * 8.0)
	var progress := clampf(_travel_elapsed / TRAVEL_DURATION, 0.0, 1.0)
	_progress_fill.size.x = progress * (_progress_bg.size.x - 4.0)

func _on_arrived() -> void:
	_progress_bg.visible = false
	_progress_fill.visible = false
	_progress_label.visible = false
	_delivery_pct_label.visible = false

	# Count surviving items and tally earnings
	var earned := 0.0
	var delivered := 0
	for child in _item_container.get_children():
		if child is HouseholdItem:
			var item := child as HouseholdItem
			if item.state == HouseholdItem.State.PLACED:
				earned += item.value
				delivered += 1

	_perfect_delivery = (delivered == GameManager.total_items)
	GameManager.add_earnings(earned)

	_camera.global_position.y = VP_H / 2.0
	GameManager.set_phase(GameManager.GamePhase.RESULTS)

func _on_item_hit_ground(body: Node2D) -> void:
	if not (body is HouseholdItem):
		return
	var item := body as HouseholdItem
	if item.state == HouseholdItem.State.FALLEN:
		return
	_spawn_explosion(item.global_position, item.item_color, item._half_size * 2.0)
	item.mark_fallen()

func _spawn_explosion(world_pos: Vector2, color: Color, item_size: Vector2) -> void:
	for i in 8:
		var piece := RigidBody2D.new()
		piece.collision_layer = 1
		piece.collision_mask  = 1

		var ps := randf_range(5.0, 13.0)
		var shape := RectangleShape2D.new()
		shape.size = Vector2(ps, ps)
		var col := CollisionShape2D.new()
		col.shape = shape
		piece.add_child(col)

		var mat := PhysicsMaterial.new()
		mat.bounce   = 0.45
		mat.friction = 0.5
		piece.physics_material_override = mat

		var vis := ColorRect.new()
		vis.color = color
		vis.size = Vector2(ps, ps)
		vis.position = Vector2(-ps * 0.5, -ps * 0.5)
		piece.add_child(vis)

		piece.position = world_pos + Vector2(
			randf_range(-item_size.x * 0.3, item_size.x * 0.3),
			randf_range(-item_size.y * 0.3, 0.0)
		)
		add_child(piece)

		# Fan upward in a -150° to -30° arc (screen-up is negative Y)
		var angle := randf_range(deg_to_rad(-150.0), deg_to_rad(-30.0))
		var speed := randf_range(150.0, 420.0)
		piece.linear_velocity = Vector2(cos(angle) * speed, sin(angle) * speed)
		piece.angular_velocity = randf_range(-14.0, 14.0)

		var tween := create_tween()
		tween.tween_interval(0.8)
		tween.tween_property(piece, "modulate:a", 0.0, 0.55)
		tween.tween_callback(piece.queue_free)

func _on_item_fell_off_hud(_item_name: String, _value: float) -> void:
	if not _is_travelling:
		return
	_fallen_count += 1
	var total := GameManager.total_items
	if total == 0:
		return
	var pct := int(float(total - _fallen_count) / float(total) * 100.0)
	pct = maxi(pct, 0)
	_delivery_pct_label.text = "On Truck: %d%%" % pct
	if pct == 100:
		_delivery_pct_label.add_theme_color_override("font_color", Color(0.25, 0.90, 0.35))
	elif pct >= 50:
		_delivery_pct_label.add_theme_color_override("font_color", Color(0.95, 0.80, 0.10))
	else:
		_delivery_pct_label.add_theme_color_override("font_color", Color(0.95, 0.25, 0.25))

func _on_queue_empty() -> void:
	pass
