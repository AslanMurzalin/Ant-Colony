extends Node

# Autoload: GameManager
# Oversees the run lifecycle, day-night progression, game speed, win/lose evaluation, and deterministic seed management.

signal day_started(day_number: int)
signal day_time_updated(elapsed_ratio: float)
signal day_progress_ticked(elapsed_ratio: float)   ## alias used by TopBarHUD
signal day_ended(day_number: int, stats: Dictionary)
signal game_speed_changed(new_speed: float)
signal game_over(reason: String)
signal game_won(rating: String, final_stats: Dictionary)
signal ant_count_changed(alive: int, maximum: int)

var current_day: int = 1
var day_duration_seconds: float = 150.0
var day_timer: float = 0.0
var game_state: Enums.GameState = Enums.GameState.NOT_STARTED
var simulation_speed: float = 1.0
var run_seed: int = 0
var total_workers_alive: int = 0
var ants_born_today: int = 0
var ants_lost_today: int = 0
var food_gathered_today: int = 0
var next_ant_id: int = 1

func _ready() -> void:
	pass

func get_next_ant_id() -> int:
	var assigned_id: int = next_ant_id
	next_ant_id += 1
	return assigned_id

func _process(delta: float) -> void:
	if game_state == Enums.GameState.RUNNING:
		day_timer += delta
		var elapsed_ratio: float = clampf(day_timer / day_duration_seconds, 0.0, 1.0)
		day_time_updated.emit(elapsed_ratio)
		day_progress_ticked.emit(elapsed_ratio)
		if day_timer >= day_duration_seconds:
			advance_day()

func start_new_run(optional_seed: int = -1) -> void:
	if optional_seed == -1:
		randomize()
		run_seed = randi()
	else:
		run_seed = optional_seed
	seed(run_seed)

	current_day = 1
	day_timer = 0.0
	total_workers_alive = 0
	next_ant_id = 1
	ants_born_today = 0
	ants_lost_today = 0
	food_gathered_today = 0
	game_state = Enums.GameState.RUNNING
	set_game_speed(1.0)
	if ResourceManager != null and ResourceManager.has_method("reset_food"):
		ResourceManager.reset_food()
	day_started.emit(current_day)

func set_game_speed(multiplier: float) -> void:
	simulation_speed = multiplier
	if simulation_speed <= 0.0:
		Engine.time_scale = 0.0
	else:
		Engine.time_scale = simulation_speed
		# При сверхвысоких скоростях (4x, 8x) выделяем запас шагов физики на кадр,
		# чтобы симуляция муравьёв, копания и перемещений не пропускала тики при просадке кадров.
		if simulation_speed >= 8.0:
			Engine.max_physics_steps_per_frame = 16
		elif simulation_speed >= 4.0:
			Engine.max_physics_steps_per_frame = 12
		else:
			Engine.max_physics_steps_per_frame = 8
	game_speed_changed.emit(simulation_speed)

func advance_day() -> void:
	game_state = Enums.GameState.DAY_SUMMARY
	var summary_stats: Dictionary = {
		"day": current_day,
		"ants_born": ants_born_today,
		"ants_lost": ants_lost_today,
		"food_gathered": food_gathered_today,
		"total_workers": total_workers_alive
	}
	day_ended.emit(current_day, summary_stats)
	check_win_lose_conditions()

func start_next_day() -> void:
	current_day += 1
	day_timer = 0.0
	ants_born_today = 0
	ants_lost_today = 0
	food_gathered_today = 0
	game_state = Enums.GameState.RUNNING
	day_started.emit(current_day)

func check_win_lose_conditions() -> void:
	if current_day > 10 and game_state != Enums.GameState.DEFEAT:
		trigger_victory()

func trigger_defeat(reason: String) -> void:
	game_state = Enums.GameState.DEFEAT
	set_game_speed(0.0)
	game_over.emit(reason)

func trigger_victory() -> void:
	game_state = Enums.GameState.VICTORY
	set_game_speed(0.0)
	var rating: String = calculate_end_rating()
	var final_stats: Dictionary = {
		"days_survived": current_day,
		"total_workers": total_workers_alive,
		"rating": rating
	}
	game_won.emit(rating, final_stats)

func calculate_end_rating() -> String:
	if total_workers_alive >= 36:
		return "Thriving"
	elif total_workers_alive >= 15:
		return "Healthy"
	else:
		return "Fledgling"


## Called by NurseryManager when a new ant hatches.
func register_ant_born() -> void:
	total_workers_alive += 1
	ants_born_today += 1
	ant_count_changed.emit(total_workers_alive, 50)


## Called by AntController on death.
func register_ant_died() -> void:
	total_workers_alive = max(0, total_workers_alive - 1)
	ants_lost_today += 1
	ant_count_changed.emit(total_workers_alive, 50)
