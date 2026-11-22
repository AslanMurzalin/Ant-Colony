class_name SoilWorm
extends Node2D

## Декоративный подземный червяк (Этап 5).
## Медленно и плавно извивается в почве вне туннелей.
## Чисто визуальный элемент, не влияет на геймплей.

@export var worm_color: Color = Color(0.910, 0.573, 0.635, 1.0)       # #E892A2 (розовый)
@export var worm_shadow: Color = Color(0.741, 0.388, 0.455, 1.0)      # #BD6374 (теневой поясок)
@export var segment_count: int = 6
@export var segment_radius: float = 2.4
@export var crawl_speed: float = 3.5

var _time: float = 0.0
var _base_pos: Vector2 = Vector2.ZERO


func _ready() -> void:
	_base_pos = position
	z_index = 0


func _process(delta: float) -> void:
	_time += delta
	# Медленное ползание туда-обратно по синусоиде на несколько пикселей
	position.x = _base_pos.x + sin(_time * 0.25) * 12.0
	queue_redraw()


func _draw() -> void:
	# Отрисовка сегментированного извивающегося тела червячка
	for i in range(segment_count):
		var wave_offset: float = sin(_time * 2.2 + float(i) * 0.75) * 3.0
		var seg_x: float = float(i) * 3.8
		var seg_pos: Vector2 = Vector2(seg_x, wave_offset)
		
		# Теневой контур
		draw_circle(seg_pos + Vector2(0.5, 0.5), segment_radius + 0.4, worm_shadow)
		# Розовое тело сегмента
		draw_circle(seg_pos, segment_radius, worm_color)
		
		# Клителлум (утолщенный поясок червяка на 2-м сегменте)
		if i == 2:
			draw_circle(seg_pos, segment_radius + 0.6, Color(0.96, 0.68, 0.74, 1.0))
