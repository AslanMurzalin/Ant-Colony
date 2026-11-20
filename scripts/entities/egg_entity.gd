class_name EggEntity
extends Node2D

# Egg entity incubating in the royal chamber or dedicated nursery.

var egg_id: int = 0
var incubation_timer: float = 25.0

func _draw() -> void:
	if not has_node("Sprite2D"):
		draw_circle(Vector2.ZERO, 4.0, Color(0.95, 0.95, 0.88))
		draw_circle(Vector2.ZERO, 4.0, Color(0.8, 0.8, 0.7), false, 1.0)
