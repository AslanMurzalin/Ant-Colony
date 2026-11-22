class_name FoodSpawner
extends Node2D

# Surface food spawner that creates near and far food nodes across the grass boundary.

signal food_spawned(source: FoodSource)

var active_sources: Array[FoodSource] = []
var food_source_scene: PackedScene = preload("res://scenes/economy/food_source.tscn")
var spawn_timer: float = 0.0
var spawn_interval: float = 30.0

func _ready() -> void:
	spawn_initial_food()

func _process(delta: float) -> void:
	if GameManager.game_state == Enums.GameState.RUNNING:
		spawn_timer += delta
		if spawn_timer >= spawn_interval:
			spawn_timer = 0.0
			_spawn_periodic_food()

func spawn_initial_food() -> void:
	# Spawn close crumb nodes near entrance (X: 880, 1040, Y: 248)
	spawn_food_node(Vector2(880.0, 248.0), 6, "Bread Crumb")
	spawn_food_node(Vector2(1040.0, 248.0), 6, "Seed Cluster")
	
	# Spawn far rich nodes (Fruit / Dead Insect)
	spawn_food_node(Vector2(450.0, 248.0), 20, "Fallen Strawberry")
	spawn_food_node(Vector2(1480.0, 248.0), 25, "Dead Beetle Carcass")

func spawn_food_node(pos: Vector2, amount: int, s_name: String) -> FoodSource:
	if food_source_scene == null:
		return null
	
	var node: FoodSource = food_source_scene.instantiate() as FoodSource
	node.position = pos
	node.food_units = amount
	node.source_name = s_name
	add_child(node)
	
	active_sources.append(node)
	node.food_depleted.connect(func() -> void:
		_on_food_depleted(node)
	)
	food_spawned.emit(node)
	return node

func _spawn_periodic_food() -> void:
	if active_sources.size() < 6:
		var is_far: bool = randf() > 0.5
		var spawn_x: float = 0.0
		var amount: int = 5
		var name_str: String = "Crumb"
		
		if is_far:
			spawn_x = randf_range(300.0, 600.0) if randf() < 0.5 else randf_range(1300.0, 1650.0)
			amount = randi_range(15, 25)
			name_str = "Rich Food Deposit"
		else:
			spawn_x = randf_range(800.0, 1120.0)
			amount = randi_range(4, 8)
			name_str = "Bread Crumb"
		
		spawn_food_node(Vector2(spawn_x, 248.0), amount, name_str)

func get_closest_food(from_pos: Vector2) -> FoodSource:
	var best_source: FoodSource = null
	var min_dist: float = 999999.0
	
	for s in active_sources:
		if is_instance_valid(s) and not s.is_depleted and s.food_units > 0:
			var d: float = from_pos.distance_squared_to(s.global_position)
			if d < min_dist:
				min_dist = d
				best_source = s
				
	return best_source

func _on_food_depleted(source: FoodSource) -> void:
	if active_sources.has(source):
		active_sources.erase(source)
