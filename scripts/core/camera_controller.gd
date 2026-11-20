class_name CameraController
extends Camera2D

# Controller for the 2D cross-section camera with pan limits, dragging, and zoom controls.

signal camera_moved(new_position: Vector2)
signal camera_zoomed(new_zoom: Vector2)

var pan_speed: float = 500.0
var drag_sensitivity: float = 1.0
var zoom_speed: float = 0.1
var min_zoom: float = 0.5
var max_zoom: float = 2.0

var limit_top_val: int = -300
var limit_bottom_val: int = 1600
var limit_left_val: int = -200
var limit_right_val: int = 2120

var is_dragging: bool = false
var drag_start_mouse_pos: Vector2 = Vector2.ZERO
var drag_start_camera_pos: Vector2 = Vector2.ZERO

func _ready() -> void:
	add_to_group("camera")
	set_bounds(limit_left_val, limit_top_val, limit_right_val, limit_bottom_val)

func _process(delta: float) -> void:
	var move_vec: Vector2 = Vector2.ZERO
	if Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_W):
		move_vec.y -= 1.0
	if Input.is_action_pressed("ui_down") or Input.is_key_pressed(KEY_S):
		move_vec.y += 1.0
	if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A):
		move_vec.x -= 1.0
	if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D):
		move_vec.x += 1.0

	if move_vec != Vector2.ZERO:
		move_camera(move_vec.normalized() * pan_speed * delta)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_MIDDLE or mouse_event.button_index == MOUSE_BUTTON_RIGHT:
			if mouse_event.pressed:
				is_dragging = true
				drag_start_mouse_pos = mouse_event.position
				drag_start_camera_pos = position
			else:
				is_dragging = false
		elif mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP and mouse_event.pressed:
			adjust_zoom(zoom_speed)
		elif mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN and mouse_event.pressed:
			adjust_zoom(-zoom_speed)

	elif event is InputEventMouseMotion and is_dragging:
		var motion_event: InputEventMouseMotion = event as InputEventMouseMotion
		var drag_delta: Vector2 = (drag_start_mouse_pos - motion_event.position) * drag_sensitivity / zoom.x
		position = drag_start_camera_pos + drag_delta
		_clamp_position()
		camera_moved.emit(position)

func set_bounds(left: int, top: int, right: int, bottom: int) -> void:
	limit_left_val = left
	limit_top_val = top
	limit_right_val = right
	limit_bottom_val = bottom
	limit_left = limit_left_val
	limit_top = limit_top_val
	limit_right = limit_right_val
	limit_bottom = limit_bottom_val

func move_camera(offset: Vector2) -> void:
	position += offset
	_clamp_position()
	camera_moved.emit(position)

func adjust_zoom(zoom_delta: float) -> void:
	var new_zoom_val: float = clampf(zoom.x + zoom_delta, min_zoom, max_zoom)
	zoom = Vector2(new_zoom_val, new_zoom_val)
	camera_zoomed.emit(zoom)

func reset_camera() -> void:
	position = Vector2(960.0, 540.0)
	zoom = Vector2.ONE
	camera_moved.emit(position)
	camera_zoomed.emit(zoom)

func center_on_position(world_pos: Vector2) -> void:
	position = world_pos
	_clamp_position()
	camera_moved.emit(position)

func _clamp_position() -> void:
	position.x = clampf(position.x, float(limit_left_val) + 960.0 / zoom.x, float(limit_right_val) - 960.0 / zoom.x)
	position.y = clampf(position.y, float(limit_top_val) + 540.0 / zoom.y, float(limit_bottom_val) - 540.0 / zoom.y)
