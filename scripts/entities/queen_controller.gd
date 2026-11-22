class_name QueenController
extends Node2D

# Anchored in the Royal Chamber. Serves as the primary win/lose condition and lays eggs.

signal queen_health_changed(current: float, maximum: float)
signal queen_laid_egg()
signal queen_damaged(damage_amount: float)
signal queen_starvation_started()
signal queen_starvation_ended()

@export var max_health: float = 100.0
var current_health: float = 100.0
var hunger_timer: float = 15.0
var hunger_interval: float = 15.0
var egg_laying_timer: float = 20.0
var egg_laying_interval: float = 20.0
var is_starving: bool = false
var starvation_damage_rate: float = 2.0
var distress_timer: float = 0.0

static var _cached_queen_texture: ImageTexture = null

@onready var sprite: Sprite2D = $Sprite2D
@onready var health_bar: ProgressBar = $HealthBar

func _ready() -> void:
	add_to_group("queen")
	z_index = 4
	_init_queen_texture()
	if sprite != null:
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.texture = _cached_queen_texture
		sprite.scale = Vector2.ONE
	
	# Скрываем старые реалистичные спрайты кладок яиц (россыпь яиц рисуется процедурно в _draw)
	var egg_left: Node = get_node_or_null("EggClutchLeft")
	if egg_left != null and egg_left is CanvasItem:
		(egg_left as CanvasItem).visible = false
	var egg_right: Node = get_node_or_null("EggClutchRight")
	if egg_right != null and egg_right is CanvasItem:
		(egg_right as CanvasItem).visible = false

	current_health = max_health
	hunger_timer = hunger_interval
	egg_laying_timer = egg_laying_interval
	queue_redraw()
	if health_bar != null:
		health_bar.max_value = max_health
		health_bar.value = current_health
	queen_health_changed.emit(current_health, max_health)

static func _init_queen_texture() -> void:
	if _cached_queen_texture != null:
		return
	var lines: Array = [
		"..........................................",
		"................................C.C.C.....",
		".................................CJC......",
		"..............................AA..C.......",
		".............................A............",
		"............................A...HHHH......",
		"........DDDDDDD............A..HHHHHHEE....",
		".....DDDDDDDDDDDDD...........HHHHHHHHE....",
		"...DDDDDDDDDDDDDDDDD........HHHHHHHHHQ....",
		"..DDDDDQQQQQQQDDDDDDD.WW...HHHHHHHHHHQ....",
		".DDDDDQQQQQQQQQDDDDDDDWWWW.HHHHHHHHHH.....",
		".DDDDQQQQQQQQQQQDDDDDDWWWWW.HHHHHHHH......",
		"DDDDQQQQQQQQQQQQQDDDDDWWWWW..HHHHHH.......",
		"DDDDQQQQQQQQQQQQQDDDDDWWWWW...HHHH........",
		".DDDDQQQQQQQQQQQDDDDDD.WWWW...L..L..L.....",
		".DDDDDQQQQQQQQQDDDDDDD..WW...L..L....L....",
		"..DDDDDQQQQQQQDDDDDDD.......L..L......L...",
		"...DDDDDDDDDDDDDDDDD.......L..L........L..",
		".....DDDDDDDDDDDDD........L..L..........L.",
		"........DDDDDDD..........L..L............L",
		"..........................................",
		"..........................................",
		"..........................................",
		".........................................."
	]
	var pal: Dictionary = {
		'Q': Color(0.478, 0.227, 0.133, 1.0), # #7A3A22 Queen reddish brown
		'D': Color(0.333, 0.149, 0.078, 1.0), # #552614 Dark segment stripes
		'H': Color(0.608, 0.298, 0.180, 1.0), # #9B4C2E Highlight
		'W': Color(0.353, 0.165, 0.094, 1.0), # Waist / Thorax connection
		'C': Color(0.949, 0.761, 0.114, 1.0), # #F2C21D Gold crown
		'J': Color(0.831, 0.176, 0.118, 1.0), # Crown ruby
		'E': Color(1.0, 0.96, 0.90, 1.0),     # Eye
		'L': Color(0.255, 0.110, 0.059, 1.0), # Leg
		'A': Color(0.255, 0.110, 0.059, 1.0), # Antenna
	}
	var img: Image = Image.create(42, 24, false, Image.FORMAT_RGBA8)
	for y in range(24):
		var line: String = lines[y]
		for x in range(42):
			var ch: String = line[x]
			if pal.has(ch):
				img.set_pixel(x, y, pal[ch])
			else:
				img.set_pixel(x, y, Color(0.0, 0.0, 0.0, 0.0))
	_cached_queen_texture = ImageTexture.create_from_image(img)

func _draw() -> void:
	# 1. Органическая темная подстилка гнезда (земля и листья) под королевой
	draw_set_transform(Vector2(0.0, 8.0), 0.0, Vector2(1.9, 1.0))
	draw_circle(Vector2.ZERO, 40.0, Color(0.20, 0.13, 0.07, 0.90)) # #332112
	draw_circle(Vector2.ZERO, 35.0, Color(0.32, 0.22, 0.12, 0.95))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# 2. Россыпь белых яиц и светлых личинок вокруг королевы (стиль antcolony.gg)
	# Точки и овалы белого, кремового и нежно-желтого оттенков
	var egg_col_white: Color = Color(0.98, 0.98, 0.96, 0.95)
	var egg_col_cream: Color = Color(0.94, 0.91, 0.82, 0.95)
	var egg_col_shadow: Color = Color(0.24, 0.16, 0.09, 0.6)

	var egg_offsets: Array[Vector2] = [
		Vector2(-42, 4), Vector2(-36, -6), Vector2(-48, 10), Vector2(-38, 14),
		Vector2(-28, 18), Vector2(-44, -2), Vector2(-32, 8), Vector2(-24, 22),
		Vector2(26, 18), Vector2(34, 12), Vector2(42, 6), Vector2(38, -4),
		Vector2(46, 10), Vector2(28, 22), Vector2(48, -2), Vector2(36, 16),
		Vector2(-12, 22), Vector2(0, 24), Vector2(12, 22), Vector2(-6, 26),
		Vector2(6, 26), Vector2(-18, 20), Vector2(18, 20), Vector2(-52, 6),
		Vector2(52, 4), Vector2(-30, -10), Vector2(32, -8)
	]

	for i in range(egg_offsets.size()):
		var ep: Vector2 = egg_offsets[i]
		# Тень под яйцом
		draw_circle(ep + Vector2(0.5, 0.8), 2.8, egg_col_shadow)
		# Сами яйца и личинки
		var col: Color = egg_col_white if (i % 2 == 0) else egg_col_cream
		draw_circle(ep, 2.4, col)
		# Блик
		draw_circle(ep + Vector2(-0.5, -0.5), 0.8, Color.WHITE)

func _process(delta: float) -> void:
	if GameManager.game_state == Enums.GameState.RUNNING:
		_process_queen_logic(delta)
	_update_visuals(delta)

func _process_queen_logic(delta: float) -> void:
	hunger_timer -= delta
	if hunger_timer <= 0.0:
		if not is_starving:
			is_starving = true
			queen_starvation_started.emit()
		tick_starvation(delta)
	
	if not is_starving:
		egg_laying_timer -= delta
		if egg_laying_timer <= 0.0:
			attempt_lay_egg()
			egg_laying_timer = egg_laying_interval

func _update_visuals(delta: float) -> void:
	if distress_timer > 0.0:
		distress_timer -= delta
		modulate = Color(1.0, 0.4, 0.4, 1.0)
	elif is_starving:
		var blink: float = 0.7 + 0.3 * sin(Time.get_ticks_msec() * 0.01)
		modulate = Color(1.0, blink, blink, 1.0)
	else:
		modulate = Color(1.0, 1.0, 1.0, 1.0)
	
	# Subtle breathing animation on queen body
	var breath_t: float = Time.get_ticks_msec() * 0.0025
	var breath_x: float = 1.0 + 0.035 * sin(breath_t)
	var breath_y: float = 1.0 + 0.015 * sin(breath_t)
	if sprite != null:
		sprite.scale = Vector2(breath_x, breath_y)

func feed_queen(amount: int) -> bool:
	if amount <= 0:
		return false
	hunger_timer = hunger_interval
	if is_starving:
		is_starving = false
		queen_starvation_ended.emit()
	current_health = minf(max_health, current_health + 10.0 * float(amount))
	if health_bar != null:
		health_bar.value = current_health
	queen_health_changed.emit(current_health, max_health)
	return true

func take_damage(amount: float) -> void:
	if amount <= 0.0 or current_health <= 0.0:
		return
	current_health = maxf(0.0, current_health - amount)
	distress_timer = 0.5
	if health_bar != null:
		health_bar.value = current_health
	queen_damaged.emit(amount)
	queen_health_changed.emit(current_health, max_health)
	if current_health <= 0.0:
		GameManager.trigger_defeat("Queen died of combat injuries!")

func tick_starvation(delta: float) -> void:
	if current_health <= 0.0:
		return
	var damage: float = starvation_damage_rate * delta
	current_health = maxf(0.0, current_health - damage)
	if health_bar != null:
		health_bar.value = current_health
	queen_damaged.emit(damage)
	queen_health_changed.emit(current_health, max_health)
	if current_health <= 0.0:
		GameManager.trigger_defeat("Queen died of starvation!")

func attempt_lay_egg() -> void:
	if is_starving or GameManager.total_workers_alive >= 50:
		return
	
	# Colony law: Queen cannot birth more ants unless stored food exceeds 50% capacity
	if ResourceManager != null and ResourceManager.get_max_capacity() > 0:
		var food_ratio: float = float(ResourceManager.stored_food) / float(ResourceManager.get_max_capacity())
		if food_ratio <= 0.5:
			return

	queen_laid_egg.emit()
	var spawn_pos: Vector2 = global_position + Vector2(randf_range(-24.0, 24.0), 12.0)
	var nursery = get_node_or_null("/root/NurseryManager")
	if nursery != null and nursery.has_method("spawn_egg"):
		nursery.spawn_egg(spawn_pos)


## Returns current health as 0.0–1.0 ratio for HUD display.
func get_health_pct() -> float:
	if max_health <= 0.0:
		return 0.0
	return clampf(current_health / max_health, 0.0, 1.0)
