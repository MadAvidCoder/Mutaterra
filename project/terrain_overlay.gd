extends Node2D

const CHUNK_SIZE = 512
const GRID_RANGE = 5

var noise = FastNoiseLite.new()

@onready var camera = $"../Camera2D"

func _ready():
	noise.seed = randi()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 0.02
	noise.fractal_octaves = 4

func _process(_delta):
	queue_redraw()

func _draw():
	var cam_pos = camera.position
	var cam_chunk_x = floor(cam_pos.x / CHUNK_SIZE)
	var cam_chunk_y = floor(cam_pos.y / CHUNK_SIZE)
	for dx in range(-GRID_RANGE, GRID_RANGE + 1):
		for dy in range(-GRID_RANGE, GRID_RANGE + 1):
			var chunk_x = cam_chunk_x + dx
			var chunk_y = cam_chunk_y + dy
			var n = noise.get_noise_2d(chunk_x, chunk_y)
			var color: Color
			if n < -0.25:
				color = Color(0.2, 0.5, 0.8, 0.18) # water
			elif n < 0.1:
				color = Color(0.9, 0.85, 0.5, 0.18) # sand
			else:
				color = Color(0.3, 0.8, 0.4, 0.18) # grass
			var origin = Vector2(chunk_x * CHUNK_SIZE, chunk_y * CHUNK_SIZE)
			draw_rect(Rect2(origin, Vector2(CHUNK_SIZE, CHUNK_SIZE)), color, true)
