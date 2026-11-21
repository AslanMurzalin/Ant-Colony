extends Node

# Tracks eggs and larvae inside the nursery, managing incubation and maturation timers.

signal egg_spawned(egg_id: int)
signal egg_hatched(larva_id: int)
signal larva_matured(ant_instance: AntController)

var active_eggs: Array[EggEntity] = []
var active_larvae: Array[LarvaEntity] = []
var egg_incubation_time: float = 25.0
var larva_growth_time: float = 35.0
var larva_food_required: int = 2

var egg_counter: int = 0
var larva_counter: int = 0

var egg_scene: PackedScene = preload("res://scenes/entities/egg.tscn")
var larva_scene: PackedScene = preload("res://scenes/entities/larva.tscn")
var ant_scene: PackedScene = preload("res://scenes/entities/ant.tscn")

func _process(delta: float) -> void:
	if GameManager.game_state == Enums.GameState.RUNNING:
		_process_lifecycle(delta)

func _process_lifecycle(delta: float) -> void:
	# Process incubating eggs
	var eggs_copy: Array[EggEntity] = active_eggs.duplicate()
	for egg in eggs_copy:
		if is_instance_valid(egg):
			egg.incubation_timer -= delta
			if egg.incubation_timer <= 0.0:
				hatch_egg(egg.egg_id)
	
	# Process fed larvae
	var larvae_copy: Array[LarvaEntity] = active_larvae.duplicate()
	for larva in larvae_copy:
		if is_instance_valid(larva) and larva.is_fed:
			larva.growth_timer -= delta
			if larva.growth_timer <= 0.0:
				mature_larva(larva.larva_id)

func spawn_egg(chamber_pos: Vector2) -> void:
	if GameManager.total_workers_alive >= 50:
		return
	
	var egg: EggEntity = egg_scene.instantiate() as EggEntity
	egg.egg_id = egg_counter
	egg_counter += 1
	egg.incubation_timer = egg_incubation_time
	egg.position = chamber_pos
	
	add_child(egg)
	active_eggs.append(egg)
	egg_spawned.emit(egg.egg_id)

func hatch_egg(egg_id: int) -> void:
	var target_egg: EggEntity = null
	for egg in active_eggs:
		if egg.egg_id == egg_id:
			target_egg = egg
			break
	
	if target_egg == null:
		return
	
	var spawn_pos: Vector2 = target_egg.position
	active_eggs.erase(target_egg)
	target_egg.queue_free()
	
	var larva: LarvaEntity = larva_scene.instantiate() as LarvaEntity
	larva.larva_id = larva_counter
	larva_counter += 1
	larva.food_required = larva_food_required
	larva.growth_timer = larva_growth_time
	larva.position = spawn_pos
	
	add_child(larva)
	active_larvae.append(larva)
	egg_hatched.emit(larva.larva_id)

func feed_larva(larva_id: int) -> bool:
	for larva in active_larvae:
		if is_instance_valid(larva) and larva.larva_id == larva_id:
			return larva.feed()
	return false

func mature_larva(larva_id: int) -> void:
	var target_larva: LarvaEntity = null
	for larva in active_larvae:
		if larva.larva_id == larva_id:
			target_larva = larva
			break
	
	if target_larva == null:
		return
	
	var spawn_pos: Vector2 = target_larva.position
	active_larvae.erase(target_larva)
	target_larva.queue_free()
	
	if GameManager.total_workers_alive >= 50:
		return
	
	var ant: AntController = ant_scene.instantiate() as AntController
	ant.ant_id = GameManager.get_next_ant_id()
	ant.position = spawn_pos
	
	var main_node: Node = get_tree().current_scene
	var ants_container: Node2D = main_node.get_node_or_null("Ants") as Node2D if main_node != null else null
	if ants_container != null:
		ants_container.add_child(ant)
	else:
		add_child(ant)
	
	var job: Enums.JobType = TaskAllocationManager.request_job_for_ant(ant)
	ant.assign_job(job)
	
	GameManager.total_workers_alive += 1
	GameManager.ants_born_today += 1
	larva_matured.emit(ant)

func get_hungry_larva() -> LarvaEntity:
	for larva in active_larvae:
		if is_instance_valid(larva) and larva.is_hungry():
			return larva
	return null

func get_random_nursery_position() -> Vector2:
	if GridManager != null:
		var nursery_cells: Array[Vector2i] = []
		for coord in GridManager.chambers.keys():
			if GridManager.chambers[coord] == Enums.ChamberType.NURSERY:
				nursery_cells.append(coord)
		
		if nursery_cells.size() > 0:
			var picked: Vector2i = nursery_cells[randi() % nursery_cells.size()]
			return GridManager.grid_to_world(picked)
	
	# Default fallback to Royal Chamber center
	return Vector2(976.0, 528.0)
