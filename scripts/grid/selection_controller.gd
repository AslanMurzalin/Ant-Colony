class_name SelectionController
extends Node2D

## Controls Shift+RMB box selection of worker ants in the world,
## renders selection rectangle overlay, and manages the role assignment popup.

signal ants_selected(selected: Array[AntController])
signal selection_cleared()

@export var selection_popup: SelectionPopup = null

var is_box_selecting: bool = false
var selection_start_world: Vector2 = Vector2.ZERO
var selection_curr_world: Vector2 = Vector2.ZERO
var selected_ants: Array[AntController] = []

func _ready() -> void:
	z_index = 50
	if selection_popup == null:
		selection_popup = get_node_or_null("../UILayer/SelectionPopup") as SelectionPopup
	if selection_popup == null:
		selection_popup = get_tree().get_first_node_in_group("selection_popup") as SelectionPopup
	if selection_popup != null:
		selection_popup.role_chosen.connect(_on_role_chosen)
		selection_popup.unpin_chosen.connect(_on_unpin_chosen)
		selection_popup.popup_closed.connect(clear_selection)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		var is_shift: bool = mouse_event.shift_pressed or Input.is_key_pressed(KEY_SHIFT)

		if mouse_event.button_index == MOUSE_BUTTON_RIGHT:
			if mouse_event.pressed and is_shift:
				is_box_selecting = true
				selection_start_world = get_global_mouse_position()
				selection_curr_world = selection_start_world
				queue_redraw()
				get_viewport().set_input_as_handled()
			elif not mouse_event.pressed and is_box_selecting:
				is_box_selecting = false
				selection_curr_world = get_global_mouse_position()
				queue_redraw()
				_finish_selection()
				get_viewport().set_input_as_handled()

		elif mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			# If user clicks LMB somewhere while popup is open, close popup if not clicking inside it
			if not selected_ants.is_empty() and selection_popup != null and selection_popup.visible:
				var m_pos: Vector2 = get_viewport().get_mouse_position()
				var p_rect: Rect2 = selection_popup.get_global_rect()
				if not p_rect.has_point(m_pos):
					clear_selection()

	elif event is InputEventMouseMotion and is_box_selecting:
		selection_curr_world = get_global_mouse_position()
		queue_redraw()

	elif event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		if key_event.pressed and key_event.keycode == KEY_ESCAPE:
			clear_selection()

func _draw() -> void:
	if is_box_selecting:
		var top_left: Vector2 = Vector2(
			minf(selection_start_world.x, selection_curr_world.x),
			minf(selection_start_world.y, selection_curr_world.y)
		)
		var bottom_right: Vector2 = Vector2(
			maxf(selection_start_world.x, selection_curr_world.x),
			maxf(selection_start_world.y, selection_curr_world.y)
		)
		var size: Vector2 = bottom_right - top_left
		var local_rect: Rect2 = Rect2(to_local(top_left), size)

		# Semi-transparent fill + bright border
		draw_rect(local_rect, Color(0.2, 0.6, 1.0, 0.25), true)
		draw_rect(local_rect, Color(0.4, 0.8, 1.0, 0.9), false, 1.5)

func _finish_selection() -> void:
	clear_selection()

	var top_left: Vector2 = Vector2(
		minf(selection_start_world.x, selection_curr_world.x),
		minf(selection_start_world.y, selection_curr_world.y)
	)
	var bottom_right: Vector2 = Vector2(
		maxf(selection_start_world.x, selection_curr_world.x),
		maxf(selection_start_world.y, selection_curr_world.y)
	)
	var size: Vector2 = bottom_right - top_left
	var select_rect: Rect2 = Rect2(top_left, size)

	var workers: Array = get_tree().get_nodes_in_group("workers")
	for node in workers:
		if is_instance_valid(node) and node is AntController:
			var ant: AntController = node as AntController
			# If dragged box is small, do radius check near click
			if size.x < 16.0 and size.y < 16.0:
				if ant.global_position.distance_to(selection_curr_world) <= 32.0 or ant.global_position.distance_to(selection_start_world) <= 32.0:
					selected_ants.append(ant)
			else:
				if select_rect.grow(4.0).has_point(ant.global_position):
					selected_ants.append(ant)

	for ant in selected_ants:
		ant.set_selected(true)

	if not selected_ants.is_empty():
		ants_selected.emit(selected_ants)
		if selection_popup == null:
			selection_popup = get_node_or_null("../UILayer/SelectionPopup") as SelectionPopup
		if selection_popup == null:
			selection_popup = get_tree().get_first_node_in_group("selection_popup") as SelectionPopup
		if selection_popup != null:
			var screen_pos: Vector2 = get_viewport().get_mouse_position()
			selection_popup.open_at(screen_pos, selected_ants.size())
	else:
		selection_cleared.emit()

func _on_role_chosen(job: Enums.JobType) -> void:
	for ant in selected_ants:
		if is_instance_valid(ant):
			ant.assign_job_manually(job)
	clear_selection()
	var total_alive: int = get_tree().get_nodes_in_group("workers").size()
	TaskAllocationManager.recalculate_job_targets(total_alive)

func _on_unpin_chosen() -> void:
	for ant in selected_ants:
		if is_instance_valid(ant):
			ant.unpin_job()
			var new_job: Enums.JobType = TaskAllocationManager.request_job_for_ant(ant)
			ant.assign_job(new_job)
	clear_selection()
	var total_alive: int = get_tree().get_nodes_in_group("workers").size()
	TaskAllocationManager.recalculate_job_targets(total_alive)

func clear_selection() -> void:
	for ant in selected_ants:
		if is_instance_valid(ant):
			ant.set_selected(false)
	selected_ants.clear()
	if selection_popup != null and selection_popup.visible:
		selection_popup.hide()
	selection_cleared.emit()

func get_selected_ants() -> Array[AntController]:
	return selected_ants
