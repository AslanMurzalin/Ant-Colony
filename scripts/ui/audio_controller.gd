class_name AudioController
extends Node

## AudioController — manages all SFX and Music buses, screen shake, and volume settings.
## Add as autoload or child of Main scene.

# ── Audio stream player nodes ─────────────────────────────────────────────────
@onready var _ambient:   AudioStreamPlayer = $Ambient
@onready var _sfx_dig:   AudioStreamPlayer = $SfxDig
@onready var _sfx_alert: AudioStreamPlayer = $SfxAlert
@onready var _sfx_rain:  AudioStreamPlayer = $SfxRain
@onready var _sfx_step:  AudioStreamPlayer = $SfxStep
@onready var _sfx_win:   AudioStreamPlayer = $SfxWin

# ── Camera reference for screen shake ────────────────────────────────────────
var _camera: Camera2D = null
var _shake_intensity: float = 0.0
var _shake_duration:  float = 0.0

# ── Volume ───────────────────────────────────────────────────────────────────
var sfx_volume_db:   float = 0.0
var music_volume_db: float = -6.0


func _ready() -> void:
	add_to_group("audio_controller")
	_setup_audio_buses()
	_connect_signals()
	# Start ambient rumble loop
	if _ambient != null:
		_ambient.play()


func _process(delta: float) -> void:
	_tick_screen_shake(delta)


# ── Signal Connections ────────────────────────────────────────────────────────

func _connect_signals() -> void:
	ThreatManager.connect("threat_warning_issued", _on_threat_warning)
	ThreatManager.connect("rain_started",          _on_rain_started)
	ThreatManager.connect("rain_stopped",          _on_rain_stopped)
	GameManager.connect("game_won",   func(_r, _s) -> void: _play_sfx(_sfx_win))
	GameManager.connect("game_over",  func(_reason) -> void: pass)


func _on_threat_warning(_threat_type = null, _spawn_side = null, _time = null) -> void:
	_play_sfx(_sfx_alert)


func _on_rain_started(_duration: float = 0.0) -> void:
	_play_sfx(_sfx_rain)


func _on_rain_stopped() -> void:
	if _sfx_rain != null and _sfx_rain.playing:
		_sfx_rain.stop()


# ── Public API ────────────────────────────────────────────────────────────────

## Play the dig chomp sound once.
func play_dig_sfx() -> void:
	_play_sfx(_sfx_dig)


## Play the ant footstep tick at low volume.
func play_step_sfx() -> void:
	if _sfx_step != null:
		_sfx_step.volume_db = sfx_volume_db - 12.0
		if not _sfx_step.playing:
			_sfx_step.play()


## Trigger a camera shake — called when a beetle strikes walls or the Queen.
func trigger_screen_shake(intensity: float = 6.0, duration: float = 0.4) -> void:
	_shake_intensity = intensity
	_shake_duration  = duration
	if _camera == null:
		_camera = get_tree().get_first_node_in_group("camera")


## Set SFX bus volume from a 0.0–1.0 slider.
func set_sfx_volume(linear: float) -> void:
	sfx_volume_db = linear_to_db(clampf(linear, 0.001, 1.0))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), sfx_volume_db)


## Set Music bus volume from a 0.0–1.0 slider.
func set_music_volume(linear: float) -> void:
	music_volume_db = linear_to_db(clampf(linear, 0.001, 1.0))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), music_volume_db)


# ── Internals ─────────────────────────────────────────────────────────────────

func _play_sfx(player: AudioStreamPlayer) -> void:
	if player != null and player.stream != null:
		player.volume_db = sfx_volume_db
		player.play()


func _tick_screen_shake(delta: float) -> void:
	if _shake_duration <= 0.0 or _camera == null:
		return
	_shake_duration -= delta
	if _shake_duration <= 0.0:
		_camera.offset = Vector2.ZERO
		return
	_camera.offset = Vector2(
		randf_range(-_shake_intensity, _shake_intensity),
		randf_range(-_shake_intensity, _shake_intensity)
	)


func _setup_audio_buses() -> void:
	# Ensure SFX and Music buses exist at runtime; Godot stores buses in project settings.
	if AudioServer.get_bus_index("SFX") == -1:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, "SFX")
	if AudioServer.get_bus_index("Music") == -1:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, "Music")
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"),   sfx_volume_db)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), music_volume_db)
