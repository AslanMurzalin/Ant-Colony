class_name GridView
extends Node2D

## Визуальный рендерер подземной сетки в органичном пиксельном стиле antcolony.gg.
## Генерирует сглаженные прогрызенные туннели с мягкими углами, органичными неровностями,
## ambient occlusion вдоль стен и светлым ободком осыпавшейся почвы.
## Квантуется в пиксельную сетку 4x4 (480x320 px текстура) с texture_filter = NEAREST.

const GRID_SCALE: int = 8 # 8 пикселей маски на клетку 32x32 (1 px маски = 4 px в мире)
const TEX_W: int = 480     # 60 клеток * 8
const TEX_H: int = 320     # 40 клеток * 8

# Цвета туннелей
const COLOR_TUNNEL_VOID: Color = Color(0.133, 0.078, 0.039, 1.0)  # #22140A глубокое ядро
const COLOR_TUNNEL_BODY: Color = Color(0.290, 0.180, 0.102, 1.0)  # #4A2E1A тело туннеля
const COLOR_TUNNEL_AO:   Color = Color(0.102, 0.059, 0.027, 1.0)  # #1A0F07 тень стен
const COLOR_SOIL_RIM:    Color = Color(0.588, 0.412, 0.255, 0.70) # #966941 ободок осыпи

# Цвета специальных элементов
var color_rock:          Color = Color(0.32, 0.30, 0.28, 1.0)
var color_water:         Color = Color(0.29, 0.56, 0.85, 0.75)
var color_dig_marker:    Color = Color(0.94, 0.54, 0.14, 1.0) # Тонкая желто-оранжевая рамка
var color_royal_chamber: Color = Color(0.95, 0.75, 0.20, 1.0)
var color_nursery:       Color = Color(0.78, 0.45, 0.72, 1.0)
var color_food_store:    Color = Color(0.88, 0.62, 0.18, 1.0)

# Старые параметры для обратной совместимости
const CORNER_R: float = 5.0
const CORNER_SEGS: int = 4
var color_tunnel_body: Color = COLOR_TUNNEL_BODY
var color_tunnel_void: Color = COLOR_TUNNEL_VOID
var color_tunnel_ao: Color = COLOR_TUNNEL_AO
var color_tunnel_wall: Color = Color(0.35, 0.22, 0.125, 1.0)
var color_soil_rim: Color = COLOR_SOIL_RIM

# Внутреннее состояние текстуры
var _tunnel_texture: ImageTexture = null
var _is_tunnel_dirty: bool = true
var _dig_overlay: Node2D = null
var _progress_throttle_timer: float = 0.0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = 0
	
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

	_is_tunnel_dirty = true
	queue_redraw()


func _process(delta: float) -> void:
	if _progress_throttle_timer > 0.0:
		_progress_throttle_timer -= delta


func _on_cell_modified(_coords: Vector2i, _new_type: Enums.CellType) -> void:
	_is_tunnel_dirty = true
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
	_is_tunnel_dirty = true
	queue_redraw()


# ── Построение сглаженной маски туннелей (Blur + Threshold + AO) ───────────────
func _rebuild_tunnel_texture() -> void:
	if GridManager == null:
		return

	var s_row: int = GridManager.surface_row
	var gw: int = GridManager.grid_width
	var gh: int = GridManager.grid_height

	# 1. Заполняем бинарную маску вырытых клеток
	var mask: PackedFloat32Array = PackedFloat32Array()
	mask.resize(TEX_W * TEX_H)
	mask.fill(0.0)

	for cy in range(s_row, gh):
		for cx in range(gw):
			var coords: Vector2i = Vector2i(cx, cy)
			if GridManager.get_cell_type(coords) == Enums.CellType.AIR:
				var base_y: int = cy * GRID_SCALE
				var base_x: int = cx * GRID_SCALE
				for py in range(base_y, base_y + GRID_SCALE):
					var row_idx: int = py * TEX_W
					for px in range(base_x, base_x + GRID_SCALE):
						mask[row_idx + px] = 1.0

	# 2. Сепарабельный Box Blur 5x5 (радиус 2)
	# Горизонтальный проход
	var temp: PackedFloat32Array = PackedFloat32Array()
	temp.resize(TEX_W * TEX_H)
	for y in range(TEX_H):
		var row_offset: int = y * TEX_W
		for x in range(TEX_W):
			var s: float = 0.0
			for k in range(-2, 3):
				var nx: int = clampi(x + k, 0, TEX_W - 1)
				s += mask[row_offset + nx]
			temp[row_offset + x] = s * 0.2

	# Вертикальный проход и цветовая генерация в Image
	var img: Image = Image.create(TEX_W, TEX_H, false, Image.FORMAT_RGBA8)

	for y in range(TEX_H):
		var depth_factor: float = 1.0 - (float(y) / float(TEX_H)) * 0.16
		for x in range(TEX_W):
			var s: float = 0.0
			for k in range(-2, 3):
				var ny: int = clampi(y + k, 0, TEX_H - 1)
				s += temp[ny * TEX_W + x]
			var val: float = s * 0.2

			# Органический шум неровности краев стен
			var noise: float = sin(float(x) * 0.45) * cos(float(y) * 0.5) * 0.05 + sin(float(x) * 1.2 + float(y) * 0.8) * 0.025
			var thresh: float = 0.38 + noise

			if val < thresh - 0.12:
				img.set_pixel(x, y, Color(0.0, 0.0, 0.0, 0.0))
			elif val < thresh:
				# Ободок осыпавшейся земли
				var t_rim: float = (val - (thresh - 0.12)) / 0.12
				var alpha: float = 0.70 * t_rim
				img.set_pixel(x, y, Color(COLOR_SOIL_RIM.r, COLOR_SOIL_RIM.g, COLOR_SOIL_RIM.b, alpha))
			else:
				# Внутри туннеля: Ambient Occlusion у стен -> тело -> темное ядро в центре
				var t_inner: float = clampf((val - thresh) / (1.0 - thresh), 0.0, 1.0)
				var pixel_col: Color
				if t_inner < 0.25:
					var t_ao: float = t_inner / 0.25
					pixel_col = COLOR_TUNNEL_AO.lerp(COLOR_TUNNEL_BODY, t_ao)
				else:
					var t_core: float = (t_inner - 0.25) / 0.75
					pixel_col = COLOR_TUNNEL_BODY.lerp(COLOR_TUNNEL_VOID, t_core)

				# Затемнение с глубиной
				pixel_col.r *= depth_factor
				pixel_col.g *= depth_factor
				pixel_col.b *= depth_factor

				# Оттенок камер (Royal, Nursery, Storage)
				var cx: int = x / GRID_SCALE
				var cy: int = y / GRID_SCALE
				var chamber: Enums.ChamberType = GridManager.get_chamber_type(Vector2i(cx, cy))
				match chamber:
					Enums.ChamberType.ROYAL:
						pixel_col = pixel_col.lerp(Color(0.95, 0.75, 0.20), 0.22)
					Enums.ChamberType.NURSERY:
						pixel_col = pixel_col.lerp(Color(0.78, 0.45, 0.72), 0.22)
					Enums.ChamberType.FOOD_STORE:
						pixel_col = pixel_col.lerp(Color(0.88, 0.62, 0.18), 0.22)

				pixel_col.a = 1.0
				img.set_pixel(x, y, pixel_col)

	_tunnel_texture = ImageTexture.create_from_image(img)
	_is_tunnel_dirty = false


# ── Отрисовка GridView ─────────────────────────────────────────────────────────
func _draw() -> void:
	if GridManager == null:
		return

	# Перестройка сглаженной маски туннелей при изменении ячеек
	if _is_tunnel_dirty or _tunnel_texture == null:
		_rebuild_tunnel_texture()

	var c_size: Vector2 = GridManager.cell_size
	var gw: int = GridManager.grid_width
	var gh: int = GridManager.grid_height
	var s_row: int = GridManager.surface_row

	# 1. Отрисовка сглаженной текстуры туннелей
	if _tunnel_texture != null:
		var world_rect: Rect2 = Rect2(0.0, 0.0, float(gw) * c_size.x, float(gh) * c_size.y)
		draw_texture_rect(_tunnel_texture, world_rect, false)

	# 2. Отрисовка камней и воды
	for y in range(s_row, gh):
		for x in range(gw):
			var coords: Vector2i = Vector2i(x, y)
			var c_type: Enums.CellType = GridManager.get_cell_type(coords)
			var rect: Rect2 = Rect2(float(x) * c_size.x, float(y) * c_size.y, c_size.x, c_size.y)

			match c_type:
				Enums.CellType.ROCK:
					draw_rect(rect, color_rock)
					draw_rect(rect, color_rock.lightened(0.2), false, 1.0)
				Enums.CellType.WATER:
					draw_rect(rect, color_water)

	# 3. Маркеры специализированных камер
	_draw_chamber_icons()


## Отрисовка аккуратных компактных значков камер
func _draw_chamber_icons() -> void:
	if GridManager == null:
		return

	var c_size: Vector2 = GridManager.cell_size
	var s_row: int = GridManager.surface_row
	var gh: int = GridManager.grid_height
	var gw: int = GridManager.grid_width

	for y in range(s_row, gh):
		for x in range(gw):
			var coords: Vector2i = Vector2i(x, y)
			if GridManager.get_cell_type(coords) != Enums.CellType.AIR:
				continue
			var chamber: Enums.ChamberType = GridManager.get_chamber_type(coords)
			if chamber == Enums.ChamberType.NONE or chamber == Enums.ChamberType.ROYAL:
				continue

			var center: Vector2 = Vector2((float(x) + 0.5) * c_size.x, (float(y) + 0.5) * c_size.y)
			match chamber:
				Enums.ChamberType.NURSERY:
					# Розово-белая иконка инкубатора (маленькое яйцо)
					draw_circle(center, 3.5, Color(0.78, 0.45, 0.72, 0.8))
					draw_circle(center + Vector2(-0.5, -0.5), 2.2, Color(0.98, 0.95, 0.90, 0.95))
				Enums.ChamberType.FOOD_STORE:
					# Золотистая иконка склада запасов (зернышко)
					draw_circle(center, 3.5, Color(0.88, 0.62, 0.18, 0.8))
					draw_circle(center + Vector2(0.0, 0.0), 2.0, Color(1.0, 0.85, 0.4, 0.95))


# ── Слой разметки копания (Dig Overlay) ─────────────────────────────────────────
func _on_draw_overlay() -> void:
	if GridManager == null or _dig_overlay == null:
		return

	var c_size: Vector2 = GridManager.cell_size

	for d_coord in GridManager.dig_queue:
		var d_rect: Rect2 = Rect2(
			float(d_coord.x) * c_size.x, float(d_coord.y) * c_size.y,
			c_size.x, c_size.y
		)
		# Тонкая аккуратная желтая рамка
		_dig_overlay.draw_rect(d_rect, color_dig_marker, false, 1.0)
		_dig_overlay.draw_line(d_rect.position, d_rect.position + d_rect.size, color_dig_marker, 0.8)
		_dig_overlay.draw_line(
			Vector2(d_rect.position.x + d_rect.size.x, d_rect.position.y),
			Vector2(d_rect.position.x, d_rect.position.y + d_rect.size.y),
			color_dig_marker, 0.8
		)

		var prog: float = GridManager.get_dig_progress(d_coord)
		if prog > 0.0:
			var bar_rect: Rect2 = Rect2(
				d_rect.position.x + 2.0,
				d_rect.position.y + d_rect.size.y - 4.0,
				(d_rect.size.x - 4.0) * prog, 2.5
			)
			_dig_overlay.draw_rect(bar_rect, Color(0.2, 0.9, 0.2, 0.9))


# ── Устаревшие методы для обратной совместимости с контрактами ─────────────────
func _draw_tunnel_cell(_coords: Vector2i, _rect: Rect2) -> void:
	pass

func _draw_tunnel_ambient_occlusion(_coords: Vector2i, _rect: Rect2) -> void:
	pass

func _draw_soil_rim(_coords: Vector2i, _rect: Rect2) -> void:
	pass

func _rounded_rect_polygon(rect: Rect2, _r: float, _segs: int) -> PackedVector2Array:
	return PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])
