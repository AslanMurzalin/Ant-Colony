class_name TileTooltip
extends Control

## Информационная плашка тайла в нижнем правом углу (стиль antcolony.gg).
## Отображает категорию, название, описание, Hardness и Depth текущего тайла под курсором.

@onready var label_category: Label = $PanelContainer/VBox/HeaderLabel
@onready var label_title: Label = $PanelContainer/VBox/TitleLabel
@onready var label_desc: Label = $PanelContainer/VBox/DescLabel
@onready var label_hardness: Label = $PanelContainer/VBox/StatsHBox/HardnessVal
@onready var label_depth: Label = $PanelContainer/VBox/StatsHBox/DepthVal


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_connect_cursor()
	update_info(Vector2i(-1, -1), false)


## Подключение к сигналу перемещения курсора GridCursor
func _connect_cursor() -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var cursor: Node = tree.root.find_child("GridCursor", true, false)
	if cursor != null and cursor.has_signal("hover_cell_changed"):
		cursor.connect("hover_cell_changed", _on_hover_cell_changed)


func _on_hover_cell_changed(coords: Vector2i, is_valid: bool) -> void:
	update_info(coords, is_valid)


## Обновление содержимого плашки по координатам ячейки
func update_info(coords: Vector2i, is_valid: bool) -> void:
	if label_category == null or label_title == null or label_desc == null:
		return

	if GridManager == null or not GridManager.is_valid_coord(coords):
		_display_sky()
		return

	var s_row: int = GridManager.surface_row
	if coords.y < s_row:
		_display_sky()
		return

	# Глубина в сантиметрах (от линии поверхности земли)
	var depth_cm: int = int(float(coords.y - s_row) * 12.0)
	var cell_type: Enums.CellType = GridManager.get_cell_type(coords)

	match cell_type:
		Enums.CellType.SOIL:
			label_category.text = "TILE · SOIL"
			label_title.text = "Subsoil"
			label_desc.text = "Undisturbed soil"
			label_hardness.text = "Soft"
			label_depth.text = "%d cm" % depth_cm
		Enums.CellType.ROCK:
			label_category.text = "TILE · ROCK"
			label_title.text = "Granite Rock"
			label_desc.text = "Impenetrable stone"
			label_hardness.text = "Hard"
			label_depth.text = "%d cm" % depth_cm
		Enums.CellType.WATER:
			label_category.text = "TILE · WATER"
			label_title.text = "Subterranean Spring"
			label_desc.text = "Aquifer water vein"
			label_hardness.text = "Liquid"
			label_depth.text = "%d cm" % depth_cm
		Enums.CellType.AIR:
			var chamber: Enums.ChamberType = GridManager.get_chamber_type(coords)
			match chamber:
				Enums.ChamberType.ROYAL:
					label_category.text = "CHAMBER · ROYAL"
					label_title.text = "Royal Chamber"
					label_desc.text = "Queen's safe haven"
					label_hardness.text = "Hollow"
					label_depth.text = "%d cm" % depth_cm
				Enums.ChamberType.NURSERY:
					label_category.text = "CHAMBER · NURSERY"
					label_title.text = "Brood Nursery"
					label_desc.text = "Incubation warmth"
					label_hardness.text = "Hollow"
					label_depth.text = "%d cm" % depth_cm
				Enums.ChamberType.FOOD_STORE:
					label_category.text = "CHAMBER · STORAGE"
					label_title.text = "Food Granary"
					var stored: int = 0
					var cap: int = 5
					if ResourceManager != null:
						stored = ResourceManager.get_cell_food(coords)
						cap = ResourceManager.CAPACITY_PER_STORAGE_CELL
					label_desc.text = "Stored %d / %d" % [stored, cap]
					label_hardness.text = "Stockpile"
					label_depth.text = "%d cm" % depth_cm
				_:
					label_category.text = "TILE · TUNNEL"
					label_title.text = "Excavated Tunnel"
					label_desc.text = "Carved subterranean passage"
					label_hardness.text = "Hollow"
					label_depth.text = "%d cm" % depth_cm


func _display_sky() -> void:
	label_category.text = "TILE · SKY"
	label_title.text = "Open Sky"
	label_desc.text = "Above-ground atmosphere"
	label_hardness.text = "None"
	label_depth.text = "0 cm"
