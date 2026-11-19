class_name BuildMenuController
extends Control

# Bottom-right architecture deck: allows player to select Dig, Cancel, Nursery, or Food Store tools.

signal tool_selected(tool_id: int)

var current_tool: int = 0 # 0 = DIG, 1 = CANCEL, 2 = NURSERY, 3 = FOOD_STORE

@onready var btn_dig: Button = $Panel/HBox/BtnDig
@onready var btn_cancel: Button = $Panel/HBox/BtnCancel
@onready var btn_nursery: Button = $Panel/HBox/BtnNursery
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
			btn.modulate = Color(1.2, 1.2, 1.0) if i == current_tool else Color(0.85, 0.85, 0.85)
