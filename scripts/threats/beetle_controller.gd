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

	# Check or re-evaluate target
	if current_target == null or not is_instance_valid(current_target):
		current_target = find_highest_priority_target()
		if current_target != null:
			_navigate_to_target(current_target.global_position)

	if current_target != null and is_instance_valid(current_target):
		var dist: float = global_position.distance_to(current_target.global_position)
		if dist <= 28.0:
			# Within attack range
			velocity = Vector2.ZERO
			if attack_timer <= 0.0:
				attack_target(current_target, delta)
				attack_timer = attack_cooldown
		else:
			# Advance towards target
			_move_along_path(delta)

func find_highest_priority_target() -> Node2D:
	var main_node: Node = get_tree().current_scene
	if main_node == null:
		return null
	
	# 1. Queen (Ultimate objective)
	var queen: QueenController = main_node.get_node_or_null("Queen") as QueenController
	
	# If beetle is underground, targets Queen
	if global_position.y > 270.0:
		if queen != null and queen.current_health > 0:
			return queen
	
	# If near surface, moves toward entrance shaft (Col 30, row 8: 976, 256)
	return queen

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
	
	# Beetle tunnels through or uses excavated paths
	path_waypoints = GridManager.get_world_path(start_grid, end_grid)
	current_path_index = 0

func _move_along_path(delta: float) -> void:
	if path_waypoints.is_empty() or current_path_index >= path_waypoints.size():
		if current_target != null:
			var dir: Vector2 = (current_target.global_position - global_position).normalized()
			velocity = dir * move_speed
			move_and_slide()
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
	if sprite != null and abs(dir.x) > 0.1:
		sprite.flip_h = (dir.x < 0.0)

func take_damage(amount: float) -> void:
	health = maxf(0.0, health - amount)
	flash_timer = 0.2
	if health <= 0.0:
		var threat_mgr: Node = get_node_or_null("/root/ThreatManager")
		if threat_mgr != null and threat_mgr.has_method("unregister_threat"):
			threat_mgr.call("unregister_threat", self)
		queue_free()
