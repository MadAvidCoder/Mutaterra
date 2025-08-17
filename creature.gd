extends Node2D

func setup(data):
	position = Vector2(data["x"], data["y"])
	var color = Color.from_hsv(data["genes"].get("color", 0) / 360.0, 1, 1)
	$ColorRect.color = color
	scale = Vector2.ONE * data["genes"].get("size", 1.0)
