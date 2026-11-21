class_name GridCursor
extends Node2D

# Cursor interaction controller: tracks mouse world coordinates, raycasts to grid cells,
# renders hover box highlighting, and triggers invalid-click flashes.

signal cell_clicked(coords: Vector2i, button_index: int)
signal hover_cell_changed(coords: Vector2i, is_valid: bool)
signal invalid_click_occurred(coords: Vector2i)

var current_hover_cell: Vector2i = Vector2i(-1, -1)
var is_hover_valid: bool = false
var flash_timer: float = 0.0
var invalid_flash_pos: Vector2i = Vector2i(-1, -1)
var current_tool: int = 0 # 0 = DIG, 1 = CANCEL, 2 = NURSERY, 3 = FOOD_STORE

var color_valid_hover: Color = Color(1.0, 1.0, 1.0, 0.45)
var color_dig_hover: Color = Color("#f08a24")
var color_invalid_flash: Color = Color(0.9, 0.15, 0.15, 0.8)

func _ready() -> void:
	z_index = 10

func _process(delta: float) -> void:
	var mouse_world: Vector2 = get_global_mouse_position()
	if GridManager != null:
		var new_hover: Vector2i = GridManager.world_to_grid(mouse_world)
		if new_hover != current_hover_cell:
			current_hover_cell = new_hover
			is_hover_valid = GridManager.is_valid_coord(current_hover_cell) and current_hover_cell.y >= GridManager.surface_row
			hover_cell_changed.emit(current_hover_cell, is_hover_valid)
			queue_redraw()

	if flash_timer > 0.0:
		flash_timer -= delta
		if flash_timer <= 0.0:
			invalid_flash_pos = Vector2i(-1, -1)
		queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.pressed:
			if mouse_event.button_index == MOUSE_BUTTON_LEFT:
				handle_click(current_hover_cell, false)
			elif mouse_event.button_index == MOUSE_BUTTON_RIGHT:
				if not mouse_event.shift_pressed and not Input.is_key_pressed(KEY_SHIFT):
					handle_click(current_hover_cell, true)

func select_tool(tool_id: int) -> void:
	current_tool = tool_id
	queue_redraw()

func get_hover_cell() -> Vector2i:
	return current_hover_cell

func handle_click(coords: Vector2i, is_right_click: bool = false) -> void:
	if GridManager == null or not GridManager.is_valid_coord(coords):
		return

	cell_clicked.emit(coords, MOUSE_BUTTON_RIGHT if is_right_click else MOUSE_BUTTON_LEFT)

	if is_right_click or current_tool == 1: # CANCEL DIG
		if GridManager.is_cell_marked_for_dig(coords):
			GridManager.cancel_dig(coords)
		else:
			trigger_invalid_flash(coords)
		return

	# Primary Tool: DIG (0)
	if current_tool == 0:
		if GridManager.is_cell_marked_for_dig(coords):
			# Toggle off
			GridManager.cancel_dig(coords)
		elif GridManager.is_cell_diggable(coords):
			GridManager.mark_cell_for_dig(coords)
		else:
			# Clicked unmineable rock, air, or sky -> invalid flash
			trigger_invalid_flash(coords)

	# Chamber Designation Tools (2 = NURSERY, 3 = FOOD_STORE)
	elif current_tool == 2:
		if not GridManager.designate_chamber(coords, Enums.ChamberType.NURSERY):
			trigger_invalid_flash(coords)
	elif current_tool == 3:
		if not GridManager.designate_chamber(coords, Enums.ChamberType.FOOD_STORE):
			trigger_invalid_flash(coords)

func trigger_invalid_flash(coords: Vector2i) -> void:
	invalid_flash_pos = coords
	flash_timer = 0.25
	invalid_click_occurred.emit(coords)
	queue_redraw()

func _draw() -> void:
	if GridManager == null:
		return

	var c_size: Vector2 = GridManager.cell_size

	# Draw hover box over active cell
	if is_hover_valid and GridManager.is_valid_coord(current_hover_cell):
		var rect: Rect2 = Rect2(float(current_hover_cell.x) * c_size.x, float(current_hover_cell.y) * c_size.y, c_size.x, c_size.y)
		var ctype: Enums.CellType = GridManager.get_cell_type(current_hover_cell)

		if ctype == Enums.CellType.SOIL:
			var border_col: Color = color_dig_hover if GridManager.is_cell_marked_for_dig(current_hover_cell) else color_valid_hover
			draw_rect(rect, border_col, false, 2.0)
		elif ctype == Enums.CellType.ROCK:
			draw_rect(rect, Color(0.9, 0.2, 0.2, 0.4), false, 2.0)

	# Draw invalid click flash (Red Box with X)
	if flash_timer > 0.0 and GridManager.is_valid_coord(invalid_flash_pos):
		var f_rect: Rect2 = Rect2(float(invalid_flash_pos.x) * c_size.x, float(invalid_flash_pos.y) * c_size.y, c_size.x, c_size.y)
		var flash_alpha: float = clampf(flash_timer / 0.25, 0.0, 1.0)
		var cur_flash_col: Color = Color(color_invalid_flash.r, color_invalid_flash.g, color_invalid_flash.b, flash_alpha * 0.8)
		draw_rect(f_rect, cur_flash_col)
		draw_rect(f_rect, Color(1, 0.1, 0.1, flash_alpha), false, 2.5)
		draw_line(f_rect.position, f_rect.position + f_rect.size, Color(1, 1, 1, flash_alpha), 2.0)
		draw_line(Vector2(f_rect.position.x + f_rect.size.x, f_rect.position.y), Vector2(f_rect.position.x, f_rect.position.y + f_rect.size.y), Color(1, 1, 1, flash_alpha), 2.0)
