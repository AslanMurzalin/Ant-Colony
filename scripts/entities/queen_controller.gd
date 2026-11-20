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
	current_health = max_health
	hunger_timer = hunger_interval
	egg_laying_timer = egg_laying_interval
	if health_bar != null:
		health_bar.max_value = max_health
		health_bar.value = current_health
	queen_health_changed.emit(current_health, max_health)

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
	if not is_starving and GameManager.total_workers_alive < 50:
		queen_laid_egg.emit()
