class_name TopBarHUD
extends Control

## Top Bar HUD — shows Day, progress bar, Food, Ants, Queen HP, and speed buttons.
## Space toggles pause. Buttons set game speed 0x/1x/2x.

const SPEED_PAUSE: float = 0.0
const SPEED_1X:    float = 1.0
const SPEED_2X:    float = 2.0

@onready var _day_label:       Label       = $HBoxContainer/DayLabel
@onready var _day_bar:         ProgressBar = $HBoxContainer/DayBar
@onready var _food_label:      Label       = $HBoxContainer/FoodLabel
@onready var _ants_label:      Label       = $HBoxContainer/AntsLabel
@onready var _queen_hp_bar:    ProgressBar = $HBoxContainer/QueenHPBar
@onready var _btn_pause:       Button      = $HBoxContainer/SpeedButtons/BtnPause
@onready var _btn_1x:          Button      = $HBoxContainer/SpeedButtons/Btn1x
@onready var _btn_2x:          Button      = $HBoxContainer/SpeedButtons/Btn2x


func _ready() -> void:
	GameManager.connect("day_started",        _on_day_started)
	GameManager.connect("day_progress_ticked", _on_day_progress)
	ResourceManager.connect("food_changed",   _on_food_changed)
	GameManager.connect("ant_count_changed",  _on_ant_count_changed)

	_btn_pause.connect("pressed", func() -> void: _set_speed(SPEED_PAUSE))
	_btn_1x.connect("pressed",   func() -> void: _set_speed(SPEED_1X))
	_btn_2x.connect("pressed",   func() -> void: _set_speed(SPEED_2X))

	_refresh_all()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_SPACE:
			_toggle_pause()


# ── Speed ────────────────────────────────────────────────────────────────────

func _set_speed(speed: float) -> void:
	GameManager.set_game_speed(speed)
	_update_speed_buttons(speed)


func _toggle_pause() -> void:
	var current: float = Engine.time_scale
	var next: float = SPEED_PAUSE if current > 0.0 else SPEED_1X
	_set_speed(next)


func _update_speed_buttons(speed: float) -> void:
	_btn_pause.modulate = Color.WHITE if speed == SPEED_PAUSE else Color(0.6, 0.6, 0.6)
	_btn_1x.modulate    = Color.WHITE if speed == SPEED_1X    else Color(0.6, 0.6, 0.6)
	_btn_2x.modulate    = Color.WHITE if speed == SPEED_2X    else Color(0.6, 0.6, 0.6)


# ── Signal handlers ──────────────────────────────────────────────────────────

func _on_day_started(day: int) -> void:
	_day_label.text = "Day %d / 10" % day
	_day_bar.value = 0.0


func _on_day_progress(pct: float) -> void:
	_day_bar.value = pct * 100.0
	# Refresh Queen HP each progress tick (cheap)
	_refresh_queen_hp()


func _on_food_changed(current: int, capacity: int) -> void:
	_food_label.text = "Food: %d / %d" % [current, capacity]


func _on_ant_count_changed(alive: int, _max: int) -> void:
	_ants_label.text = "Ants: %d / 50" % alive


# ── Refresh helpers ──────────────────────────────────────────────────────────

func _refresh_all() -> void:
	_day_label.text   = "Day %d / 10" % GameManager.current_day
	_day_bar.value    = 0.0
	_food_label.text  = "Food: %d / %d" % [ResourceManager.stored_food, ResourceManager.food_capacity]
	_ants_label.text  = "Ants: %d / 50" % GameManager.total_workers_alive
	_refresh_queen_hp()
	_update_speed_buttons(Engine.time_scale)


func _refresh_queen_hp() -> void:
	# Retrieve queen node from group "queen"
	var queens: Array = get_tree().get_nodes_in_group("queen")
	if queens.is_empty():
		_queen_hp_bar.value = 100.0
		return
	var queen: Node = queens[0]
	if queen.has_method("get_health_pct"):
		_queen_hp_bar.value = queen.get_health_pct() * 100.0
