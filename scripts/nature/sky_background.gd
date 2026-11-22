class_name SkyBackground
extends TextureRect

## Процедурный генератор пиксельного неба, облаков и холмов дальнего плана (Этап 1).
## Генерирует мозаичную пиксельную текстуру при старте и запекает в ImageTexture один раз.
##
## Палитра референса antcolony.gg:
##   - Небо: #8EC5E8 -> #D6ECF7 (пиксельный градиент с дизерингом)
##   - Облака: #FFFFFF со светотенью #C7E2F2
##   - Дальний холм (дымка): #A8C5B8
##   - Средний холм: #8FA888
##   - Ближний холм: #6E9364
##   - База травы у горизонта: #5A9A3C

const FIXED_SEED: int = 133742
const TEX_WIDTH: int = 700
const TEX_HEIGHT: int = 164

# Цветовая палитра
const SKY_TOP: Color = Color(0.557, 0.773, 0.910, 1.0)   # #8EC5E8
const SKY_BOT: Color = Color(0.839, 0.925, 0.969, 1.0)   # #D6ECF7
const CLOUD_WHITE: Color = Color(1.0, 1.0, 1.0, 1.0)     # #FFFFFF
const CLOUD_SHADOW: Color = Color(0.780, 0.886, 0.949, 1.0) # #C7E2F2

const HILL_FAR: Color = Color(0.659, 0.773, 0.722, 1.0)  # #A8C5B8
const HILL_MID: Color = Color(0.561, 0.659, 0.533, 1.0)  # #8FA888
const HILL_NEAR: Color = Color(0.431, 0.576, 0.392, 1.0) # #6E9364
const GRASS_BASE: Color = Color(0.353, 0.604, 0.235, 1.0) # #5A9A3C


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	stretch_mode = TextureRect.STRETCH_SCALE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	generate_sky_and_hills()


## Процедурная генерация и запекание текстуры неба и холмов
func generate_sky_and_hills() -> void:
	var img: Image = Image.create(TEX_WIDTH, TEX_HEIGHT, false, Image.FORMAT_RGBA8)
	
	# 1. Градиент неба с дизерингом
	_render_sky_gradient(img)
	
	# 2. Пиксельные облака
	_render_clouds(img)
	
	# 3. Три слоя холмов дальнего плана
	_render_hills(img)
	
	texture = ImageTexture.create_from_image(img)


## Отрисовка вертикального градиента неба с пиксельным дизерингом
func _render_sky_gradient(img: Image) -> void:
	for y in range(TEX_HEIGHT):
		var t: float = float(y) / float(TEX_HEIGHT)
		for x in range(TEX_WIDTH):
			# 4x4 пиксельный дизеринг для мозаичного эффекта
			var bayer: float = float((x ^ (y * 3)) % 4) / 4.0 - 0.5
			var t_dither: float = clampf(t + bayer * 0.04, 0.0, 1.0)
			var col: Color = SKY_TOP.lerp(SKY_BOT, t_dither)
			img.set_pixel(x, y, col)


## Отрисовка пиксельных облаков с плоским низом и подсветкой
func _render_clouds(img: Image) -> void:
	# Координаты облаков на экране и чуть выше
	var clouds: Array[Vector3] = [
		Vector3(80.0, 96.0, 0.9),
		Vector3(210.0, 92.0, 1.15),
		Vector3(350.0, 98.0, 1.3),
		Vector3(500.0, 94.0, 0.85),
		Vector3(630.0, 96.0, 1.1),
		Vector3(140.0, 42.0, 1.2),
		Vector3(390.0, 36.0, 1.35),
		Vector3(590.0, 48.0, 1.0)
	]
	
	for c in clouds:
		_draw_pixel_cloud(img, int(c.x), int(c.y), c.z)


## Рисует одно пиксельное облако
func _draw_pixel_cloud(img: Image, cx: int, cy: int, scale: float) -> void:
	var puffs: Array[Vector3] = [
		Vector3(0, 0, 14),
		Vector3(-12, 2, 10),
		Vector3(12, 2, 11),
		Vector3(-22, 5, 8),
		Vector3(22, 4, 8),
		Vector3(0, -4, 10),
		Vector3(-6, -3, 8),
		Vector3(6, -3, 8)
	]
	var base_cutoff: int = cy + int(7.0 * scale)
	
	for p in puffs:
		var rad: int = int(p.z * scale)
		for dy in range(-rad, rad + 1):
			for dx in range(-rad, rad + 1):
				if dx * dx + dy * dy <= rad * rad:
					var gx: int = cx + int(p.x * scale) + dx
					var gy: int = cy + int(p.y * scale) + dy
					if gy <= base_cutoff and gx >= 0 and gx < TEX_WIDTH and gy >= 0 and gy < TEX_HEIGHT:
						var is_shadow: bool = gy >= base_cutoff - int(3.0 * scale) or (dy > float(rad) * 0.45)
						var col: Color = CLOUD_SHADOW if is_shadow else CLOUD_WHITE
						img.set_pixel(gx, gy, col)


## Отрисовка 3 слоев холмов с атмосферной дымкой
func _render_hills(img: Image) -> void:
	# Слой 1: Дальний холм (дымка)
	for x in range(TEX_WIDTH):
		var h1: int = 124 + int(sin(float(x) * 0.014 + 0.5) * 11.0 + cos(float(x) * 0.028) * 5.0)
		for y in range(h1, TEX_HEIGHT):
			var dither: float = float((x + y) % 2) * 0.015
			var col: Color = Color(HILL_FAR.r + dither, HILL_FAR.g + dither, HILL_FAR.b + dither, 1.0)
			img.set_pixel(x, y, col)
	
	# Слой 2: Средний холм
	for x in range(TEX_WIDTH):
		var h2: int = 136 + int(sin(float(x) * 0.021 + 2.1) * 9.0 + cos(float(x) * 0.042) * 4.0)
		for y in range(h2, TEX_HEIGHT):
			var dither: float = float((x ^ y) % 3) * 0.012
			var col: Color = Color(HILL_MID.r + dither, HILL_MID.g + dither, HILL_MID.b + dither, 1.0)
			img.set_pixel(x, y, col)
	
	# Слой 3: Ближний холм
	for x in range(TEX_WIDTH):
		var h3: int = 148 + int(sin(float(x) * 0.017 + 4.2) * 7.0 + sin(float(x) * 0.035) * 4.0)
		for y in range(h3, TEX_HEIGHT):
			var dither: float = float((x + y * 2) % 3) * 0.01
			var col: Color = Color(HILL_NEAR.r + dither, HILL_NEAR.g + dither, HILL_NEAR.b + dither, 1.0)
			img.set_pixel(x, y, col)
	
	# Полоса травы у горизонта (плавный переход к поверхности земли y=158..164)
	for x in range(TEX_WIDTH):
		for y in range(158, TEX_HEIGHT):
			var blend: float = float(y - 158) / 6.0
			var curr: Color = img.get_pixel(x, y)
			img.set_pixel(x, y, curr.lerp(GRASS_BASE, blend * 0.8))
