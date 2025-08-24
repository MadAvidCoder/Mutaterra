extends Node2D

const MIN_ZOOM = 0.3
const MAX_ZOOM = 2.5

var zoom_speed = 0.075
var move_speed = 500
var chunk_size = 512
var loaded_chunks = {}
var last_mouse_pos = Vector2.ZERO
var is_dragging = false
var creature_chunks = {}
var requested_chunks = {}
var creature_map = {}
var pending_chunk_batches = {}
var creature_names = {-1: "N/A"}

var food_per_chunk = {}
const MAX_FOOD_PER_CHUNK = 10
const FOOD_RESPAWN_INTERVAL = 2.0
var food_timer = 0.0

@onready var network = $Network
@onready var camera = $Camera2D
@onready var container = $CreatureContainer

func random_genes():
	return {
		"speed": randf_range(0.2, 1.0),
		"size": randf_range(0.5, 1.5),
		"color": randf(),
		"move_angle": randf_range(0, TAU),
		"move_jitter": randf_range(0.05, 0.5)
	}

func _process(delta: float) -> void:
	var input = Vector2(
		Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left"),
		Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
	)
	camera.position += input * move_speed * delta
	
	_load_visible_chunks()
	_unload_far_chunks()
	
	food_timer += delta
	if food_timer > FOOD_RESPAWN_INTERVAL:
		_spawn_food_in_loaded_chunks()
		food_timer = 0.0

func _spawn_food_in_loaded_chunks():
	for chunk_id in loaded_chunks.keys():
		var food_list = food_per_chunk.get(chunk_id, [])
		food_list = food_list.filter(func(f): return is_instance_valid(f))
		while food_list.size() < MAX_FOOD_PER_CHUNK:
			var food = load("res://food.tscn").instantiate()
			var chunk_x = chunk_id.x
			var chunk_y = chunk_id.y
			food.position = Vector2(
				randf_range(chunk_x * chunk_size, (chunk_x + 1) * chunk_size),
				randf_range(chunk_y * chunk_size, (chunk_y + 1) * chunk_size)
			)
			container.add_child(food)
			food.add_to_group("food")
			food_list.append(food)
		food_per_chunk[chunk_id] = food_list

func _unload_far_chunks():
	var pos = camera.position
	var current_chunk = Vector2i(floor(pos.x / chunk_size), floor(pos.y / chunk_size))

	var chunks_to_unload := []

	for chunk_id in loaded_chunks.keys():
		var distance = current_chunk.distance_to(chunk_id)
		if distance > 6:
			chunks_to_unload.append(chunk_id)

	for chunk_id in chunks_to_unload:
		if creature_chunks.has(chunk_id):
			for creature in creature_chunks[chunk_id]:
				if is_instance_valid(creature):
					creature.queue_free()
			creature_chunks.erase(chunk_id)
		network.unwatch_chunk(chunk_id.x, chunk_id.y)
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
	
	if event is InputEventMouseMotion and is_dragging:
		var delta = event.position - last_mouse_pos
		camera.position -= delta / camera.zoom
		last_mouse_pos = event.position
	
	if event is InputEventKey and event.pressed and event.keycode == KEY_S:
		var world_pos = camera.get_global_mouse_position()
		network.send_spawn_creature(world_pos, random_genes())
	
	if event is InputEventKey and event.pressed and event.keycode == KEY_F:
		var world_pos = camera.get_global_mouse_position()
		var food = load("res://food.tscn").instantiate()
		food.position = world_pos
		container.add_child(food)
		food.add_to_group("food")
		var chunk_x = int(floor(food.position.x / chunk_size))
		var chunk_y = int(floor(food.position.y / chunk_size))
		var chunk_id = Vector2i(chunk_x, chunk_y)
		if not food_per_chunk.has(chunk_id):
			food_per_chunk[chunk_id] = []
		food_per_chunk[chunk_id].append(food)
	
	var z = camera.zoom
	z.x = clamp(z.x, MIN_ZOOM, MAX_ZOOM)
	z.y = clamp(z.y, MIN_ZOOM, MAX_ZOOM)
	camera.zoom = z

func _load_visible_chunks():
	var pos = camera.position
	var cam_chunk_x = floor(pos.x / chunk_size)
	var cam_chunk_y = floor(pos.y / chunk_size)

	var preload_radius = 3

	for dx in range(-preload_radius, preload_radius + 1):
		for dy in range(-preload_radius, preload_radius + 1):
			var chunk_x = cam_chunk_x + dx
			var chunk_y = cam_chunk_y + dy
			var chunk_id = Vector2i(chunk_x, chunk_y)
			
			if loaded_chunks.has(chunk_id) or requested_chunks.has(chunk_id):
				continue
			
			network.fetch_chunk(chunk_x, chunk_y)
			requested_chunks[chunk_id] = true

func _on_chunk_loaded(data) -> void:
	var chunk_id = Vector2i(data.get("chunk_x", -9999), data.get("chunk_y", -9999))
	if chunk_id.x == -9999 or chunk_id.y == -9999:
		print("Error: Received chunk data without valid chunk coords:", data)
		return

	# Batch handling
	var batch_index = int(data["batch_index"]) if data.has("batch_index") else 0
	var batch_count = int(data["batch_count"]) if data.has("batch_count") else 1
	
	if not pending_chunk_batches.has(chunk_id):
		pending_chunk_batches[chunk_id] = {
			"batches": {},
			"total": batch_count
		}

	pending_chunk_batches[chunk_id]["batches"][batch_index] = data.get("creatures", [])
	pending_chunk_batches[chunk_id]["total"] = batch_count

	if pending_chunk_batches[chunk_id]["batches"].size() == batch_count:
		var all_creatures = []
		for i in range(batch_count):
			all_creatures += pending_chunk_batches[chunk_id]["batches"][i]
		for creature in all_creatures:
			spawn_creature(creature)
		loaded_chunks[chunk_id] = true
		if requested_chunks.has(chunk_id):
			requested_chunks.erase(chunk_id)
		else:
			print("Warning: chunk", chunk_id, "was not in requested_chunks when loaded")
		pending_chunk_batches.erase(chunk_id)

func spawn_creature(data: Dictionary):
	var c = load("res://creature.tscn").instantiate()
	var chunk_x = floor(data["x"] / chunk_size)
	var chunk_y = floor(data["y"] / chunk_size)
	var chunk_id = Vector2i(chunk_x, chunk_y)
	
	c.setup(data, chunk_x, chunk_y)
	container.add_child(c)

	if not creature_chunks.has(chunk_id):
		creature_chunks[chunk_id] = []

	creature_chunks[chunk_id].append(c)
	
	if data.has("id"):
		creature_map[data["id"]] = c
		c.connect("tree_exited", Callable(self, "_on_creature_removed").bind(data["id"]))
	
	return c

func _on_creature_removed(id):
	if creature_map.has(id):
		creature_map.erase(id)

func _find_creature_by_id(id):
	if creature_map.has(id):
		return creature_map[id]
	return null

func _on_chunk_updated(data: Dictionary) -> void:
	if data.has("dead_ids"):
		for id in data["dead_ids"]:
			var creature = _find_creature_by_id(id)
			if creature:
				creature.queue_free()
				creature_map.erase(id)
				if id in creature_names:
					creature_names.erase(id)
	for creature_data in data.get("creatures", []):
		if not creature_data.has("id"):
			return
		var creature = _find_creature_by_id(creature_data["id"])
		if creature:
			creature.sync_with_backend(creature_data)
		else:
			spawn_creature(creature_data)
