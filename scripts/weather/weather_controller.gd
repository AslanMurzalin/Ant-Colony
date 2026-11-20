class_name WeatherController
extends Node2D

# Weather effects controller: renders surface rain particle drops and darkens sky during rainstorms.

var is_raining: bool = false
var rain_timer: float = 0.0
var rain_drops: Array[Vector2] = []
var max_drops: int = 120
var sky_darkness: float = 0.0

@onready var sky_rect: ColorRect = get_node_or_null("../Background/Sky")

func _ready() -> void:
	z_index = 5
	var threat_mgr: Node = get_node_or_null("/root/ThreatManager")
	if threat_mgr != null:
		threat_mgr.connect("rain_storm_started", Callable(self, "_on_rain_storm_started"))
		threat_mgr.connect("rain_storm_ended", Callable(self, "_on_rain_storm_ended"))

func _on_rain_storm_started(duration: float) -> void:
	start_rain(duration)

func _on_rain_storm_ended() -> void:
	stop_rain()

func start_rain(duration: float) -> void:
	is_raining = true
	rain_timer = duration
	rain_drops.clear()
	for i in range(max_drops):
		rain_drops.append(Vector2(randf_range(-200.0, 2100.0), randf_range(-100.0, 300.0)))
	queue_redraw()

func stop_rain() -> void:
	is_raining = false
	rain_drops.clear()
	sky_darkness = 0.0
	if sky_rect != null:
		sky_rect.color = Color(0.749, 0.89, 0.949, 1.0)
	queue_redraw()

func _process(delta: float) -> void:
	if is_raining:
		sky_darkness = move_toward(sky_darkness, 0.55, delta * 0.3)
		if sky_rect != null:
			sky_rect.color = Color(0.749, 0.89, 0.949, 1.0).lerp(Color(0.2, 0.25, 0.35, 1.0), sky_darkness)
		
		# Move raindrops
		for i in range(rain_drops.size()):
			rain_drops[i].y += delta * 650.0
			rain_drops[i].x -= delta * 120.0
			if rain_drops[i].y > 256.0: # Hit grass
				rain_drops[i].y = randf_range(-100.0, 0.0)
				rain_drops[i].x = randf_range(-200.0, 2100.0)
		
		queue_redraw()
	elif sky_darkness > 0.0:
		sky_darkness = move_toward(sky_darkness, 0.0, delta * 0.5)
		if sky_rect != null:
			sky_rect.color = Color(0.749, 0.89, 0.949, 1.0).lerp(Color(0.2, 0.25, 0.35, 1.0), sky_darkness)
		queue_redraw()

func _draw() -> void:
	if is_raining:
		var drop_col: Color = Color(0.65, 0.8, 0.95, 0.65)
		for drop in rain_drops:
			draw_line(drop, drop + Vector2(-3.0, 14.0), drop_col, 1.5)
