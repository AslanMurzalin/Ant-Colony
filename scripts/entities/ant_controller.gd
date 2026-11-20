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

@onready var sprite: Sprite2D = $Sprite2D
@onready var job_badge: ColorRect = $JobBadge
@onready var cargo_node: Node2D = $CargoNode

func _ready() -> void:
	update_job_visuals()
	update_cargo_visuals()

func _physics_process(delta: float) -> void:
	if GameManager.game_state == Enums.GameState.RUNNING:
		execute_job_behavior(delta)
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
	if path_waypoints.size() > 0:
		current_target_pos = path_waypoints[0]

func move_along_path(delta: float) -> bool:
	if current_path_index >= path_waypoints.size():
		velocity = Vector2.ZERO
		return true

	var target_wp: Vector2 = path_waypoints[current_path_index]
	var dist: float = global_position.distance_to(target_wp)
	
	if dist <= 4.0:
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
						# If no path, stay idle
						pass

		Enums.AntState.TRAVELING_TO_TARGET:
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
					set_ant_state(Enums.AntState.WORKING)

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
	if state == Enums.AntState.IDLE:
		request_job_transition()

func _tick_nurse() -> void:
	if state == Enums.AntState.IDLE:
		request_job_transition()

func _tick_defend() -> void:
	if state == Enums.AntState.IDLE:
		request_job_transition()

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
	match current_job:
		Enums.JobType.FORAGE:
			badge_color = Color(0.55, 0.35, 0.17, 1.0) # Brown
		Enums.JobType.DIG:
			badge_color = Color(0.9, 0.5, 0.13, 1.0) # Orange
		Enums.JobType.NURSE:
			badge_color = Color(0.18, 0.8, 0.44, 1.0) # Green
		Enums.JobType.DEFEND:
			badge_color = Color(0.9, 0.3, 0.24, 1.0) # Red
		_:
			badge_color = Color(0.7, 0.7, 0.7, 1.0)
	
	if job_badge != null:
		job_badge.color = badge_color
	if sprite != null:
		sprite.modulate = badge_color

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
