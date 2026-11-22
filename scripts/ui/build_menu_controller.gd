class_name BuildMenuController
extends Control

# Bottom-right architecture deck: allows player to select Dig, Cancel, Nursery, or Food Store tools.

signal tool_selected(tool_id: int)

const COLOR_DARK_BG    := Color(0.102, 0.082, 0.071, 1.0)   # #1A1512
const COLOR_GOLD       := Color(0.949, 0.659, 0.114, 1.0)   # #F2A81D
const COLOR_INACTIVE   := Color(0.141, 0.110, 0.090, 1.0)   # #241C17
const COLOR_TEXT_DIM   := Color(0.831, 0.784, 0.745, 1.0)   # #D4C8BE

var current_tool: int = 0 # 0 = DIG, 1 = CANCEL, 2 = NURSERY, 3 = FOOD_STORE

@onready var btn_dig: Button       = $Panel/HBox/BtnDig
@onready var btn_cancel: Button    = $Panel/HBox/BtnCancel
@onready var btn_nursery: Button   = $Panel/HBox/BtnNursery
@onready var btn_food_store: Button = $Panel/HBox/BtnFoodStore


func _ready() -> void:
	if btn_dig != null:
		btn_dig.pressed.connect(func(): select_tool(0))
	if btn_cancel != null:
		btn_cancel.pressed.connect(func(): select_tool(1))
	if btn_nursery != null:
		btn_nursery.pressed.connect(func(): select_tool(2))
	if btn_food_store != null:
		btn_food_store.pressed.connect(func(): select_tool(3))
	select_tool(0)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		var key_event: InputEventKey = event as InputEventKey
		if key_event.keycode == KEY_1:
			select_tool(0)
		elif key_event.keycode == KEY_2:
			select_tool(1)
		elif key_event.keycode == KEY_3:
			select_tool(2)
		elif key_event.keycode == KEY_4:
			select_tool(3)


func select_tool(tool_id: int) -> void:
	current_tool = tool_id
	_update_button_highlights()
	tool_selected.emit(current_tool)


func handle_grid_click(cell_coords: Vector2i) -> void:
	if GridManager == null:
		return
	match current_tool:
		0:
			GridManager.toggle_dig_mark(cell_coords)
		1:
			GridManager.cancel_dig(cell_coords)
		2:
			GridManager.designate_chamber(cell_coords, Enums.ChamberType.NURSERY)
		3:
			GridManager.designate_chamber(cell_coords, Enums.ChamberType.FOOD_STORE)


func _update_button_highlights() -> void:
	var buttons: Array = [btn_dig, btn_cancel, btn_nursery, btn_food_store]
	for i in range(buttons.size()):
		var btn: Button = buttons[i]
		if btn != null:
			_apply_tool_style(btn, i == current_tool)


## Apply gold border+text style to active tool button, dim style to inactive.
func _apply_tool_style(btn: Button, is_active: bool) -> void:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_right = 4
	sb.corner_radius_bottom_left = 4
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1

	if is_active:
		sb.bg_color = COLOR_DARK_BG
		sb.border_color = COLOR_GOLD
		btn.add_theme_color_override("font_color", COLOR_GOLD)
		btn.add_theme_color_override("font_hover_color", COLOR_GOLD)
	else:
		sb.bg_color = COLOR_INACTIVE
		sb.border_color = Color(0.20, 0.15, 0.11, 1.0)
		btn.add_theme_color_override("font_color", COLOR_TEXT_DIM)
		btn.add_theme_color_override("font_hover_color", Color.WHITE)

	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", sb)
	btn.add_theme_stylebox_override("pressed", sb)
