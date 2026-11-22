class_name GridView
extends Node2D

# Visual renderer for the underground soil grid, rocks, excavated tunnels, and dig markers.
# Renders:
#   SOIL  → invisible (warm earth texture shows through from background TextureRect)
#   AIR   → dark tunnel (#1a1005) with rounded inner corners and subtle wall shading
#   ROCK  → dark grey fill
#   WATER → translucent blue

# ── Colours ────────────────────────────────────────────────────────────────────
var color_rock:          Color = Color(0.32, 0.30, 0.28)
var color_water:         Color = Color(0.29, 0.56, 0.85, 0.75)
var color_dig_marker:    Color = Color("#f08a24")
var color_royal_chamber: Color = Color("#f2c230")
var color_nursery:       Color = Color(0.78, 0.45, 0.72)
var color_food_store:    Color = Color(0.88, 0.62, 0.18)

# Deep dark tunnel void — matches antcolony.gg (#1a1005)
var color_tunnel_void:   Color = Color(0.102, 0.063, 0.020, 1.0)   # #1a1005
# Slightly lighter inner wall (top + left edges) for depth illusion
var color_tunnel_wall:   Color = Color(0.18,  0.11,  0.05,  1.0)   # subtle warm edge
# Very faint soil rim drawn around tunnel edges into neighbouring SOIL cells
var color_soil_rim:      Color = Color(0.55,  0.38,  0.20,  0.55)  # earthy inner bevel

# ── Corner rounding ─────────────────────────────────────────────────────────────
# Radius in pixels to cut off each inner corner of a tunnel cell
const CORNER_R: float = 5.0
# How many segments per corner arc (higher = smoother, more draw calls)
const CORNER_SEGS: int = 4

# ── Internal ────────────────────────────────────────────────────────────────────
var _dig_overlay: Node2D = null
var _progress_throttle_timer: float = 0.0


func _ready() -> void:
	_dig_overlay = Node2D.new()
	_dig_overlay.name = "DigOverlay"
	_dig_overlay.draw.connect(_on_draw_overlay)
	add_child(_dig_overlay)

	if GridManager != null:
		GridManager.cell_modified.connect(_on_cell_modified)
		GridManager.dig_marked.connect(_on_dig_updated)
		GridManager.dig_cancelled.connect(_on_dig_updated)
		GridManager.dig_progress_updated.connect(_on_dig_progress)
		GridManager.chamber_designated.connect(_on_chamber_updated)
		GridManager.chamber_completed.connect(_on_chamber_updated)


func _process(delta: float) -> void:
	if _progress_throttle_timer > 0.0:
		_progress_throttle_timer -= delta


func _on_cell_modified(_coords: Vector2i, _new_type: Enums.CellType) -> void:
	queue_redraw()
	if _dig_overlay != null:
		_dig_overlay.queue_redraw()


func _on_dig_updated(_coords: Vector2i) -> void:
	if _dig_overlay != null:
		_dig_overlay.queue_redraw()


func _on_dig_progress(_coords: Vector2i, _progress: float) -> void:
	if _progress_throttle_timer <= 0.0:
		_progress_throttle_timer = 0.066
		if _dig_overlay != null:
			_dig_overlay.queue_redraw()


func _on_chamber_updated(_coords: Vector2i, _type: Enums.ChamberType) -> void:
	queue_redraw()


# ── Main draw ──────────────────────────────────────────────────────────────────
func _draw() -> void:
	if GridManager == null:
		return

	var c_size: Vector2 = GridManager.cell_size
	var s_row:  int     = GridManager.surface_row

	for y in range(s_row, GridManager.grid_height):
		for x in range(GridManager.grid_width):
			var coords: Vector2i  = Vector2i(x, y)
			var c_type: Enums.CellType = GridManager.get_cell_type(coords)
			var rect:   Rect2     = Rect2(float(x) * c_size.x, float(y) * c_size.y, c_size.x, c_size.y)

			match c_type:
				Enums.CellType.SOIL:
					# Earth texture shows from background — just a ghost grid outline
					draw_rect(rect, Color(0.0, 0.0, 0.0, 0.04), false, 0.5)

				Enums.CellType.ROCK:
					draw_rect(rect, color_rock)
					draw_rect(rect, color_rock.lightened(0.2), false, 1.5)

				Enums.CellType.WATER:
					draw_rect(rect, color_water)

				Enums.CellType.AIR:
					_draw_tunnel_cell(coords, rect)


# ── Tunnel cell renderer ───────────────────────────────────────────────────────
# Draws a dark tunnel void with:
#   • Rounded inner corners (polygon that cuts off the 4 corners)
#   • Subtle shading on top/left walls to give depth
#   • A thin soil-coloured rim at borders shared with SOIL neighbours
func _draw_tunnel_cell(coords: Vector2i, rect: Rect2) -> void:
	# 1. Base dark fill with rounded corners ───────────────────────────────────
	var poly: PackedVector2Array = _rounded_rect_polygon(rect, CORNER_R, CORNER_SEGS)
	draw_colored_polygon(poly, color_tunnel_void)

	# 2. Inner wall shading (top + left = slightly lighter warm brown → depth) ─
	var top_left:     Vector2 = rect.position
	var top_right:    Vector2 = rect.position + Vector2(rect.size.x, 0.0)
	var bottom_left:  Vector2 = rect.position + Vector2(0.0, rect.size.y)
	var bottom_right: Vector2 = rect.end

	# Thin top wall shading
	draw_line(top_left  + Vector2(2.0, 1.5), top_right  + Vector2(-2.0, 1.5), color_tunnel_wall, 2.0)
	# Thin left wall shading
	draw_line(top_left  + Vector2(1.5, 2.0), bottom_left + Vector2(1.5, -2.0), color_tunnel_wall, 2.0)
	# Thin bottom shadow (darker, casts depth)
	draw_line(bottom_left + Vector2(2.0, -1.5), bottom_right + Vector2(-2.0, -1.5),
			Color(0.05, 0.03, 0.01, 0.9), 1.5)

	# 3. Soil rim at borders shared with SOIL neighbours ──────────────────────
	_draw_soil_rim(coords, rect)

	# 4. Chamber tint overlay ─────────────────────────────────────────────────
	var chamber: Enums.ChamberType = GridManager.get_chamber_type(coords)
	match chamber:
		Enums.ChamberType.ROYAL:
			draw_colored_polygon(poly, Color(0.85, 0.65, 0.25, 0.30))
			draw_rect(rect, color_royal_chamber, false, 1.0)
		Enums.ChamberType.NURSERY:
			draw_colored_polygon(poly, Color(0.78, 0.45, 0.72, 0.30))
			draw_rect(rect, color_nursery, false, 1.0)
		Enums.ChamberType.FOOD_STORE:
			draw_colored_polygon(poly, Color(0.88, 0.62, 0.18, 0.30))
			draw_rect(rect, color_food_store, false, 1.0)


# Returns a polygon for a rectangle with the 4 corners chamfered by radius r.
# Each corner is a small arc of `segs` segments.
func _rounded_rect_polygon(rect: Rect2, r: float, segs: int) -> PackedVector2Array:
	var poly: PackedVector2Array = PackedVector2Array()
	var x0: float = rect.position.x
	var y0: float = rect.position.y
	var x1: float = rect.end.x
	var y1: float = rect.end.y
	r = minf(r, minf(rect.size.x * 0.5, rect.size.y * 0.5))

	# Corner centers
	var corners: Array[Vector2] = [
		Vector2(x0 + r, y0 + r),   # top-left
		Vector2(x1 - r, y0 + r),   # top-right
		Vector2(x1 - r, y1 - r),   # bottom-right
		Vector2(x0 + r, y1 - r),   # bottom-left
	]
	# Start angles for each corner arc (pointing "outward", then sweeping 90°)
	var start_angles: Array[float] = [PI, -PI * 0.5, 0.0, PI * 0.5]

	for ci in range(4):
		var c: Vector2    = corners[ci]
		var a0: float     = start_angles[ci]
		for s in range(segs + 1):
			var t: float  = float(s) / float(segs)
			var angle: float = a0 + t * (PI * 0.5)
			poly.append(c + Vector2(cos(angle), sin(angle)) * r)

	return poly


# Draws a thin earthy rim line on each edge of the tunnel cell that borders a SOIL cell,
# giving the impression of a carved wall rather than a floating void square.
func _draw_soil_rim(coords: Vector2i, rect: Rect2) -> void:
	var gw: int = GridManager.grid_width
	var gh: int = GridManager.grid_height

	# Up
	var up: Vector2i = coords + Vector2i(0, -1)
	if up.y >= 0 and GridManager.get_cell_type(up) == Enums.CellType.SOIL:
		draw_line(rect.position + Vector2(2.0, 0.0),
				  rect.position + Vector2(rect.size.x - 2.0, 0.0),
				  color_soil_rim, 2.5)
	# Down
	var dn: Vector2i = coords + Vector2i(0, 1)
	if dn.y < gh and GridManager.get_cell_type(dn) == Enums.CellType.SOIL:
		draw_line(rect.position + Vector2(2.0, rect.size.y),
				  rect.position + Vector2(rect.size.x - 2.0, rect.size.y),
				  color_soil_rim, 2.5)
	# Left
	var lt: Vector2i = coords + Vector2i(-1, 0)
	if lt.x >= 0 and GridManager.get_cell_type(lt) == Enums.CellType.SOIL:
		draw_line(rect.position + Vector2(0.0, 2.0),
				  rect.position + Vector2(0.0, rect.size.y - 2.0),
				  color_soil_rim, 2.5)
	# Right
	var rt: Vector2i = coords + Vector2i(1, 0)
	if rt.x < gw and GridManager.get_cell_type(rt) == Enums.CellType.SOIL:
		draw_line(rect.position + Vector2(rect.size.x, 2.0),
				  rect.position + Vector2(rect.size.x, rect.size.y - 2.0),
				  color_soil_rim, 2.5)


# ── Dig overlay ────────────────────────────────────────────────────────────────
func _on_draw_overlay() -> void:
	if GridManager == null or _dig_overlay == null:
		return

	var c_size: Vector2 = GridManager.cell_size

	for d_coord in GridManager.dig_queue:
		var d_rect: Rect2 = Rect2(
			float(d_coord.x) * c_size.x, float(d_coord.y) * c_size.y,
			c_size.x, c_size.y
		)
		_dig_overlay.draw_rect(d_rect, color_dig_marker, false, 2.0)
		_dig_overlay.draw_line(d_rect.position, d_rect.position + d_rect.size, color_dig_marker, 1.5)
		_dig_overlay.draw_line(
			Vector2(d_rect.position.x + d_rect.size.x, d_rect.position.y),
			Vector2(d_rect.position.x, d_rect.position.y + d_rect.size.y),
			color_dig_marker, 1.5
		)

		var prog: float = GridManager.get_dig_progress(d_coord)
		if prog > 0.0:
			var bar_rect: Rect2 = Rect2(
				d_rect.position.x + 2.0,
				d_rect.position.y + d_rect.size.y - 6.0,
				(d_rect.size.x - 4.0) * prog, 4.0
			)
			_dig_overlay.draw_rect(bar_rect, Color(0.2, 0.9, 0.2, 0.9))
