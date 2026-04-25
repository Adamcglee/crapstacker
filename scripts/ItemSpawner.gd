extends Node
class_name ItemSpawner

const HouseholdItemScript := preload("res://scripts/HouseholdItem.gd")

signal queue_empty()

var _queue: Array[String] = []
var _current: HouseholdItem = null
var _preview: HouseholdItem = null
var _container: Node2D
var _stage_pos: Vector2
var _preview_pos: Vector2

func setup(container: Node2D, stage_pos: Vector2, preview_pos: Vector2) -> void:
	_container = container
	_stage_pos = stage_pos
	_preview_pos = preview_pos

func load_queue(ids: Array[String]) -> void:
	_queue = ids.duplicate()

func spawn_next() -> void:
	_clear_preview()

	if _queue.is_empty():
		queue_empty.emit()
		return

	# Spawn the current item in the staging slot
	var id: String = _queue.pop_front()
	_current = _create_item(id, _stage_pos, true)
	_current.placed.connect(_on_placed, CONNECT_ONE_SHOT)
	_current.fell.connect(_on_fell, CONNECT_ONE_SHOT)

	# Spawn the next-up preview (dimmed, non-interactive)
	if not _queue.is_empty():
		_preview = _create_item(_queue[0], _preview_pos, false)
		_preview.modulate = Color(1.0, 1.0, 1.0, 0.45)

func _create_item(id: String, world_pos: Vector2, is_active: bool) -> HouseholdItem:
	var def = ItemDatabase.get_item(id)
	var item: HouseholdItem = HouseholdItemScript.new()
	_container.add_child(item)
	item.setup(def)
	item.interactive = is_active
	item.global_position = world_pos
	return item

func _clear_preview() -> void:
	if _preview and is_instance_valid(_preview):
		_preview.queue_free()
	_preview = null

func _on_placed(item: HouseholdItem) -> void:
	_current = null
	GameManager.on_item_placed()
	# Brief pause so the player sees the item settle before the next one appears
	await get_tree().create_timer(0.7).timeout
	if is_inside_tree():
		spawn_next()

func _on_fell(item: HouseholdItem) -> void:
	GameManager.on_item_fell(item.display_name, item.value)
