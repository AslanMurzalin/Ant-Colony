class_name FoodSource
extends Node2D

# Surface food entity representing crumbs, seeds, fruit, or dead insects.

signal food_harvested(remaining: int)
signal food_depleted()

@export var food_units: int = 5
@export var initial_units: int = 5
@export var source_name: String = "Crumb"
@export var is_depleted: bool = false

@onready var count_label: Label = $CountLabel
@onready var sprite: Sprite2D = get_node_or_null("Sprite2D") as Sprite2D

func _ready() -> void:
	initial_units = food_units
	if sprite != null and initial_units > 10:
		var apple_tex_path: String = "res://assets/sprites_topdown/food_apple.png"
		if ResourceLoader.exists(apple_tex_path):
			sprite.texture = load(apple_tex_path)
	if ResourceManager != null and ResourceManager.has_signal("food_changed"):
		ResourceManager.connect("food_changed", Callable(self, "_on_storage_food_changed"))
	_update_display()

func _on_storage_food_changed(_cur: int, _max: int) -> void:
	_update_display()

func harvest_unit() -> int:
	if is_depleted or food_units <= 0:
		return 0
	
	food_units -= 1
	food_harvested.emit(food_units)
	_update_display()
	
	if food_units <= 0:
		is_depleted = true
		food_depleted.emit()
		queue_free()
	
	return 1

func get_remaining_food() -> int:
	return food_units

func _update_display() -> void:
	if count_label != null:
		var is_full: bool = false
		if ResourceManager != null and ResourceManager.has_method("has_available_storage_space"):
			is_full = not ResourceManager.has_available_storage_space()
		if is_full:
			count_label.text = "%d [Full]" % food_units
			count_label.add_theme_color_override("font_color", Color(1.0, 0.55, 0.2))
		else:
			count_label.text = "%d" % food_units
			count_label.remove_theme_color_override("font_color")
	queue_redraw()

func _draw() -> void:
	if sprite == null:
		# Draw food icon representation based on amount
		var base_radius: float = 6.0 if initial_units <= 10 else 10.0
		var col: Color = Color(0.95, 0.76, 0.19) if initial_units <= 10 else Color(0.85, 0.35, 0.25)
		draw_circle(Vector2.ZERO, base_radius, col)
		draw_circle(Vector2.ZERO, base_radius + 1.0, col.darkened(0.3), false, 1.5)
