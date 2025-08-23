extends CanvasLayer

@onready var id = $ColorRect/ID
@onready var energy = $ColorRect/Energy
@onready var generation = $ColorRect/Generation
@onready var speed = $ColorRect/Speed
@onready var size = $ColorRect/Size
@onready var color = $ColorRect/Color
@onready var angle = $ColorRect/Angle
@onready var jitter = $ColorRect/Jitter
@onready var click_handler = $ClickHandler

func set_creature_data(creature: Node):
	speed.text = "Speed: %.2f" % creature.genes.get("speed", 0)
	size.text = "Size: %.2f" % creature.genes.get("size", 0)
	color.text = "Color: %.2f" % creature.genes.get("color", 0)
	angle.text = "Move Angle: %.2f" % creature.genes.get("move_angle", 0)
	jitter.text = "Move Jitter: %.2f" % creature.genes.get("move_jitter", 0)
	energy.text = "Energy: %.2f" % creature.energy
	generation.text = "Generation: %d" % creature.generation
	var id_val = "N/A" if creature.id == -1 else str(int(creature.id))
	id.text = "ID: %s" % id_val
	show()

func _input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		hide()
		get_viewport().set_input_as_handled()

func _on_click_handler_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		hide()
		get_viewport().set_input_as_handled()
