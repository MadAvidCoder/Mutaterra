extends Node2D

var genes: Dictionary = {}
var speed: float = 10.0
var velocity = Vector2.ZERO
var direction_timer = 0.0
const CHANGE_INTERVAL = 2.0
var energy: float = 100.0
var reproduction_cooldown = 0.0
const REPRODUCTION_ENERGY_COST = 50
const REPRODUCTION_COOLDOWN_TIME = 10.0

@onready var main = $"../.."

func _ready():
	speed = genes.get("speed", 10.0)
	if speed <= 1:
		speed *= 10
	energy = genes.get("energy", 100.0)

	_pick_new_direction()

	if genes.has("size"):
		scale = Vector2.ONE * genes["size"]

func can_reproduce() -> bool:
	return energy >= REPRODUCTION_ENERGY_COST and reproduction_cooldown <= 0

func reproduce_with(partner):
	if not can_reproduce() or not partner.can_reproduce():
		return null

	energy -= REPRODUCTION_ENERGY_COST / 2
	partner.energy -= REPRODUCTION_ENERGY_COST / 2
	
	reproduction_cooldown = REPRODUCTION_COOLDOWN_TIME
	partner.reproduction_cooldown = REPRODUCTION_COOLDOWN_TIME
	
	var child_genes = {}
	for key in genes.keys():
		var gene_a = genes[key]
		var gene_b = partner.genes.get(key, gene_a)
		var avg_gene = (gene_a + gene_b) / 2
		var mutation = randf_range(-0.1, 0.1)
		child_genes[key] = clamp(avg_gene * (1 + mutation), 0, 1)
	
	var spawn_pos = (position + partner.position) / 2 + Vector2(randf_range(-10,10), randf_range(-10,10))
	
	return main.spawn_creature({"x": spawn_pos.x, "y": spawn_pos.y, "genes": child_genes, "energy": 100})

func try_reproduce_nearby():
	var mates = get_parent().get_children()
	for mate in mates:
		if mate == self:
			continue
		if position.distance_to(mate.position) < 30:
			var child = reproduce_with(mate)
			if child != null:
				print("New child spawned!")
				break

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	
	if reproduction_cooldown > 0:
		reproduction_cooldown -= delta
	else:
		try_reproduce_nearby()

	direction_timer -= delta
	if direction_timer <= 0:
		_pick_new_direction()

	position += velocity * delta

	energy -= delta

	modulate.a = clamp(energy / 100.0, 0.2, 1.0)

	var base_size = genes.get("size", 1.0)
	self.scale = Vector2.ONE * base_size * clamp(energy / 100.0, 0.5, 1.0)

	if energy <= 0:
		queue_free()

func _pick_new_direction():
	direction_timer = CHANGE_INTERVAL
	var angle = randf_range(0, TAU)

	velocity = Vector2.RIGHT.rotated(angle) * speed

	var mates = $"..".get_children()
	mates.shuffle()
	for mate in mates:
		if mate == self:
			continue
		if position.distance_to(mate.position) < 500 and randf() < 0.33:
			angle = position.angle_to(mate.position)
			mate.velocity = Vector2.RIGHT.rotated(mate.position.angle_to(self.position)) * mate.speed * 2
			velocity = Vector2.RIGHT.rotated(angle) * speed * 2

func setup(data):
	position = Vector2(data["x"], data["y"])
	var color = Color.from_hsv(data["genes"].get("color", 0) / 360.0, 1, 1)
	$ColorRect.color = color
	scale = Vector2.ONE * data["genes"].get("size", 1.0)
	genes = data["genes"]
	
	speed = genes.get("speed", 10.0)
	if speed <= 1:
		speed *= 30
	energy = genes.get("energy", 100.0)

	if genes.has("size"):
		scale = Vector2.ONE * genes["size"]
