class_name LarvaEntity
extends Node2D

# Larva entity on the chamber floor requiring feeding from nurse ants to mature.

var larva_id: int = 0
var food_fed: int = 0
var food_required: int = 2
var growth_timer: float = 35.0
var is_fed: bool = false

@onready var hunger_bubble: Node2D = $HungerBubble

func _ready() -> void:
	_update_hunger_bubble()

func feed() -> bool:
	if food_fed < food_required:
		food_fed += 1
		if food_fed >= food_required:
			is_fed = true
		_update_hunger_bubble()
		return true
	return false

func is_hungry() -> bool:
	return food_fed < food_required

func _update_hunger_bubble() -> void:
	if hunger_bubble != null:
		hunger_bubble.visible = is_hungry()
	queue_redraw()

func _draw() -> void:
	# Draw plump segmented grub body
	var col: Color = Color(0.92, 0.90, 0.82)
	draw_circle(Vector2(-3, 0), 4.0, col)
	draw_circle(Vector2(2, 0), 5.0, col)
	draw_circle(Vector2(6, 0), 4.0, col)
	draw_circle(Vector2(-3, 0), 4.0, col.darkened(0.2), false, 1.0)
	draw_circle(Vector2(2, 0), 5.0, col.darkened(0.2), false, 1.0)
	draw_circle(Vector2(6, 0), 4.0, col.darkened(0.2), false, 1.0)
