extends Node2D

const MIN_ZOOM = 0.22
const MAX_ZOOM = 2.5

var zoom_speed = 0.075
var drag_speed = 0.5
var move_speed = 500
var chunk_size = 512
var loaded_chunks = {}
var last_mouse_pos = Vector2.ZERO
var is_dragging = false
var creature_chunks = {}

@onready var http = $HTTPRequest
@onready var camera = $Camera2D
@onready var container = $CreatureContainer
@onready var creature_scene = preload("res://Creature.tscn")

func _process(delta: float) -> void:
	var input = Vector2(
		Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left"),
		Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
	)
	camera.position += input * move_speed * delta
	
	_load_visible_chunks()
	_unload_far_chunks()

func _unload_far_chunks():
	var pos = camera.get_screen_center_position()
	var current_chunk = Vector2i(int(pos.x / chunk_size), int(pos.y / chunk_size))

	var chunks_to_unload := []

	for chunk_id in loaded_chunks.keys():
		var distance = current_chunk.distance_to(Vector2i(chunk_id))
		if distance > 15:
			chunks_to_unload.append(chunk_id)

	for chunk_id in chunks_to_unload:
		if creature_chunks.has(chunk_id):
			for creature in creature_chunks[chunk_id]:
				creature.queue_free()

		creature_chunks.erase(chunk_id)

		loaded_chunks.erase(chunk_id)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			is_dragging = event.pressed
			last_mouse_pos = event.position
		
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera.zoom *= 1.0 - zoom_speed
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera.zoom *= 1.0 + zoom_speed
	
	elif event is InputEventMouseMotion and is_dragging:
		var delta = event.position - last_mouse_pos
		camera.position -= delta / camera.zoom * drag_speed
		last_mouse_pos = event.position
	
	var z = camera.zoom
	z.x = clamp(z.x, MIN_ZOOM, MAX_ZOOM)
	z.y = clamp(z.y, MIN_ZOOM, MAX_ZOOM)
	camera.zoom = z


func _load_visible_chunks():
	var pos = camera.get_screen_center_position()
	var chunk_x = int(floor(pos.x / chunk_size))
	var chunk_y = int(floor(pos.y / chunk_size))
	var chunk_id = Vector2(chunk_x, chunk_y)
	
	if not loaded_chunks.has(chunk_id):
		http.fetch_chunk(chunk_x, chunk_y)
		loaded_chunks[chunk_id] = true

func _on_chunk_loaded(data) -> void:
	for creature in data:
		_spawn_creature(creature)

func _spawn_creature(data: Dictionary):
	var c = creature_scene.instantiate()
	c.setup(data)
	container.add_child(c)
	
	var chunk_x = int(floor(data["x"] / chunk_size))
	var chunk_y = int(floor(data["y"] / chunk_size))
	var chunk_id = Vector2(chunk_x, chunk_y)

	if not creature_chunks.has(chunk_id):
		creature_chunks[chunk_id] = []

	creature_chunks[chunk_id].append(c)
