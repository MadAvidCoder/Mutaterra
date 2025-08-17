extends Node2D

@export var chunk_size: int = 512
@export var range: int = 15
@onready var camera: Camera2D = get_parent().get_node("Camera2D")

func _process(delta):
	queue_redraw()

func _draw():
	var cam_pos = camera.get_screen_center_position()
	var cam_chunk_x = int(cam_pos.x / chunk_size)
	var cam_chunk_y = int(cam_pos.y / chunk_size)

	for dx in range(-range, range + 1):
		for dy in range(-range, range + 1):
			var chunk_x = cam_chunk_x + dx
			var chunk_y = cam_chunk_y + dy
			var origin = Vector2(chunk_x * chunk_size, chunk_y * chunk_size)

			var top_left = origin
			var top_right = origin + Vector2(chunk_size, 0)
			var bottom_left = origin + Vector2(0, chunk_size)
			var bottom_right = origin + Vector2(chunk_size, chunk_size)

			draw_line(top_left, top_right, Color.GRAY, 2.0)
			draw_line(top_right, bottom_right, Color.GRAY, 2.0)
			draw_line(bottom_right, bottom_left, Color.GRAY, 2.0)
			draw_line(bottom_left, top_left, Color.GRAY, 2.0)

			# Optional: Draw chunk coords
			draw_string(
				ThemeDB.fallback_font,
				origin + Vector2(4, 14),
				"C(%d, %d)" % [chunk_x, chunk_y],
				0,
				-1,
				12,
				Color(0.5, 0.5, 0.5)
			)
