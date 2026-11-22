class_name SurfaceDecorSpawner
extends Node2D

## Спавнер декораций поверхности (Этап 3: Трава, цветы, мелкие детали поверхности).
## Создает визуальный стиль как на референсе браузерной игры Ant Colony (antcolony.gg):
##   - 2 слоя деревьев: дальний (меньше, темнее) и ближний (крупнее, сочнее).
##   - Кроны: пуантилизм/мозаика из тысяч мелких разноцветных точек (зеленый, розовый, белый, красный).
##   - Стволы: фактурные коричневые со светотенью и легким расширением у корней.
##   - Корни: рекурсивное ветвление, извилистые, сужающиеся, без прямых линий.
##   - Трава: зубчатый край, пучки разной высоты, желтые/розовые/красные цветы на стебельках, камешки и кустики.
##   - Запекание в ImageTexture один раз при старте (60 FPS, 0 draw calls в кадрах).

@export var surface_y: float = 256.0           ## Высота поверхности земли (Y = row 8 * 32)
@export var map_width: float = 1920.0          ## Ширина игровой зоны
@export var entrance_x: float = 976.0          ## Координата входа в муравейник
@export var entrance_clear_radius: float = 75.0 ## Зона вокруг входа в муравейник

const FIXED_SEED: int = 771234

# Палитра крон и листвы
const COLOR_FOLIAGE_DARK_BG: Color = Color(0.188, 0.376, 0.141, 1.0)
const COLOR_FOLIAGE_MID_BG: Color = Color(0.247, 0.482, 0.188, 1.0)
const COLOR_FOLIAGE_LIGHT_BG: Color = Color(0.353, 0.608, 0.255, 1.0)

const COLOR_FOLIAGE_DARK_FG: Color = Color(0.224, 0.451, 0.169, 1.0)
const COLOR_FOLIAGE_MID_FG: Color = Color(0.310, 0.604, 0.227, 1.0)  # #4F9A3A
const COLOR_FOLIAGE_LIGHT_FG: Color = Color(0.482, 0.761, 0.353, 1.0) # #7BC25A
const COLOR_FOLIAGE_BRIGHT_FG: Color = Color(0.588, 0.855, 0.431, 1.0)

const COLOR_FLOWER_PINK: Color = Color(0.949, 0.655, 0.765, 1.0)   # #F2A7C3
const COLOR_FLOWER_WHITE: Color = Color(1.0, 1.0, 1.0, 1.0)         # #FFFFFF
const COLOR_FRUIT_RED: Color = Color(0.851, 0.227, 0.227, 1.0)      # #D93A3A

# Палитра ствола и корней
const COLOR_TRUNK_LIGHT: Color = Color(0.451, 0.282, 0.165, 1.0)
const COLOR_TRUNK_MID: Color = Color(0.345, 0.204, 0.110, 1.0)
const COLOR_TRUNK_DARK: Color = Color(0.235, 0.133, 0.063, 1.0)

const COLOR_ROOT_MAIN: Color = Color(0.320, 0.180, 0.080, 1.0)     # #522E14
const COLOR_ROOT_SHADOW: Color = Color(0.200, 0.100, 0.040, 1.0)   # #331A0A

# Палитра травы и цветов поверхности
const COLOR_GRASS_DARK: Color = Color(0.243, 0.478, 0.165, 1.0)    # #3E7A2A
const COLOR_GRASS_MID: Color = Color(0.353, 0.604, 0.235, 1.0)     # #5A9A3C
const COLOR_GRASS_LIGHT: Color = Color(0.447, 0.702, 0.314, 1.0)   # #72B350
const COLOR_GRASS_BRIGHT: Color = Color(0.553, 0.816, 0.400, 1.0)  # #8DD066
const COLOR_STEM: Color = Color(0.275, 0.529, 0.176, 1.0)

const COLOR_FLOWER_YELLOW: Color = Color(0.949, 0.761, 0.114, 1.0) # #F2C21D
const COLOR_STONE_LIGHT: Color = Color(0.541, 0.541, 0.541, 1.0)   # #8A8A8A
const COLOR_STONE_DARK: Color = Color(0.373, 0.373, 0.373, 1.0)    # #5F5F5F
const COLOR_BUSH_DARK: Color = Color(0.184, 0.353, 0.125, 1.0)
const COLOR_BUSH_LIGHT: Color = Color(0.255, 0.471, 0.176, 1.0)


func _ready() -> void:
	z_index = 0
	generate_surface_decorations()


## Генерация всех деревьев двух слоев, полосы травы и цветов
func generate_surface_decorations() -> void:
	for child in get_children():
		child.queue_free()

	# 1. Дальний слой деревьев (Back trees: z_index = 0, чуть меньше и темнее)
	var back_tree_xs: Array[float] = [
		190.0, 380.0, 580.0, 780.0, 1180.0, 1380.0, 1580.0, 1780.0
	]
	var back_seed_idx: int = 100
	for bx in back_tree_xs:
		if absf(bx - entrance_x) > entrance_clear_radius:
			_spawn_tree_with_roots(bx, surface_y, true, 0.82, back_seed_idx)
			back_seed_idx += 37

	# 2. Ближний слой деревьев (Front trees: z_index = 2, пышные, сочные, с корнями)
	var front_tree_xs: Array[float] = [
		110.0, 290.0, 480.0, 680.0, 870.0, 1090.0, 1290.0, 1490.0, 1690.0, 1860.0
	]
	var front_seed_idx: int = 500
	for fx in front_tree_xs:
		if absf(fx - entrance_x) > entrance_clear_radius:
			_spawn_tree_with_roots(fx, surface_y, false, 1.08, front_seed_idx)
			front_seed_idx += 43

	# 3. Полоса травы с полевыми цветами, кустами и камешками (Этап 3)
	_spawn_grass_strip()


## Создание одного дерева (крона + ствол + корни)
func _spawn_tree_with_roots(pos_x: float, pos_y: float, is_background: bool = false, scale_factor: float = 1.0, tree_seed: int = 123) -> void:
	var tree_node: Node2D = Node2D.new()
	tree_node.position = Vector2(pos_x, pos_y)
	
	# А. Корни под землей (только для переднего слоя, чтобы не перегружать недра)
	if not is_background:
		var root_tex: ImageTexture = _bake_roots(tree_seed)
		var root_sprite: Sprite2D = Sprite2D.new()
		root_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		root_sprite.texture = root_tex
		root_sprite.centered = true
		root_sprite.offset = Vector2(0.0, float(root_tex.get_height()) * 0.5)
		root_sprite.z_index = 0
		tree_node.add_child(root_sprite)

	# Б. Ствол и крона дерева над землей
	var canopy_tex: ImageTexture = _bake_tree_canopy_and_trunk(scale_factor, is_background, tree_seed)
	var canopy_sprite: Sprite2D = Sprite2D.new()
	canopy_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	canopy_sprite.texture = canopy_tex
	canopy_sprite.centered = true
	canopy_sprite.offset = Vector2(0.0, -float(canopy_tex.get_height()) * 0.5)
	canopy_sprite.z_index = 0 if is_background else 2
	tree_node.add_child(canopy_sprite)

	add_child(tree_node)


## Создание запеченной полосы травы с цветами вдоль всей поверхности карты
func _spawn_grass_strip() -> void:
	var grass_tex: ImageTexture = _bake_grass_strip()
	var grass_sprite: Sprite2D = Sprite2D.new()
	grass_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	grass_sprite.texture = grass_tex
	grass_sprite.centered = false
	# Линия основания травы (base_y = 36) ложится ровно на surface_y (256.0)
	grass_sprite.position = Vector2(-200.0, surface_y - 36.0)
	grass_sprite.z_index = 1
	add_child(grass_sprite)


## Запекание полосы травы, цветов, кустов и камешков в единый ImageTexture
func _bake_grass_strip() -> ImageTexture:
	var rnd: RandomNumberGenerator = RandomNumberGenerator.new()
	rnd.seed = FIXED_SEED + 9991
	
	var gw: int = 2320
	var gh: int = 38 # Высота 38px: base_y = 36, травинки растут вверх, только 2px основание внизу
	var img: Image = Image.create(gw, gh, false, Image.FORMAT_RGBA8)
	
	var base_y: int = 36
	var ent_x: int = int(entrance_x) + 200 # смещение за счет x = -200
	
	# 1. Трава с зубчатым краем и пучками травинок
	for x in range(gw):
		var dist_to_ent: int = absi(x - ent_x)
		var is_ent: bool = dist_to_ent < 80
		var blade_h: int
		if is_ent:
			blade_h = rnd.randi_range(1, 3) # низкий аккуратный срез у входа
		else:
			var wave: float = sin(float(x) * 0.08) * 3.0 + sin(float(x) * 0.02) * 4.0
			blade_h = clampi(int(7.0 + wave) + rnd.randi_range(-3, 3), 4, 15)
		
		var top_y: int = base_y - blade_h
		for y in range(top_y, gh):
			var roll: float = rnd.randf()
			var rel: float = float(y - top_y) / float(gh - top_y)
			var col: Color
			if rel < 0.25:
				col = COLOR_GRASS_BRIGHT if roll < 0.3 else COLOR_GRASS_LIGHT
			elif rel < 0.6:
				col = COLOR_GRASS_LIGHT if roll < 0.4 else COLOR_GRASS_MID
			else:
				col = COLOR_GRASS_MID if roll < 0.3 else COLOR_GRASS_DARK
			img.set_pixel(x, y, col)
	
	# 2. Мелкие серые камешки
	var num_stones: int = 28
	for _s in range(num_stones):
		var sx: int = rnd.randi_range(20, gw - 20)
		if absi(sx - ent_x) < 70:
			continue
		var sw: int = rnd.randi_range(3, 6)
		var sh: int = rnd.randi_range(2, 4)
		var sy: int = base_y - rnd.randi_range(0, 2)
		for dx in range(sw):
			for dy in range(sh):
				if (dx == 0 and dy == 0) or (dx == sw - 1 and dy == 0):
					continue
				var px: int = sx + dx
				var py: int = sy + dy
				if px >= 0 and px < gw and py >= 0 and py < gh:
					var scol: Color = COLOR_STONE_LIGHT if dy == 0 else COLOR_STONE_DARK
					img.set_pixel(px, py, scol)
	
	# 3. 5 невысоких кустиков тёмно-зелёного цвета у оснований деревьев
	var bush_xs: Array[int] = [
		110 + 200 + 20, 480 + 200 - 22, 870 + 200 - 26, 1290 + 200 + 24, 1690 + 200 - 18
	]
	for bx in bush_xs:
		var bw: int = rnd.randi_range(16, 24)
		var bh: int = rnd.randi_range(9, 14)
		for dy in range(-bh, 2):
			for dx in range(-bw / 2, bw / 2 + 1):
				var nx: float = float(dx) / (float(bw) * 0.5)
				var ny: float = float(dy) / float(bh)
				if nx * nx + ny * ny <= 1.0:
					var px: int = bx + dx
					var py: int = base_y + dy
					if px >= 0 and px < gw and py >= 0 and py < gh:
						var bcol: Color = COLOR_BUSH_LIGHT if (rnd.randf() < 0.35 and dy < -int(float(bh) * 0.3)) else COLOR_BUSH_DARK
						img.set_pixel(px, py, bcol)
	
	# 4. Тонкие стебельки с разноцветными цветами
	var num_flowers: int = 70
	for _f in range(num_flowers):
		var fx: int = rnd.randi_range(15, gw - 15)
		if absi(fx - ent_x) < 85:
			continue
		var stem_h: int = rnd.randi_range(12, 26)
		var flower_y: int = base_y - stem_h
		var lean: int = [-1, 0, 1].pick_random()
		
		# Стебелек в 1px
		for sy in range(flower_y + 3, base_y):
			var prog: float = float(sy - flower_y) / float(stem_h)
			var cur_fx: int = fx + int(float(lean) * (1.0 - prog) * 3.0)
			if cur_fx >= 0 and cur_fx < gw and sy >= 0 and sy < gh:
				img.set_pixel(cur_fx, sy, COLOR_STEM)
		
		# Цветок (размер 3-5px)
		var f_roll: float = rnd.randf()
		var f_col: Color = COLOR_FLOWER_YELLOW if f_roll < 0.45 else (COLOR_FLOWER_PINK if f_roll < 0.8 else COLOR_FRUIT_RED)
		var f_center: Color = Color(1.0, 1.0, 0.85, 1.0) if f_col != COLOR_FLOWER_YELLOW else Color.WHITE
		var f_size: int = [3, 4, 5].pick_random()
		var top_fx: int = fx + lean * 3
		var half_s: int = f_size / 2
		
		for fdy in range(-half_s, half_s + 1):
			for fdx in range(-half_s, half_s + 1):
				if absi(fdx) + absi(fdy) <= half_s + 1:
					var px: int = top_fx + fdx
					var py: int = flower_y + fdy
					if px >= 0 and px < gw and py >= 0 and py < gh:
						var c: Color = f_center if (fdx == 0 and fdy == 0) else f_col
						img.set_pixel(px, py, c)
	
	return ImageTexture.create_from_image(img)


## Запекание кроны и ствола дерева в ImageTexture
func _bake_tree_canopy_and_trunk(scale_factor: float, is_background: bool, tree_seed: int) -> ImageTexture:
	var rnd: RandomNumberGenerator = RandomNumberGenerator.new()
	rnd.seed = FIXED_SEED + tree_seed
	
	var tw: int = int(240.0 * scale_factor)
	var th: int = int(260.0 * scale_factor)
	var img: Image = Image.create(tw, th, false, Image.FORMAT_RGBA8)
	
	var trunk_w: int = int(14.0 * scale_factor)
	var trunk_h: int = int(120.0 * scale_factor)
	var trunk_x: int = tw / 2
	var trunk_base_y: int = th - 2
	
	# 1. Ствол дерева с фактурной корой, левым бликом и правой тенью
	for y in range(trunk_base_y - trunk_h, trunk_base_y):
		var prog: float = float(y - (trunk_base_y - trunk_h)) / float(trunk_h)
		var flare: int = int(prog * prog * 4.0 * scale_factor)
		var hw: int = (trunk_w / 2) + flare
		for x in range(trunk_x - hw, trunk_x + hw + 1):
			var jitter: float = rnd.randf_range(-0.04, 0.04)
			var tx: float = float(x - (trunk_x - hw)) / float(maxi(1, hw * 2))
			var col: Color = COLOR_TRUNK_LIGHT if tx < 0.35 else (COLOR_TRUNK_DARK if tx > 0.65 else COLOR_TRUNK_MID)
			if is_background:
				col = col.darkened(0.2)
			var final_col: Color = Color(clampf(col.r + jitter, 0.0, 1.0), clampf(col.g + jitter, 0.0, 1.0), clampf(col.b + jitter, 0.0, 1.0), 1.0)
			img.set_pixel(x, y, final_col)
	
	# 2. Мозаичная крона (пуантилизм из тысяч разноцветных точек)
	var canopy_cy: int = trunk_base_y - trunk_h - int(12.0 * scale_factor)
	var cr: int = int(54.0 * scale_factor)
	var clusters: Array[Vector3] = [
		Vector3(0, 0, cr),
		Vector3(-int(30.0 * scale_factor), int(8.0 * scale_factor), int(float(cr) * 0.78)),
		Vector3(int(30.0 * scale_factor), int(8.0 * scale_factor), int(float(cr) * 0.78)),
		Vector3(-int(18.0 * scale_factor), -int(16.0 * scale_factor), int(float(cr) * 0.82)),
		Vector3(int(18.0 * scale_factor), -int(16.0 * scale_factor), int(float(cr) * 0.82)),
		Vector3(0, -int(26.0 * scale_factor), int(float(cr) * 0.72))
	]
	
	for cl in clusters:
		var cx: int = trunk_x + int(cl.x)
		var cy: int = canopy_cy + int(cl.y)
		var rad: int = int(cl.z)
		var num_dots: int = int(float(rad * rad) * 1.65)
		
		for _d in range(num_dots):
			var ang: float = rnd.randf() * TAU
			var dist: float = pow(rnd.randf(), 0.65) * float(rad)
			var px: int = cx + int(cos(ang) * dist)
			var py: int = cy + int(sin(ang) * dist)
			
			if px >= 0 and px < tw and py >= 0 and py < th:
				var rel_y: float = float(py - (canopy_cy - int(38.0 * scale_factor))) / float(maxi(1, int(76.0 * scale_factor)))
				var roll: float = rnd.randf()
				var dot_col: Color
				
				if not is_background and roll < 0.025:
					dot_col = COLOR_FRUIT_RED
				elif not is_background and roll < 0.075:
					dot_col = COLOR_FLOWER_PINK
				elif not is_background and roll < 0.13:
					dot_col = COLOR_FLOWER_WHITE
				elif roll < 0.38:
					dot_col = (COLOR_FOLIAGE_BRIGHT_FG if rel_y < 0.55 else COLOR_FOLIAGE_MID_FG) if not is_background else COLOR_FOLIAGE_LIGHT_BG
				elif roll < 0.75:
					dot_col = (COLOR_FOLIAGE_MID_FG if rel_y < 0.75 else COLOR_FOLIAGE_DARK_FG) if not is_background else COLOR_FOLIAGE_MID_BG
				else:
					dot_col = COLOR_FOLIAGE_DARK_FG if not is_background else COLOR_FOLIAGE_DARK_BG
				
				# 2x2 пиксельная точка
				for ddx in range(2):
					for ddy in range(2):
						var gx: int = px + ddx
						var gy: int = py + ddy
						if gx >= 0 and gx < tw and gy >= 0 and gy < th:
							img.set_pixel(gx, gy, dot_col)
	
	return ImageTexture.create_from_image(img)


## Запекание извилистых ветвящихся корней в ImageTexture
func _bake_roots(tree_seed: int) -> ImageTexture:
	var rnd: RandomNumberGenerator = RandomNumberGenerator.new()
	rnd.seed = FIXED_SEED + tree_seed * 17
	
	var rw: int = 280
	var rh: int = 220
	var img: Image = Image.create(rw, rh, false, Image.FORMAT_RGBA8)
	
	var start_x: int = rw / 2
	var start_y: int = 2
	
	# 4 основных извилистых корня, расходящихся веером
	_grow_root_branch(img, rnd, start_x, start_y, -0.65, 85.0, 8.5, 0)
	_grow_root_branch(img, rnd, start_x, start_y, -0.22, 115.0, 9.5, 0)
	_grow_root_branch(img, rnd, start_x, start_y, 0.20, 110.0, 9.5, 0)
	_grow_root_branch(img, rnd, start_x, start_y, 0.62, 80.0, 8.0, 0)
	
	return ImageTexture.create_from_image(img)


## Рекурсивное выращивание ветвящегося извилистого корня со сужением
func _grow_root_branch(img: Image, rnd: RandomNumberGenerator, x: float, y: float, angle_rad: float, length: float, thickness: float, depth: int) -> void:
	if length < 6.0 or thickness < 1.0 or depth > 4:
		return
	
	var steps: int = int(length / 2.0)
	var cur_x: float = x
	var cur_y: float = y
	var cur_angle: float = angle_rad
	var rw: int = img.get_width()
	var rh: int = img.get_height()
	
	for s in range(steps):
		cur_angle += rnd.randf_range(-0.16, 0.16)
		var cur_thick: float = maxf(1.0, thickness * (1.0 - (float(s) / float(steps)) * 0.45))
		
		var nx: float = cur_x + sin(cur_angle) * 2.0
		var ny: float = cur_y + cos(cur_angle) * 2.0
		
		var rad: int = int(cur_thick * 0.5)
		for dx in range(-rad, rad + 1):
			for dy in range(-rad, rad + 1):
				if dx * dx + dy * dy <= rad * rad:
					var px: int = int(nx + float(dx))
					var py: int = int(ny + float(dy))
					if px >= 0 and px < rw and py >= 0 and py < rh:
						var col: Color = COLOR_ROOT_SHADOW if (dx > int(float(rad) * 0.35)) else COLOR_ROOT_MAIN
						img.set_pixel(px, py, col)
		
		cur_x = nx
		cur_y = ny
		
		if s > 3 and rnd.randf() < 0.11 and depth < 3:
			var branch_dir: float = -1.0 if rnd.randf() < 0.5 else 1.0
			var b_angle: float = cur_angle + branch_dir * rnd.randf_range(0.35, 0.70)
			_grow_root_branch(img, rnd, cur_x, cur_y, b_angle, length * rnd.randf_range(0.5, 0.75), cur_thick * 0.65, depth + 1)
	
	if depth < 2:
		_grow_root_branch(img, rnd, cur_x, cur_y, cur_angle - rnd.randf_range(0.2, 0.4), length * 0.6, thickness * 0.6, depth + 1)
		_grow_root_branch(img, rnd, cur_x, cur_y, cur_angle + rnd.randf_range(0.2, 0.4), length * 0.6, thickness * 0.6, depth + 1)


## Создание экземпляра Sprite2D с выравниванием pivot по основанию (внизу по центру)
func _spawn_prop(texture_path: String, pos_x: float, pos_y: float, min_scale: float, max_scale: float) -> void:
	if not ResourceLoader.exists(texture_path):
		return

	var tex: Texture2D = load(texture_path)
	if tex == null:
		return

	var sprite: Sprite2D = Sprite2D.new()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.texture = tex
	sprite.centered = true
	sprite.offset = Vector2(0.0, -float(tex.get_height()) * 0.5)

	var s: float = randf_range(min_scale, max_scale)
	sprite.scale = Vector2(s, s)
	sprite.flip_h = randf() > 0.5

	var jitter_x: float = randf_range(-6.0, 6.0)
	sprite.position = Vector2(pos_x + jitter_x, pos_y)

	add_child(sprite)
