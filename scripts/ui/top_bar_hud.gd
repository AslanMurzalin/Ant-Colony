class_name TopBarHUD
extends Control

## Top Bar HUD — стилизованная панель antcolony.gg (#1A1512).
## Отображает Day, Food, Population, Queen HP, кнопки скорости и кнопку Roster.

signal roster_toggled()

const SPEED_PAUSE: float = 0.0
const SPEED_1X:    float = 1.0
const SPEED_2X:    float = 2.0
const SPEED_4X:    float = 4.0
const SPEED_8X:    float = 8.0

const COLOR_GOLD_ACCENT: Color = Color(0.949, 0.659, 0.114, 1.0) # #F2A81D
const COLOR_DARK_BG: Color     = Color(0.102, 0.082, 0.071, 1.0) # #1A1512
const COLOR_BUTTON_BG: Color   = Color(0.150, 0.120, 0.100, 1.0) # #261F1A
const COLOR_BUTTON_TEXT: Color = Color(0.850, 0.800, 0.750, 1.0)

var _previous_speed: float = SPEED_1X

@onready var _day_label:       Label       = $PanelContainer/HBoxContainer/DayBlock/DayLabel
@onready var _day_bar:         ProgressBar = $PanelContainer/HBoxContainer/DayBlock/DayBar
@onready var _food_label:      Label       = $PanelContainer/HBoxContainer/FoodBlock/FoodLabel
@onready var _ants_label:      Label       = $PanelContainer/HBoxContainer/AntsBlock/AntsLabel
@onready var _queen_label:     Label       = $PanelContainer/HBoxContainer/QueenBlock/QueenLabel
@onready var _queen_hp_bar:    ProgressBar = $PanelContainer/HBoxContainer/QueenBlock/QueenHPBar
@onready var _btn_pause:       Button      = $PanelContainer/HBoxContainer/SpeedButtons/BtnPause
@onready var _btn_1x:          Button      = $PanelContainer/HBoxContainer/SpeedButtons/Btn1x
@onready var _btn_2x:          Button      = $PanelContainer/HBoxContainer/SpeedButtons/Btn2x
@onready var _btn_4x:          Button      = $PanelContainer/HBoxContainer/SpeedButtons/Btn4x
@onready var _btn_8x:          Button      = $PanelContainer/HBoxContainer/SpeedButtons/Btn8x
@onready var _btn_roster:      Button      = $PanelContainer/HBoxContainer/BtnRoster


func _ready() -> void:
	GameManager.connect("day_started",        _on_day_started)
	GameManager.connect("day_progress_ticked", _on_day_progress)
	ResourceManager.connect("food_changed",   _on_food_changed)
	GameManager.connect("ant_count_changed",  _on_ant_count_changed)
	TaskAllocationManager.connect("quotas_updated", func() -> void:
		_update_ants_label()
	)

	_btn_pause.connect("pressed", func() -> void: _toggle_pause())
	_btn_1x.connect("pressed",   func() -> void: _set_speed(SPEED_1X))
	_btn_2x.connect("pressed",   func() -> void: _set_speed(SPEED_2X))
	if _btn_4x != null:
		_btn_4x.connect("pressed", func() -> void: _set_speed(SPEED_4X))
	if _btn_8x != null:
		_btn_8x.connect("pressed", func() -> void: _set_speed(SPEED_8X))
	if _btn_roster != null:
		_btn_roster.connect("pressed", _on_roster_pressed)
		_style_roster_button()

	_refresh_all()


func _style_roster_button() -> void:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = COLOR_BUTTON_BG
	sb.border_color = COLOR_GOLD_ACCENT
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_right = 4
	sb.corner_radius_bottom_left = 4
	_btn_roster.add_theme_stylebox_override("normal", sb)
	_btn_roster.add_theme_stylebox_override("hover", sb)
	_btn_roster.add_theme_color_override("font_color", COLOR_GOLD_ACCENT)


func _on_roster_pressed() -> void:
	roster_toggled.emit()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key_event: InputEventKey = event as InputEventKey
		if key_event.keycode == KEY_SPACE:
			_toggle_pause()
			get_viewport().set_input_as_handled()
		elif key_event.keycode == KEY_F1 or key_event.keycode == KEY_KP_1 or (key_event.keycode == KEY_1 and key_event.shift_pressed):
			_set_speed(SPEED_1X)
			get_viewport().set_input_as_handled()
		elif key_event.keycode == KEY_F2 or key_event.keycode == KEY_KP_2 or (key_event.keycode == KEY_2 and key_event.shift_pressed):
			_set_speed(SPEED_2X)
			get_viewport().set_input_as_handled()
		elif key_event.keycode == KEY_F3 or key_event.keycode == KEY_KP_3 or (key_event.keycode == KEY_3 and key_event.shift_pressed):
			_set_speed(SPEED_4X)
			get_viewport().set_input_as_handled()
		elif key_event.keycode == KEY_F4 or key_event.keycode == KEY_KP_4 or (key_event.keycode == KEY_4 and key_event.shift_pressed):
			_set_speed(SPEED_8X)
			get_viewport().set_input_as_handled()


# ── Speed ────────────────────────────────────────────────────────────────────

func _set_speed(speed: float) -> void:
	if speed > 0.0:
		_previous_speed = speed
	GameManager.set_game_speed(speed)
	_update_speed_buttons(speed)


func _toggle_pause() -> void:
	var current: float = Engine.time_scale
	if current > 0.0:
		_previous_speed = current
		_set_speed(SPEED_PAUSE)
	else:
		var resume_speed: float = _previous_speed if _previous_speed > 0.0 else SPEED_1X
		_set_speed(resume_speed)


func _update_speed_buttons(speed: float) -> void:
	_apply_speed_style(_btn_pause, is_equal_approx(speed, SPEED_PAUSE))
	_apply_speed_style(_btn_1x,    is_equal_approx(speed, SPEED_1X))
	_apply_speed_style(_btn_2x,    is_equal_approx(speed, SPEED_2X))
	_apply_speed_style(_btn_4x,    is_equal_approx(speed, SPEED_4X))
	_apply_speed_style(_btn_8x,    is_equal_approx(speed, SPEED_8X))


func _apply_speed_style(btn: Button, is_active: bool) -> void:
	if btn == null:
		return
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_right = 4
	sb.corner_radius_bottom_left = 4
	
	if is_active:
		sb.bg_color = COLOR_GOLD_ACCENT
		btn.add_theme_color_override("font_color", COLOR_DARK_BG)
		btn.add_theme_color_override("font_hover_color", COLOR_DARK_BG)
	else:
		sb.bg_color = COLOR_BUTTON_BG
		sb.border_color = Color(0.24, 0.18, 0.14, 1.0)
		sb.border_width_left = 1
		sb.border_width_top = 1
		sb.border_width_right = 1
		sb.border_width_bottom = 1
		btn.add_theme_color_override("font_color", COLOR_BUTTON_TEXT)
		btn.add_theme_color_override("font_hover_color", Color.WHITE)
		
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", sb)
	btn.add_theme_stylebox_override("pressed", sb)


# ── Signal handlers ──────────────────────────────────────────────────────────

func _on_day_started(day: int) -> void:
	_day_label.text = "%d / 10" % day
	_day_bar.value = 0.0


func _on_day_progress(pct: float) -> void:
	_day_bar.value = pct * 100.0
	_refresh_queen_hp()


func _on_food_changed(current: int, capacity: int) -> void:
	_food_label.text = "%d / %d" % [current, capacity]


func _on_ant_count_changed(alive: int, _max: int) -> void:
	_update_ants_label(alive)


func _update_ants_label(alive: int = -1) -> void:
	if alive < 0:
		alive = GameManager.total_workers_alive
	_ants_label.text = "%d / 50" % alive


# ── Refresh helpers ──────────────────────────────────────────────────────────

func _refresh_all() -> void:
	_day_label.text   = "%d / 10" % GameManager.current_day
	_day_bar.value    = 0.0
	_food_label.text  = "%d / %d" % [ResourceManager.stored_food, ResourceManager.food_capacity]
	_update_ants_label(GameManager.total_workers_alive)
	_refresh_queen_hp()
	_update_speed_buttons(Engine.time_scale)


func _refresh_queen_hp() -> void:
	var queens: Array = get_tree().get_nodes_in_group("queen")
	if queens.is_empty():
		_queen_hp_bar.value = 100.0
		if _queen_label != null:
			_queen_label.text = "100%"
		return
	var queen: Node = queens[0]
	if queen.has_method("get_health_pct"):
		var pct: float = queen.get_health_pct()
		_queen_hp_bar.value = pct * 100.0
		if _queen_label != null:
			_queen_label.text = "%d%%" % int(pct * 100.0)
