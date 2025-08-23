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

var last_id

func set_creature_data(creature: Node):
	last_id = creature.id
	speed.text = "Speed: %.2f" % creature.genes.get("speed", 0)
	size.text = "Size: %.2f" % creature.genes.get("size", 0)
	color.text = "Color: %.2f" % creature.genes.get("color", 0)
	angle.text = "Move Angle: %.2f" % creature.genes.get("move_angle", 0)
	jitter.text = "Move Jitter: %.2f" % creature.genes.get("move_jitter", 0)
	energy.text = "Energy: %.2f" % creature.energy
	generation.text = "Generation: %d" % creature.generation
	id.text = $"..".creature_names.get(creature.id, str(int(creature.id)))
	show()

func _input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		hide()
		if last_id != -1:
			$"..".creature_names[last_id] = id.text
		get_viewport().set_input_as_handled()

func _on_click_handler_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var mouse_pos = get_viewport().get_mouse_position()
		var panel_rect = $ColorRect.get_global_rect()
		if not panel_rect.has_point(mouse_pos):
			hide()
			if last_id != -1:
				$"..".creature_names[last_id] = id.text
			get_viewport().set_input_as_handled()

func _on_id_text_submitted(new_text: String) -> void:
	if visible:
		if last_id != -1:
			$"..".creature_names[last_id] = id.text
