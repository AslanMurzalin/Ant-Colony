class_name QueenController
extends Node2D

# Anchored in the Royal Chamber. Serves as the primary win/lose condition and lays eggs.

signal queen_health_changed(current: float, maximum: float)
signal queen_laid_egg()
signal queen_damaged(damage_amount: float)
signal queen_starvation_started()
signal queen_starvation_ended()

@export var max_health: float = 100.0
var current_health: float = 100.0
var hunger_timer: float = 15.0
var hunger_interval: float = 15.0
var egg_laying_timer: float = 20.0
var egg_laying_interval: float = 20.0
var is_starving: bool = false
var starvation_damage_rate: float = 2.0
var distress_timer: float = 0.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var health_bar: ProgressBar = $HealthBar

func _ready() -> void:
	add_to_group("queen")
	current_health = max_health
	hunger_timer = hunger_interval
	egg_laying_timer = egg_laying_interval
	queue_redraw()
	if health_bar != null:
		health_bar.max_value = max_health
		health_bar.value = current_health
	queen_health_changed.emit(current_health, max_health)

func _draw() -> void:
	# Органическая подстилка гнезда (листья и почва) под королевой как на референсе
	draw_set_transform(Vector2(0.0, 8.0), 0.0, Vector2(1.85, 0.95))
	draw_circle(Vector2.ZERO, 38.0, Color(0.28, 0.20, 0.12, 0.85))
	draw_circle(Vector2.ZERO, 34.0, Color(0.42, 0.32, 0.18, 0.90))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _process(delta: float) -> void:
	if GameManager.game_state == Enums.GameState.RUNNING:
		_process_queen_logic(delta)
	_update_visuals(delta)

func _process_queen_logic(delta: float) -> void:
	hunger_timer -= delta
	if hunger_timer <= 0.0:
		if not is_starving:
			is_starving = true
			queen_starvation_started.emit()
		tick_starvation(delta)
	
	if not is_starving:
		egg_laying_timer -= delta
		if egg_laying_timer <= 0.0:
			attempt_lay_egg()
			egg_laying_timer = egg_laying_interval

func _update_visuals(delta: float) -> void:
	if distress_timer > 0.0:
		distress_timer -= delta
		modulate = Color(1.0, 0.4, 0.4, 1.0)
	elif is_starving:
		var blink: float = 0.7 + 0.3 * sin(Time.get_ticks_msec() * 0.01)
		modulate = Color(1.0, blink, blink, 1.0)
	else:
		modulate = Color(1.0, 1.0, 1.0, 1.0)
	
	# Subtle breathing animation
	var breath: float = 1.0 + 0.03 * sin(Time.get_ticks_msec() * 0.003)
	scale = Vector2(breath, breath)

func feed_queen(amount: int) -> bool:
	if amount <= 0:
		return false
	hunger_timer = hunger_interval
	if is_starving:
		is_starving = false
		queen_starvation_ended.emit()
	current_health = minf(max_health, current_health + 10.0 * float(amount))
	if health_bar != null:
		health_bar.value = current_health
	queen_health_changed.emit(current_health, max_health)
	return true

func take_damage(amount: float) -> void:
	if amount <= 0.0 or current_health <= 0.0:
		return
	current_health = maxf(0.0, current_health - amount)
	distress_timer = 0.5
	if health_bar != null:
		health_bar.value = current_health
	queen_damaged.emit(amount)
	queen_health_changed.emit(current_health, max_health)
	if current_health <= 0.0:
		GameManager.trigger_defeat("Queen died of combat injuries!")

func tick_starvation(delta: float) -> void:
	if current_health <= 0.0:
		return
	var damage: float = starvation_damage_rate * delta
	current_health = maxf(0.0, current_health - damage)
	if health_bar != null:
		health_bar.value = current_health
	queen_damaged.emit(damage)
	queen_health_changed.emit(current_health, max_health)
	if current_health <= 0.0:
		GameManager.trigger_defeat("Queen died of starvation!")

func attempt_lay_egg() -> void:
	if is_starving or GameManager.total_workers_alive >= 50:
		return
	
	# Colony law: Queen cannot birth more ants unless stored food exceeds 50% capacity
	if ResourceManager != null and ResourceManager.get_max_capacity() > 0:
		var food_ratio: float = float(ResourceManager.stored_food) / float(ResourceManager.get_max_capacity())
		if food_ratio <= 0.5:
			return

	queen_laid_egg.emit()
	var spawn_pos: Vector2 = global_position + Vector2(randf_range(-24.0, 24.0), 12.0)
	var nursery = get_node_or_null("/root/NurseryManager")
	if nursery != null and nursery.has_method("spawn_egg"):
		nursery.spawn_egg(spawn_pos)


## Returns current health as 0.0–1.0 ratio for HUD display.
func get_health_pct() -> float:
	if max_health <= 0.0:
		return 0.0
	return clampf(current_health / max_health, 0.0, 1.0)
