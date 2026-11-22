class_name SoilBackground
extends TextureRect

## Процедурный генератор песчано-бежевой почвы (Этап 4: Почва).
## Создает многослойную почву в стиле antcolony.gg:
##   - Верхний слой светлее: #E3C48E
##   - Глубже — чуть темнее и теплее: #D4AE72
##   - Волнистая граница между слоями с пиксельным дизерингом
##   - Вкрапления серых камней (#8A8A8A) и голубоватых кристаллов (#5F7FA8)
##   - Плавное затемнение с глубиной (глубокие недра темнее)
##   - Запекание в ImageTexture один раз при старте с NEAREST фильтром.

const FIXED_SEED: int = 421337
const TEX_WIDTH: int = 700
const TEX_HEIGHT: int = 286

const SOIL_TOP: Color = Color(0.890, 0.769, 0.557, 1.0)   # #E3C48E
const SOIL_DEEP: Color = Color(0.831, 0.682, 0.447, 1.0)  # #D4AE72

const STONE_GREY: Color = Color(0.541, 0.541, 0.541, 1.0) # #8A8A8A
const STONE_BLUE: Color = Color(0.373, 0.498, 0.659, 1.0) # #5F7FA8


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	stretch_mode = TextureRect.STRETCH_SCALE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	generate_soil()


## Процедурная генерация и запекание текстуры почвы
func generate_soil() -> void:
	var rnd: RandomNumberGenerator = RandomNumberGenerator.new()
	rnd.seed = FIXED_SEED
	
	var img: Image = Image.create(TEX_WIDTH, TEX_HEIGHT, false, Image.FORMAT_RGBA8)
	
	# 1. Заливка слоев с волнистой границей, дизерингом и песчаным шумом
	for y in range(TEX_HEIGHT):
		# Коэффициент затемнения с глубиной (1.0 у поверхности -> 0.76 на самом дне)
		var depth_factor: float = 1.0 - (float(y) / float(TEX_HEIGHT)) * 0.24
		
		for x in range(TEX_WIDTH):
			# Волнистая граница слоев почвы (примерно на 1/4 глубины)
			var wave: float = sin(float(x) * 0.018) * 12.0 + cos(float(x) * 0.045) * 6.0 + sin(float(x) * 0.09) * 3.0
			var boundary: float = 65.0 + wave
			
			var dist: float = float(y) - boundary
			var bayer: float = float((x ^ (y * 2)) % 4) / 4.0 - 0.5
			var t_dither: float = dist / 8.0 + bayer
			
			var base_col: Color = SOIL_TOP if t_dither < 0.0 else SOIL_DEEP
			
			# Текстурный органический шум песчинок
			var noise_val: float = rnd.randf_range(-0.025, 0.025)
			if rnd.randf() < 0.008:
				noise_val -= rnd.randf_range(0.05, 0.09) # редкие темные вкрапления
			
			var r: float = clampf((base_col.r + noise_val) * depth_factor, 0.0, 1.0)
			var g: float = clampf((base_col.g + noise_val) * depth_factor, 0.0, 1.0)
			var b: float = clampf((base_col.b + noise_val) * depth_factor, 0.0, 1.0)
			img.set_pixel(x, y, Color(r, g, b, 1.0))
	
	# 2. Вкрапления камней и минералов (серые и голубоватые)
	_draw_mineral_deposits(img, rnd)
	
	texture = ImageTexture.create_from_image(img)


## Отрисовка разбросанных по глубине серых и голубых минеральных отложений
func _draw_mineral_deposits(img: Image, rnd: RandomNumberGenerator) -> void:
	# Массив залежей: [x, y, rx, ry, is_blue]
	var deposits: Array = [
		[80, 85, 12, 7, false],
		[240, 160, 15, 8, false],
		[420, 110, 14, 8, false],
		[590, 210, 16, 9, false],
		[150, 240, 13, 7, false],
		[330, 250, 18, 10, false],
		[520, 140, 14, 10, true],
		[190, 190, 11, 8, true],
		[640, 95, 12, 7, true]
	]
	
	for dep in deposits:
		var cx: int = dep[0]
		var cy: int = dep[1]
		var rx: int = dep[2]
		var ry: int = dep[3]
		var is_blue: bool = dep[4]
		var col: Color = STONE_BLUE if is_blue else STONE_GREY
		
		for dy in range(-ry - 2, ry + 3):
			for dx in range(-rx - 2, rx + 3):
				var angle: float = atan2(float(dy), float(dx))
				var wobble: float = 1.0 + sin(angle * 3.0) * 0.15 + cos(angle * 5.0) * 0.1
				var d_norm: float = (pow(float(dx) / float(rx), 2.0) + pow(float(dy) / float(ry), 2.0)) / (wobble * wobble)
				
				if d_norm <= 1.0:
					var px: int = cx + dx
					var py: int = cy + dy
					if px >= 0 and px < TEX_WIDTH and py >= 0 and py < TEX_HEIGHT:
						if d_norm > 0.7 and rnd.randf() < 0.35:
							continue # мягкий дизеринг по краям камня
						var speck: float = rnd.randf_range(-0.04, 0.04)
						var pixel_col: Color = Color(
							clampf(col.r + speck, 0.0, 1.0),
							clampf(col.g + speck, 0.0, 1.0),
							clampf(col.b + speck, 0.0, 1.0),
							1.0
						)
						img.set_pixel(px, py, pixel_col)
