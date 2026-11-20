class_name PauseMenu
extends Control

## Pause Menu — toggled with Escape key; contains volume sliders.

@onready var _sfx_slider:   HSlider = $Panel/VBox/SFXRow/SFXSlider
@onready var _music_slider: HSlider = $Panel/VBox/MusicRow/MusicSlider
@onready var _resume_btn:   Button  = $Panel/VBox/ResumeBtn
@onready var _quit_btn:     Button  = $Panel/VBox/QuitBtn

var _audio_ctrl: AudioController = null


func _ready() -> void:
	hide()
	_resume_btn.connect("pressed", _on_resume_pressed)
	_quit_btn.connect("pressed",   func() -> void: get_tree().quit())
	_sfx_slider.connect("value_changed",   func(v: float) -> void: _on_sfx_changed(v))
	_music_slider.connect("value_changed", func(v: float) -> void: _on_music_changed(v))
	_audio_ctrl = get_tree().get_first_node_in_group("audio_controller") as AudioController


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_toggle()


func _toggle() -> void:
	if visible:
		_on_resume_pressed()
	else:
		GameManager.set_game_speed(0.0)
		show()


func _on_resume_pressed() -> void:
	hide()
	GameManager.set_game_speed(1.0)


func _on_sfx_changed(value: float) -> void:
	if _audio_ctrl != null:
		_audio_ctrl.set_sfx_volume(value / 100.0)


func _on_music_changed(value: float) -> void:
	if _audio_ctrl != null:
		_audio_ctrl.set_music_volume(value / 100.0)
