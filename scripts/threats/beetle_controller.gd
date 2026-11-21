class_name BeetleController
extends CharacterBody2D

# Heavy armored subterranean intruder that tunnels toward food stores and the royal chamber.

@export var health: float = 80.0
@export var attack_damage: float = 8.0
@export var move_speed: float = 18.0

var target_priority: Array[Node2D] = []
var attack_cooldown: float = 1.0
var attack_timer: float = 0.0
var flash_timer: float = 0.0
var path_waypoints: Array[Vector2] = []
var current_path_index: int = 0
var current_target: Node2D = null
var repath_timer: float = 0.0

const ENTRANCE_X: float = 976.0
const SURFACE_Y: float = 228.0
const UNDERGROUND_Y: float = 256.0

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	pass

func _physics_process(delta: float) -> void:
	if GameManager.game_state == Enums.GameState.RUNNING:
		_process_beetle_behavior(delta)
	
	if flash_timer > 0.0:
		flash_timer -= delta
		if sprite != null:
			sprite.modulate = Color(1.0, 0.4, 0.4, 1.0)
	elif sprite != null:
		sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)

func _process_beetle_behavior(delta: float) -> void:
	if attack_timer > 0.0:
		attack_timer -= delta

	# 1. Surface stage: walk along surface grass toward anthill entrance
	if global_position.y < UNDERGROUND_Y - 4.0:
		global_position.y = SURFACE_Y
		var x_dist: float = ENTRANCE_X - global_position.x
		if absf(x_dist) > 8.0:
			var dir_x: float = signf(x_dist)
			velocity = Vector2(dir_x * move_speed, 0.0)
			move_and_slide()
			if sprite != null and absf(dir_x) > 0.1:
				sprite.flip_h = (dir_x < 0.0)

			# Check for surface ants to attack
			var target_ant: Node2D = find_highest_priority_target()
			if target_ant != null and global_position.distance_to(target_ant.global_position) <= 24.0:
				if attack_timer <= 0.0:
					attack_target(target_ant, delta)
					attack_timer = attack_cooldown
		else:
			# Enter underground tunnel entrance
			global_position = Vector2(ENTRANCE_X, UNDERGROUND_Y)
			velocity = Vector2.ZERO
			path_waypoints.clear()
			current_path_index = 0
			repath_timer = 0.0
		return

	# 2. Underground stage: strictly navigate through excavated tunnels
	repath_timer -= delta

	current_target = find_highest_priority_target()
	if current_target != null and is_instance_valid(current_target):
		var dist: float = global_position.distance_to(current_target.global_position)
		if dist <= 28.0:
			# Within attack range
			velocity = Vector2.ZERO
			if attack_timer <= 0.0:
				attack_target(current_target, delta)
				attack_timer = attack_cooldown
			return

	if repath_timer <= 0.0 or path_waypoints.is_empty() or current_path_index >= path_waypoints.size():
		repath_timer = 1.0
		if current_target != null:
			_navigate_to_target(current_target.global_position)

	_move_along_path(delta)

func find_highest_priority_target() -> Node2D:
	# Priority 1: Nearby defending ants within 48 px
	var nearby_workers: Array = get_tree().get_nodes_in_group("workers")
	var best_ant: AntController = null
	var min_ant_dist: float = 48.0
	for w in nearby_workers:
		if is_instance_valid(w) and w is AntController:
			var d: float = global_position.distance_to((w as AntController).global_position)
			if d < min_ant_dist:
				min_ant_dist = d
				best_ant = w as AntController
	if best_ant != null:
		return best_ant

	# Priority 2: Queen (Primary subterranean target)
	var main_node: Node = get_tree().current_scene
	if main_node != null:
		var queen: QueenController = main_node.get_node_or_null("Queen") as QueenController
		if queen != null and queen.current_health > 0.0:
			return queen

	return null

func attack_target(target: Node2D, delta: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	
	if target is QueenController:
		(target as QueenController).take_damage(attack_damage)
	elif target is AntController:
		(target as AntController).take_damage(attack_damage)

func _navigate_to_target(target_world_pos: Vector2) -> void:
	if GridManager == null:
		return
	var start_grid: Vector2i = GridManager.world_to_grid(global_position)
	var end_grid: Vector2i = GridManager.world_to_grid(target_world_pos)
	
	if not GridManager.is_valid_coord(start_grid) or not GridManager.is_valid_coord(end_grid):
		return

	path_waypoints = GridManager.get_world_path(start_grid, end_grid)
	current_path_index = 0
	if path_waypoints.size() > 0 and path_waypoints[0].distance_to(global_position) < 8.0:
		current_path_index = 1

func _move_along_path(delta: float) -> void:
	if path_waypoints.is_empty() or current_path_index >= path_waypoints.size():
		velocity = Vector2.ZERO
		return
	
	var target_wp: Vector2 = path_waypoints[current_path_index]
	var dist: float = global_position.distance_to(target_wp)
	if dist <= 6.0:
		current_path_index += 1
		if current_path_index >= path_waypoints.size():
			velocity = Vector2.ZERO
			return
		target_wp = path_waypoints[current_path_index]
	
	var dir: Vector2 = (target_wp - global_position).normalized()
	velocity = dir * move_speed
	move_and_slide()
	if sprite != null and absf(dir.x) > 0.1:
		sprite.flip_h = (dir.x < 0.0)

func take_damage(amount: float) -> void:
	health = maxf(0.0, health - amount)
	flash_timer = 0.2
	if health <= 0.0:
		var threat_mgr: Node = get_node_or_null("/root/ThreatManager")
		if threat_mgr != null and threat_mgr.has_method("unregister_threat"):
			threat_mgr.call("unregister_threat", self)
		queue_free()
