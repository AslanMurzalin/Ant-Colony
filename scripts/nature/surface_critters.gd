class_name SurfaceCritters
extends Node2D

## Декоративные мелкие обитатели поверхности (Этап 5: жучки и паучки в траве).
## Едва заметно двигаются в траве вдоль линии горизонта, не влияют на геймплей.

const COLOR_BEETLE: Color = Color(0.169, 0.114, 0.078, 1.0) # #2B1D14 (тёмный жук)
const COLOR_SPIDER: Color = Color(0.120, 0.090, 0.070, 1.0) # #1F1712 (паучок)

var _time: float = 0.0

# Координаты нескольких мелких обитателей
var _critters: Array[Dictionary] = [
	{ "base_x": 360.0, "y": 248.0, "is_spider": false, "speed": 0.4 },
	{ "base_x": 720.0, "y": 249.0, "is_spider": true,  "speed": 0.3 },
	{ "base_x": 1520.0, "y": 248.0, "is_spider": false, "speed": 0.5 },
	{ "base_x": 1740.0, "y": 249.0, "is_spider": true,  "speed": 0.35 }
]


func _ready() -> void:
	z_index = 2 # На уровне травы


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	for c in _critters:
		var wiggle: float = sin(_time * c.speed * TAU) * 6.0
		var pos: Vector2 = Vector2(c.base_x + wiggle, c.y)
		
		if c.is_spider:
			_draw_mini_spider(pos)
		else:
			_draw_mini_beetle(pos, wiggle)


## Отрисовка крошечного пиксельного жука (~5px)
func _draw_mini_beetle(pos: Vector2, motion: float) -> void:
	# Тень под жучком
	draw_ellipse(pos + Vector2(0.0, 1.5), 3.5, 2.0, Color(0.1, 0.08, 0.04, 0.4))
	# Тело
	draw_ellipse(pos, 3.0, 2.2, COLOR_BEETLE)
	# Блик на панцире
	draw_circle(pos + Vector2(-1.0, -0.8), 0.8, Color(0.35, 0.25, 0.18, 1.0))
	# Крошечные лапки
	var leg_swing: float = sin(_time * 8.0) * 0.8
	draw_line(pos + Vector2(-2.0, 1.0), pos + Vector2(-3.5, 2.5 + leg_swing), COLOR_BEETLE, 1.0)
	draw_line(pos + Vector2(2.0, 1.0), pos + Vector2(3.5, 2.5 - leg_swing), COLOR_BEETLE, 1.0)


## Отрисовка крошечного пиксельного паучка (~6px)
func _draw_mini_spider(pos: Vector2) -> void:
	# Тень
	draw_ellipse(pos + Vector2(0.0, 1.5), 3.0, 1.8, Color(0.1, 0.08, 0.04, 0.35))
	# Брюшко и головогрудь
	draw_circle(pos + Vector2(0.8, 0.0), 1.8, COLOR_SPIDER)
	draw_circle(pos + Vector2(-1.0, 0.0), 1.3, COLOR_SPIDER)
	# 4 пары тонких паучьих лапок врастопырку
	var leg_twitch: float = sin(_time * 4.0) * 0.5
	draw_line(pos + Vector2(-1.0, -1.0), pos + Vector2(-3.5, -2.5 + leg_twitch), COLOR_SPIDER, 0.8)
	draw_line(pos + Vector2(1.0, -1.0), pos + Vector2(3.5, -2.5 - leg_twitch), COLOR_SPIDER, 0.8)
	draw_line(pos + Vector2(-1.0, 1.0), pos + Vector2(-3.5, 2.5 - leg_twitch), COLOR_SPIDER, 0.8)
	draw_line(pos + Vector2(1.0, 1.0), pos + Vector2(3.5, 2.5 + leg_twitch), COLOR_SPIDER, 0.8)


## Вспомогательная отрисовка эллипса
func draw_ellipse(center: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts: PackedVector2Array = PackedVector2Array()
	var segs: int = 8
	for i in range(segs):
		var a: float = float(i) * TAU / float(segs)
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, col)
