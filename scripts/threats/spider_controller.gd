class_name SpiderController
extends CharacterBody2D

# Fast surface predator that ambushes foragers on the grass and flees when wounded or satisfied.

@export var health: float = 30.0
@export var attack_damage: float = 12.0
@export var move_speed: float = 60.0

var detection_radius: float = 180.0
var is_fleeing: bool = false
var patrol_dir: float = 1.0
var flash_timer: float = 0.0
var target_forager: AntController = null

@onready var sprite: Sprite2D = $Sprite2D

func _physics_process(delta: float) -> void:
	if GameManager.game_state == Enums.GameState.RUNNING:
		if is_fleeing:
			_process_flee(delta)
		elif target_forager != null and is_instance_valid(target_forager):
			ambush_forager(target_forager)
		else:
			patrol_surface(delta)
	
	if flash_timer > 0.0:
		flash_timer -= delta
		if sprite != null:
			sprite.modulate = Color(1.0, 0.3, 0.3, 1.0)
	elif sprite != null:
		sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)

func patrol_surface(delta: float) -> void:
	# Scan for nearest forager on the surface (Y < 250)
	var main_node: Node = get_tree().current_scene
	var ants_container: Node2D = main_node.get_node_or_null("Ants") as Node2D if main_node != null else null
	if ants_container != null:
		var closest_dist: float = detection_radius
		for ant_child in ants_container.get_children():
			if ant_child is AntController:
				var a: AntController = ant_child as AntController
				if a.global_position.y <= 256.0 and a.health > 0:
					var d: float = global_position.distance_to(a.global_position)
					if d < closest_dist:
						closest_dist = d
						target_forager = a
						return

	# Normal surface patrol
	velocity = Vector2(patrol_dir * move_speed * 0.5, 0.0)
	move_and_slide()
	
	if global_position.x > 1850.0:
		patrol_dir = -1.0
	elif global_position.x < 100.0:
		patrol_dir = 1.0

	if sprite != null:
		sprite.flip_h = (patrol_dir < 0.0)

func ambush_forager(ant: AntController) -> void:
	if ant == null or not is_instance_valid(ant) or ant.health <= 0:
		target_forager = null
		return
	
	var dir: Vector2 = (ant.global_position - global_position).normalized()
	velocity = dir * move_speed
	move_and_slide()
	
	if sprite != null:
		sprite.flip_h = (dir.x < 0.0)
	
	# Attack if close
	if global_position.distance_to(ant.global_position) <= 16.0:
		ant.take_damage(attack_damage)
		# Spider retreats off-screen after killing 1 ant or striking
		target_forager = null
		flee_surface()

func flee_surface() -> void:
	is_fleeing = true
	target_forager = null
	# Flee towards closest off-screen border
	patrol_dir = -1.0 if global_position.x < 960.0 else 1.0

func _process_flee(delta: float) -> void:
	velocity = Vector2(patrol_dir * move_speed * 1.3, 0.0)
	move_and_slide()
	if sprite != null:
		sprite.flip_h = (patrol_dir < 0.0)
	
	if global_position.x < -120.0 or global_position.x > 2150.0:
		var threat_mgr: Node = get_node_or_null("/root/ThreatManager")
		if threat_mgr != null and threat_mgr.has_method("unregister_threat"):
			threat_mgr.call("unregister_threat", self)
		queue_free()

func take_damage(amount: float) -> void:
	health = maxf(0.0, health - amount)
	flash_timer = 0.25
	# Retreat immediately when attacked by defender ants
	if not is_fleeing:
		flee_surface()
	
	if health <= 0.0:
		var threat_mgr: Node = get_node_or_null("/root/ThreatManager")
		if threat_mgr != null and threat_mgr.has_method("unregister_threat"):
			threat_mgr.call("unregister_threat", self)
		queue_free()
