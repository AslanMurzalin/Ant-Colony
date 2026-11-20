class_name GridView
extends Node2D

# Visual renderer for the underground soil grid, rocks, excavated tunnels, and dig markers.

var color_soil: Color = Color("#8a5a32")
var color_deep_soil: Color = Color("#5a3820")
var color_rock: Color = Color("#2d241e")
var color_water: Color = Color(0.29, 0.56, 0.85, 0.75)
var color_dig_marker: Color = Color("#f08a24")
var color_royal_chamber: Color = Color("#f2c230")
var color_nursery: Color = Color(0.78, 0.45, 0.72)
var color_food_store: Color = Color(0.88, 0.62, 0.18)

func _ready() -> void:
	if GridManager != null:
		GridManager.cell_modified.connect(_on_cell_modified)
		GridManager.dig_marked.connect(_on_dig_updated)
		GridManager.dig_cancelled.connect(_on_dig_updated)
		GridManager.dig_progress_updated.connect(_on_dig_progress)
		GridManager.chamber_designated.connect(_on_chamber_updated)
		GridManager.chamber_completed.connect(_on_chamber_updated)

func _on_cell_modified(_coords: Vector2i, _new_type: Enums.CellType) -> void:
	queue_redraw()

func _on_dig_updated(_coords: Vector2i) -> void:
	queue_redraw()

func _on_dig_progress(_coords: Vector2i, _progress: float) -> void:
	queue_redraw()

func _on_chamber_updated(_coords: Vector2i, _type: Enums.ChamberType) -> void:
	queue_redraw()

func _draw() -> void:
	if GridManager == null:
		return

	var c_size: Vector2 = GridManager.cell_size
	var s_row: int = GridManager.surface_row

	for y in range(s_row, GridManager.grid_height):
		for x in range(GridManager.grid_width):
			var coords: Vector2i = Vector2i(x, y)
			var c_type: Enums.CellType = GridManager.get_cell_type(coords)
			var rect: Rect2 = Rect2(float(x) * c_size.x, float(y) * c_size.y, c_size.x, c_size.y)

			match c_type:
				Enums.CellType.SOIL:
					var fill_col: Color = color_deep_soil if y >= 28 else color_soil
					draw_rect(rect, fill_col)
					draw_rect(rect, fill_col.darkened(0.15), false, 1.0)
				Enums.CellType.ROCK:
					draw_rect(rect, color_rock)
					draw_rect(rect, color_rock.lightened(0.2), false, 1.5)
				Enums.CellType.WATER:
					draw_rect(rect, color_water)
				Enums.CellType.AIR:
					var chamber: Enums.ChamberType = GridManager.get_chamber_type(coords)
					if chamber == Enums.ChamberType.ROYAL:
						draw_rect(rect, color_royal_chamber.darkened(0.65))
						draw_rect(rect, color_royal_chamber, false, 1.0)
					elif chamber == Enums.ChamberType.NURSERY:
						draw_rect(rect, color_nursery.darkened(0.65))
						draw_rect(rect, color_nursery, false, 1.0)
					elif chamber == Enums.ChamberType.FOOD_STORE:
						draw_rect(rect, color_food_store.darkened(0.65))
						draw_rect(rect, color_food_store, false, 1.0)

	# Draw Dig Queue Indicators and Progress
	for d_coord in GridManager.dig_queue:
		var d_rect: Rect2 = Rect2(float(d_coord.x) * c_size.x, float(d_coord.y) * c_size.y, c_size.x, c_size.y)
		draw_rect(d_rect, color_dig_marker, false, 2.0)
		draw_line(d_rect.position, d_rect.position + d_rect.size, color_dig_marker, 1.5)
		draw_line(Vector2(d_rect.position.x + d_rect.size.x, d_rect.position.y), Vector2(d_rect.position.x, d_rect.position.y + d_rect.size.y), color_dig_marker, 1.5)
		
		# Draw progress bar if cell is currently being excavated
		var prog: float = GridManager.get_dig_progress(d_coord)
		if prog > 0.0:
			var bar_rect: Rect2 = Rect2(d_rect.position.x + 2.0, d_rect.position.y + d_rect.size.y - 6.0, (d_rect.size.x - 4.0) * prog, 4.0)
			draw_rect(bar_rect, Color(0.2, 0.9, 0.2, 0.9))
