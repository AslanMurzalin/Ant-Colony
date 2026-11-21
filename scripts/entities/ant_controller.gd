class_name AntController
extends CharacterBody2D

# Base controller for worker ants. Manages locomotion, pathfinding, visual role badges, cargo transport, and finite state machine execution.

signal ant_died(ant: AntController)
signal ant_state_changed(old_state: Enums.AntState, new_state: Enums.AntState)
signal job_switched(old_job: Enums.JobType, new_job: Enums.JobType)

@export var current_job: Enums.JobType = Enums.JobType.IDLE
@export var state: Enums.AntState = Enums.AntState.IDLE
@export var health: float = 20.0
@export var move_speed: float = 45.0
var carried_cargo: Variant = null
var current_target_pos: Vector2 = Vector2.ZERO
var target_cell: Vector2i = Vector2i(-1, -1)
var combat_target: Node2D = null

var path_waypoints: Array[Vector2] = []
var current_path_index: int = 0
var dig_time_per_tile: float = 2.5
var walk_anim_timer: float = 0.0

var target_food_source: FoodSource = null
var target_feed_entity: Node2D = null
var combat_attack_timer: float = 0.0
var nurse_wander_timer: float = 0.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var job_badge: ColorRect = $JobBadge
@onready var cargo_node: Node2D = $CargoNode

func _ready() -> void:
	add_to_group("workers")
	update_job_visuals()
	update_cargo_visuals()

func _physics_process(delta: float) -> void:
	if GameManager.game_state == Enums.GameState.RUNNING:
		execute_job_behavior(delta)
		_apply_soft_separation(delta)
	_animate_walk(delta)

func _animate_walk(delta: float) -> void:
	if velocity.length() > 1.0:
		walk_anim_timer += delta * 8.0
		var bob: float = sin(walk_anim_timer) * 1.5
		if sprite != null:
			sprite.position.y = bob
			if velocity.x < -0.1:
				sprite.flip_h = true
			elif velocity.x > 0.1:
				sprite.flip_h = false
	else:
		if sprite != null:
			sprite.position.y = 0.0

func assign_job(new_job: Enums.JobType) -> void:
	if new_job == current_job:
		return
	var old_job: Enums.JobType = current_job
	if old_job != Enums.JobType.IDLE:
		TaskAllocationManager.unregister_ant(old_job)
	
	current_job = new_job
	if current_job != Enums.JobType.IDLE:
		TaskAllocationManager.register_ant(current_job)
	
	update_job_visuals()
	job_switched.emit(old_job, new_job)

func request_job_transition() -> void:
	if state != Enums.AntState.IDLE:
		return
	var desired_job: Enums.JobType = TaskAllocationManager.request_job_for_ant(self)
	if desired_job != current_job:
		assign_job(desired_job)

func set_ant_state(new_state: Enums.AntState) -> void:
	if new_state == state:
		return
	var old_state: Enums.AntState = state
	state = new_state
	ant_state_changed.emit(old_state, new_state)

func navigate_to(target_world_pos: Vector2) -> void:
	var start_grid: Vector2i = GridManager.world_to_grid(global_position)
	var end_grid: Vector2i = GridManager.world_to_grid(target_world_pos)
	var waypoints: Array[Vector2] = GridManager.get_world_path(start_grid, end_grid)
	
	path_waypoints = waypoints
	current_path_index = 0
	current_target_pos = target_world_pos
	if path_waypoints.size() > 0 and path_waypoints[0].distance_to(global_position) < 8.0:
		current_path_index = 1

func move_along_path(delta: float) -> bool:
	if path_waypoints.is_empty() or current_path_index >= path_waypoints.size():
		velocity = Vector2.ZERO
		return true

	var target_wp: Vector2 = path_waypoints[current_path_index]
	var dist: float = global_position.distance_to(target_wp)
	
	if dist <= 8.0:
		current_path_index += 1
		if current_path_index >= path_waypoints.size():
			velocity = Vector2.ZERO
			return true
		target_wp = path_waypoints[current_path_index]

	var dir: Vector2 = (target_wp - global_position).normalized()
	velocity = dir * move_speed
	move_and_slide()
	return false

func execute_job_behavior(delta: float) -> void:
	match current_job:
		Enums.JobType.FORAGE:
			_tick_forage()
		Enums.JobType.DIG:
			_tick_dig()
		Enums.JobType.NURSE:
			_tick_nurse()
		Enums.JobType.DEFEND:
			_tick_defend()
		_:
			if state == Enums.AntState.IDLE:
				request_job_transition()

func _tick_dig() -> void:
	match state:
		Enums.AntState.IDLE:
			request_job_transition()
			if current_job != Enums.JobType.DIG:
				return
			
			target_cell = GridManager.get_next_dig_target(global_position)
			if target_cell != Vector2i(-1, -1):
				var cur_cell: Vector2i = GridManager.world_to_grid(global_position)
				var is_adjacent: bool = (abs(cur_cell.x - target_cell.x) + abs(cur_cell.y - target_cell.y)) <= 1
				if is_adjacent:
					set_ant_state(Enums.AntState.WORKING)
				else:
					var target_world: Vector2 = GridManager.grid_to_world(target_cell)
					navigate_to(target_world)
					if path_waypoints.size() > 0:
						set_ant_state(Enums.AntState.TRAVELING_TO_TARGET)
					else:
						target_cell = Vector2i(-1, -1)
			else:
				var home_pos: Vector2 = Vector2(976.0, 528.0)
				if global_position.distance_to(home_pos) > 96.0:
					navigate_to(home_pos)
					if path_waypoints.size() > 0:
						set_ant_state(Enums.AntState.TRAVELING_TO_TARGET)

		Enums.AntState.TRAVELING_TO_TARGET:
			if target_cell == Vector2i(-1, -1):
				var reached_home: bool = move_along_path(get_physics_process_delta_time())
				if reached_home:
					set_ant_state(Enums.AntState.IDLE)
				return
				
			if not GridManager.is_cell_marked_for_dig(target_cell):
				path_waypoints.clear()
				target_cell = Vector2i(-1, -1)
				set_ant_state(Enums.AntState.IDLE)
				return
			
			var cur_cell: Vector2i = GridManager.world_to_grid(global_position)
			var is_adjacent: bool = (abs(cur_cell.x - target_cell.x) + abs(cur_cell.y - target_cell.y)) <= 1
			if is_adjacent:
				path_waypoints.clear()
				velocity = Vector2.ZERO
				set_ant_state(Enums.AntState.WORKING)
			else:
				var reached: bool = move_along_path(get_physics_process_delta_time())
				if reached:
					cur_cell = GridManager.world_to_grid(global_position)
					is_adjacent = (abs(cur_cell.x - target_cell.x) + abs(cur_cell.y - target_cell.y)) <= 1
					if is_adjacent:
						set_ant_state(Enums.AntState.WORKING)
					else:
						target_cell = Vector2i(-1, -1)
						set_ant_state(Enums.AntState.IDLE)

		Enums.AntState.WORKING:
			if not GridManager.is_cell_marked_for_dig(target_cell) or GridManager.get_cell_type(target_cell) != Enums.CellType.SOIL:
				target_cell = Vector2i(-1, -1)
				set_ant_state(Enums.AntState.IDLE)
				return
			
			velocity = Vector2.ZERO
			var progress_step: float = get_physics_process_delta_time() / dig_time_per_tile
			var completed: bool = GridManager.apply_dig_damage(target_cell, progress_step)
			if completed:
				carried_cargo = "dirt"
				update_cargo_visuals()
				target_cell = Vector2i(-1, -1)
				set_ant_state(Enums.AntState.IDLE)

		Enums.AntState.CARRYING_PAYLOAD:
			carried_cargo = null
			update_cargo_visuals()
			set_ant_state(Enums.AntState.IDLE)

func _tick_forage() -> void:
	match state:
		Enums.AntState.IDLE:
			request_job_transition()
			if current_job != Enums.JobType.FORAGE:
				return
			
			var spawner: FoodSpawner = null
			var main_node: Node = get_tree().current_scene
			if main_node != null:
				spawner = main_node.get_node_or_null("FoodSpawner") as FoodSpawner
			
			if spawner != null:
				var food: FoodSource = spawner.get_closest_food(global_position)
				if food != null:
					target_food_source = food
					navigate_to(food.global_position)
					if path_waypoints.size() > 0:
						set_ant_state(Enums.AntState.TRAVELING_TO_TARGET)
				else:
					var home_pos: Vector2 = Vector2(976.0, 528.0)
					if global_position.distance_to(home_pos) > 96.0:
						navigate_to(home_pos)
						if path_waypoints.size() > 0:
							set_ant_state(Enums.AntState.TRAVELING_TO_TARGET)

		Enums.AntState.TRAVELING_TO_TARGET:
			if target_food_source == null:
				var reached_home: bool = move_along_path(get_physics_process_delta_time())
				if reached_home:
					set_ant_state(Enums.AntState.IDLE)
				return

			if not is_instance_valid(target_food_source) or target_food_source.is_depleted:
				target_food_source = null
				path_waypoints.clear()
				set_ant_state(Enums.AntState.IDLE)
				return
			
			var reached: bool = move_along_path(get_physics_process_delta_time())
			var dist: float = global_position.distance_to(target_food_source.global_position)
			if reached or dist <= 24.0:
				path_waypoints.clear()
				velocity = Vector2.ZERO
				var harvested: int = target_food_source.harvest_unit()
				if harvested > 0:
					carried_cargo = "food"
					update_cargo_visuals()
					target_food_source = null
					var deposit_pos: Vector2 = _find_nearest_food_storage()
					navigate_to(deposit_pos)
					set_ant_state(Enums.AntState.CARRYING_PAYLOAD)
				else:
					target_food_source = null
					set_ant_state(Enums.AntState.IDLE)

		Enums.AntState.CARRYING_PAYLOAD:
			var reached_deposit: bool = move_along_path(get_physics_process_delta_time())
			var dist: float = global_position.distance_to(current_target_pos)
			if reached_deposit or dist <= 28.0:
				path_waypoints.clear()
				velocity = Vector2.ZERO
				ResourceManager.add_food(1)
				GameManager.food_gathered_today += 1
				carried_cargo = null
				update_cargo_visuals()
				set_ant_state(Enums.AntState.IDLE)

func _tick_nurse() -> void:
	match state:
		Enums.AntState.IDLE:
			request_job_transition()
			if current_job != Enums.JobType.NURSE:
				return
			
			if not ResourceManager.has_food(1):
				_wander_in_chamber()
				return
			
			target_feed_entity = null
			var main_node: Node = get_tree().current_scene
			var queen: QueenController = main_node.get_node_or_null("Queen") as QueenController if main_node != null else null
			
			# Check if Queen needs food and isn't already targeted by another nurse
			var queen_needs_food: bool = (queen != null and (queen.is_starving or queen.hunger_timer < 11.0))
			if queen_needs_food and not _is_entity_targeted_by_another_nurse(queen):
				target_feed_entity = queen
			else:
				var larva: LarvaEntity = _find_unclaimed_hungry_larva()
				if larva != null:
					target_feed_entity = larva
			
			if target_feed_entity != null:
				var fetch_pos: Vector2 = _find_nearest_food_storage()
				if global_position.distance_to(fetch_pos) <= 24.0:
					if ResourceManager.consume_food(1):
						carried_cargo = "food"
						update_cargo_visuals()
						var target_offset: Vector2 = Vector2(randf_range(-14.0, 14.0), randf_range(-8.0, 8.0))
						navigate_to(target_feed_entity.global_position + target_offset)
						set_ant_state(Enums.AntState.CARRYING_PAYLOAD)
				else:
					navigate_to(fetch_pos)
					if path_waypoints.size() > 0:
						set_ant_state(Enums.AntState.TRAVELING_TO_TARGET)
			else:
				_wander_in_chamber()

		Enums.AntState.TRAVELING_TO_TARGET:
			if target_feed_entity == null:
				var reached_home: bool = move_along_path(get_physics_process_delta_time())
				if reached_home:
					set_ant_state(Enums.AntState.IDLE)
				return

			var reached: bool = move_along_path(get_physics_process_delta_time())
			var dist: float = global_position.distance_to(current_target_pos)
			if reached or dist <= 24.0:
				path_waypoints.clear()
				velocity = Vector2.ZERO
				if ResourceManager.consume_food(1):
					carried_cargo = "food"
					update_cargo_visuals()
					if target_feed_entity != null and is_instance_valid(target_feed_entity):
						var target_offset: Vector2 = Vector2(randf_range(-14.0, 14.0), randf_range(-8.0, 8.0))
						navigate_to(target_feed_entity.global_position + target_offset)
						set_ant_state(Enums.AntState.CARRYING_PAYLOAD)
					else:
						ResourceManager.add_food(1)
						carried_cargo = null
						update_cargo_visuals()
						set_ant_state(Enums.AntState.IDLE)
				else:
					target_feed_entity = null
					set_ant_state(Enums.AntState.IDLE)

		Enums.AntState.CARRYING_PAYLOAD:
			if target_feed_entity == null or not is_instance_valid(target_feed_entity):
				ResourceManager.add_food(1)
				carried_cargo = null
				update_cargo_visuals()
				set_ant_state(Enums.AntState.IDLE)
				return
			
			var reached_target: bool = move_along_path(get_physics_process_delta_time())
			var dist: float = global_position.distance_to(target_feed_entity.global_position)
			if reached_target or dist <= 28.0:
				path_waypoints.clear()
				velocity = Vector2.ZERO
				if target_feed_entity is QueenController:
					(target_feed_entity as QueenController).feed_queen(1)
				elif target_feed_entity is LarvaEntity:
					(target_feed_entity as LarvaEntity).feed()
				target_feed_entity = null
				carried_cargo = null
				update_cargo_visuals()
				set_ant_state(Enums.AntState.IDLE)

func _is_entity_targeted_by_another_nurse(target: Node2D) -> bool:
	for worker in get_tree().get_nodes_in_group("workers"):
		if worker != self and worker is AntController:
			var other: AntController = worker as AntController
			if other.current_job == Enums.JobType.NURSE and other.target_feed_entity == target:
				return true
	return false

func _find_unclaimed_hungry_larva() -> LarvaEntity:
	var nursery = get_node_or_null("/root/NurseryManager")
	if nursery == null:
		return null
	var larvae: Array = nursery.get("active_larvae")
	if larvae == null:
		return null
	for l in larvae:
		if is_instance_valid(l) and l is LarvaEntity and (l as LarvaEntity).is_hungry():
			if not _is_entity_targeted_by_another_nurse(l as Node2D):
				return l as LarvaEntity
	return null

func _wander_in_chamber() -> void:
	nurse_wander_timer -= get_physics_process_delta_time()
	if nurse_wander_timer <= 0.0:
		nurse_wander_timer = randf_range(3.0, 7.0)
		var offset_pos: Vector2 = Vector2(976.0 + randf_range(-36.0, 36.0), 528.0 + randf_range(-14.0, 14.0))
		navigate_to(offset_pos)
		if path_waypoints.size() > 0:
			set_ant_state(Enums.AntState.TRAVELING_TO_TARGET)

func _apply_soft_separation(delta: float) -> void:
	var workers: Array = get_tree().get_nodes_in_group("workers")
	var push_vec: Vector2 = Vector2.ZERO
	var count: int = 0
	for other in workers:
		if other == self or not is_instance_valid(other) or not (other is AntController):
			continue
		var dist_sq: float = global_position.distance_squared_to((other as Node2D).global_position)
		if dist_sq < 144.0 and dist_sq > 0.01: # within 12 px
			var diff: Vector2 = global_position - (other as Node2D).global_position
			push_vec += diff.normalized() * (12.0 - sqrt(dist_sq))
			count += 1
			if count >= 3:
				break
	if count > 0:
		global_position += push_vec * 2.0 * delta

func _find_nearest_food_storage() -> Vector2:
	if GridManager != null:
		var store_coords: Array[Vector2i] = []
		for coord in GridManager.chambers.keys():
			if GridManager.chambers[coord] == Enums.ChamberType.FOOD_STORE:
				store_coords.append(coord)
		
		if store_coords.size() > 0:
			var best_pos: Vector2i = store_coords[0]
			var min_dist: float = global_position.distance_squared_to(GridManager.grid_to_world(best_pos))
			for sc in store_coords:
				var d: float = global_position.distance_squared_to(GridManager.grid_to_world(sc))
				if d < min_dist:
					min_dist = d
					best_pos = sc
			return GridManager.grid_to_world(best_pos)
	
	# Fallback to Royal Chamber center
	return Vector2(976.0, 528.0)


func _tick_defend() -> void:
	match state:
		Enums.AntState.IDLE:
			request_job_transition()
			if current_job != Enums.JobType.DEFEND:
				return
			
			var threat_mgr: Node = get_node_or_null("/root/ThreatManager")
			var best_threat: Node2D = null
			if threat_mgr != null:
				var threats: Array = threat_mgr.get("active_threats")
				var min_dist: float = 999999.0
				for t in threats:
					if is_instance_valid(t):
						var d: float = global_position.distance_squared_to(t.global_position)
						if d < min_dist:
							min_dist = d
							best_threat = t
			
			if best_threat != null:
				combat_target = best_threat
				navigate_to(best_threat.global_position)
				if path_waypoints.size() > 0:
					set_ant_state(Enums.AntState.TRAVELING_TO_TARGET)
			else:
				var patrol_pos: Vector2 = Vector2(976.0, 256.0)
				if global_position.distance_to(patrol_pos) > 32.0:
					navigate_to(patrol_pos)
					if path_waypoints.size() > 0:
						set_ant_state(Enums.AntState.TRAVELING_TO_TARGET)

		Enums.AntState.TRAVELING_TO_TARGET:
			if combat_target != null and is_instance_valid(combat_target):
				var dist: float = global_position.distance_to(combat_target.global_position)
				if dist <= 24.0:
					path_waypoints.clear()
					velocity = Vector2.ZERO
					set_ant_state(Enums.AntState.WORKING)
				else:
					move_along_path(get_physics_process_delta_time())
			else:
				var reached: bool = move_along_path(get_physics_process_delta_time())
				if reached:
					set_ant_state(Enums.AntState.IDLE)

		Enums.AntState.WORKING:
			if combat_target == null or not is_instance_valid(combat_target):
				combat_target = null
				set_ant_state(Enums.AntState.IDLE)
				return
			
			var dist: float = global_position.distance_to(combat_target.global_position)
			if dist > 36.0:
				navigate_to(combat_target.global_position)
				set_ant_state(Enums.AntState.TRAVELING_TO_TARGET)
				return
			
			velocity = Vector2.ZERO
			combat_attack_timer += get_physics_process_delta_time()
			if combat_attack_timer >= 0.8:
				combat_attack_timer = 0.0
				if combat_target.has_method("take_damage"):
					combat_target.call("take_damage", 6.0)


func take_damage(amount: float) -> void:
	health = maxf(0.0, health - amount)
	if health <= 0.0:
		carried_cargo = null
		if current_job != Enums.JobType.IDLE:
			TaskAllocationManager.unregister_ant(current_job)
		set_ant_state(Enums.AntState.DEAD)
		ant_died.emit(self)
		queue_free()

func update_job_visuals() -> void:
	var badge_color: Color = Color(0.8, 0.8, 0.8, 1.0)
	var tex_path: String = "res://assets/sprites_topdown/worker_forager.png"
	match current_job:
		Enums.JobType.FORAGE:
			badge_color = Color(0.55, 0.35, 0.17, 1.0) # Brown
			tex_path = "res://assets/sprites_topdown/worker_forager.png"
		Enums.JobType.DIG:
			badge_color = Color(0.9, 0.5, 0.13, 1.0) # Orange
			tex_path = "res://assets/sprites_topdown/worker_digger.png"
		Enums.JobType.NURSE:
			badge_color = Color(0.18, 0.8, 0.44, 1.0) # Green
			tex_path = "res://assets/sprites_topdown/worker_nurse.png"
		Enums.JobType.DEFEND:
			badge_color = Color(0.9, 0.3, 0.24, 1.0) # Red
			tex_path = "res://assets/sprites_topdown/worker_defender.png"
		_:
			badge_color = Color(0.7, 0.7, 0.7, 1.0)
	
	if job_badge != null:
		job_badge.color = badge_color
	if sprite != null:
		if ResourceLoader.exists(tex_path):
			sprite.texture = load(tex_path)
		sprite.modulate = Color.WHITE

func update_cargo_visuals() -> void:
	if cargo_node == null:
		return
	if carried_cargo == null:
		cargo_node.visible = false
	else:
		cargo_node.visible = true
		var cargo_rect: ColorRect = cargo_node.get_node_or_null("CargoColor") as ColorRect
		if cargo_rect != null:
			if str(carried_cargo) == "dirt":
				cargo_rect.color = Color(0.54, 0.35, 0.2, 1.0) # Dirt brown
			else:
				cargo_rect.color = Color(0.95, 0.76, 0.19, 1.0) # Food gold


func get_action_description() -> String:
	match current_job:
		Enums.JobType.FORAGE:
			match state:
				Enums.AntState.TRAVELING_TO_TARGET:
					if target_food_source != null and is_instance_valid(target_food_source):
						return "Heading to food (%s)" % target_food_source.source_name
					return "Walking to surface food"
				Enums.AntState.CARRYING_PAYLOAD:
					return "Carrying food to storage"
				Enums.AntState.IDLE:
					return "Searching for food on surface"
				_:
					return "Foraging"
		Enums.JobType.DIG:
			match state:
				Enums.AntState.WORKING:
					return "Digging block at (%d, %d)" % [target_cell.x, target_cell.y]
				Enums.AntState.TRAVELING_TO_TARGET:
					return "Heading to dig site (%d, %d)" % [target_cell.x, target_cell.y]
				Enums.AntState.IDLE:
					return "Waiting for dig orders"
				_:
					return "Digging"
		Enums.JobType.NURSE:
			match state:
				Enums.AntState.TRAVELING_TO_TARGET:
					return "Fetching food from storage"
				Enums.AntState.CARRYING_PAYLOAD:
					if target_feed_entity is QueenController:
						return "Feeding the Queen"
					elif target_feed_entity is LarvaEntity:
						return "Feeding larva #%d" % (target_feed_entity as LarvaEntity).larva_id
					return "Delivering food in nursery"
				Enums.AntState.IDLE:
					return "Tending to nursery and eggs"
				_:
					return "Nursing"
		Enums.JobType.DEFEND:
			match state:
				Enums.AntState.WORKING:
					return "Attacking intruder!"
				Enums.AntState.TRAVELING_TO_TARGET:
					return "Intercepting threat"
				Enums.AntState.IDLE:
					return "Guarding nest entrance"
				_:
					return "On patrol"
		_:
			return "Resting in chamber"
