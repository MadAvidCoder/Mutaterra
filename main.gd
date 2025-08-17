extends Node2D

@onready var http = $HTTPRequest
@onready var camera = $Camera2D
@onready var container = $CreatureContainer

var zoom_speed = 0.1
var move_speed = 500

func _process(delta: float) -> void:
	var input = Vector2(
		Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left"),
		Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
	)
	camera.position += input * move_speed * delta

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_WHEEL_UP:
		camera.zoom *= 1.0 - zoom_speed
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		camera.zoom *= 1.0 + zoom_speed
