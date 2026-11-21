class_name TopBarHUD
extends Control

## Top Bar HUD — shows Day, progress bar, Food, Ants, Queen HP, and speed buttons.
## Space toggles pause. Buttons set game speed 0x/1x/2x.

signal roster_toggled()

const SPEED_PAUSE: float = 0.0
const SPEED_1X:    float = 1.0
const SPEED_2X:    float = 2.0

@onready var _day_label:       Label       = $PanelContainer/HBoxContainer/DayLabel
@onready var _day_bar:         ProgressBar = $PanelContainer/HBoxContainer/DayBar
@onready var _food_label:      Label       = $PanelContainer/HBoxContainer/FoodLabel
@onready var _ants_label:      Label       = $PanelContainer/HBoxContainer/AntsLabel
@onready var _queen_hp_bar:    ProgressBar = $PanelContainer/HBoxContainer/QueenHPBar
@onready var _btn_pause:       Button      = $PanelContainer/HBoxContainer/SpeedButtons/BtnPause
@onready var _btn_1x:          Button      = $PanelContainer/HBoxContainer/SpeedButtons/Btn1x
@onready var _btn_2x:          Button      = $PanelContainer/HBoxContainer/SpeedButtons/Btn2x
@onready var _btn_roster:      Button      = $PanelContainer/HBoxContainer/BtnRoster


func _ready() -> void:
	GameManager.connect("day_started",        _on_day_started)
	GameManager.connect("day_progress_ticked", _on_day_progress)
	ResourceManager.connect("food_changed",   _on_food_changed)
	GameManager.connect("ant_count_changed",  _on_ant_count_changed)
	TaskAllocationManager.connect("quotas_updated", func() -> void:
		_update_ants_label()
	)

	_btn_pause.connect("pressed", func() -> void: _set_speed(SPEED_PAUSE))
	_btn_1x.connect("pressed",   func() -> void: _set_speed(SPEED_1X))
	_btn_2x.connect("pressed",   func() -> void: _set_speed(SPEED_2X))
	if _btn_roster != null:
		_btn_roster.connect("pressed", _on_roster_pressed)

	_refresh_all()


func _on_roster_pressed() -> void:
	roster_toggled.emit()


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
	_update_ants_label(alive)

func _update_ants_label(alive: int = -1) -> void:
	if alive < 0:
		alive = GameManager.total_workers_alive
	var pinned: int = TaskAllocationManager.get_pinned_ant_count()
	if pinned > 0:
		_ants_label.text = "Ants: %d / 50 (📌%d)" % [alive, pinned]
	else:
		_ants_label.text = "Ants: %d / 50" % alive

# ── Refresh helpers ──────────────────────────────────────────────────────────

func _refresh_all() -> void:
	_day_label.text   = "Day %d / 10" % GameManager.current_day
	_day_bar.value    = 0.0
	_food_label.text  = "Food: %d / %d" % [ResourceManager.stored_food, ResourceManager.food_capacity]
	_update_ants_label(GameManager.total_workers_alive)
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
