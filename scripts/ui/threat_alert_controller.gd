class_name ThreatAlertController
extends Control

# Screen-edge warning arrows and pulsing icons appearing 8s prior to predator invasion.

signal alert_started(type: Enums.ThreatType, dir: Vector2)
signal alert_ended()

var is_alert_active: bool = false
var alert_type: Enums.ThreatType = Enums.ThreatType.SPIDER
var alert_dir: Vector2 = Vector2.LEFT
var alert_timer: float = 0.0
var pulse_timer: float = 0.0

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	var threat_mgr: Node = get_node_or_null("/root/ThreatManager")
	if threat_mgr != null and threat_mgr.has_signal("threat_warning_issued"):
		threat_mgr.connect("threat_warning_issued", Callable(self, "_on_threat_warning_issued"))
		threat_mgr.connect("threat_spawned", Callable(self, "_on_threat_spawned"))

func _on_threat_warning_issued(type: Enums.ThreatType, spawn_side: Vector2, time_until_spawn: float) -> void:
	show_alert(type, spawn_side, time_until_spawn)

func _on_threat_spawned(_threat_node: Node2D) -> void:
	hide_alert()

func show_alert(type: Enums.ThreatType, spawn_side: Vector2, duration: float) -> void:
	is_alert_active = true
	alert_type = type
	alert_timer = duration
	# Determine incoming direction
	alert_dir = Vector2.LEFT if spawn_side.x < 960.0 else Vector2.RIGHT
	alert_started.emit(type, alert_dir)
	queue_redraw()

func hide_alert() -> void:
	if is_alert_active:
		is_alert_active = false
		alert_ended.emit()
		queue_redraw()

func _process(delta: float) -> void:
	if is_alert_active:
		pulse_timer += delta * 6.0
		alert_timer -= delta
		if alert_timer <= 0.0:
			hide_alert()
		else:
			queue_redraw()

func _draw() -> void:
	if not is_alert_active:
		return
	
	var alpha: float = 0.5 + 0.5 * sin(pulse_timer)
	var col: Color = Color(0.9, 0.15, 0.15, alpha) if alert_type == Enums.ThreatType.BEETLE else Color(0.9, 0.6, 0.1, alpha)
	
	var screen_x: float = 40.0 if alert_dir == Vector2.LEFT else 1880.0
	var screen_y: float = 240.0
	var center_pos: Vector2 = Vector2(screen_x, screen_y)
	
	# Draw pulsing warning triangle
	var arrow_size: float = 24.0
	var p1: Vector2
	var p2: Vector2
	var p3: Vector2
	
	if alert_dir == Vector2.LEFT:
		p1 = center_pos + Vector2(arrow_size, 0)
		p2 = center_pos + Vector2(0, -arrow_size * 0.7)
		p3 = center_pos + Vector2(0, arrow_size * 0.7)
	else:
		p1 = center_pos + Vector2(-arrow_size, 0)
		p2 = center_pos + Vector2(0, -arrow_size * 0.7)
		p3 = center_pos + Vector2(0, arrow_size * 0.7)
	
	var points: PackedVector2Array = PackedVector2Array([p1, p2, p3])
	draw_colored_polygon(points, col)
	draw_polyline(PackedVector2Array([p1, p2, p3, p1]), Color(1, 1, 1, alpha), 2.0)
