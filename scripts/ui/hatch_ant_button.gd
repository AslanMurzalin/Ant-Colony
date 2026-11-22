class_name HatchAntButton
extends Button

## Кнопка ручного спавна (рождения) муравьёв за счёт запасов еды колонии.

# Стоимость спавна одного муравья в единицах еды
const ANT_COST: int = 10

# Максимальный лимит популяции муравьёв по правилам игры (GD.md)
const MAX_ANTS: int = 50

# Предварительная загрузка сцены муравья для Godot 4
const ANT_SCENE: PackedScene = preload("res://scenes/entities/ant.tscn")

# Ссылки на контейнер муравьёв и узел королевы
var _ants_container: Node2D = null
var _queen_node: Node2D = null


func _ready() -> void:
	# Настройка внешнего вида и подсказки кнопки
	text = "🥚 Hatch Ant"
	tooltip_text = "Spend 10 food to hatch a new worker ant"
	
	# Подключение сигнала нажатия кнопки в синтаксисе Godot 4
	pressed.connect(_on_pressed)
	
	# Поиск узла королевы и контейнера муравьев в дереве сцены
	_find_scene_nodes()
	
	# Первоначальное обновление доступности кнопки
	_update_button_state()


func _process(_delta: float) -> void:
	# В каждом кадре проверяем, достаточно ли еды и свободен ли лимит популяции.
	# Это автоматически включает кнопку обратно, когда сборщики приносят еду с поверхности.
	_update_button_state()


## Проверка, можно ли в данный момент заспавнить муравья
func can_hatch() -> bool:
	var current_food: int = ResourceManager.stored_food
	var current_ants: int = GameManager.total_workers_alive
	return current_food >= ANT_COST and current_ants < MAX_ANTS


## Автоматическое переключение состояния кнопки (активна / неактивна)
func _update_button_state() -> void:
	var available: bool = can_hatch()
	if disabled == available:
		disabled = not available


## Обработчик нажатия на кнопку "Родить муравья"
func _on_pressed() -> void:
	# Двойная проверка на случай спама кликов
	if not can_hatch():
		return
	
	# Списываем еду через синглтон ресурсов колонии
	var food_consumed: bool = ResourceManager.consume_food(ANT_COST)
	if not food_consumed:
		return
	
	# Если ссылка на королеву потерялась, находим её заново
	if _queen_node == null or not is_instance_valid(_queen_node):
		_find_scene_nodes()
	
	# Вычисляем позицию спавна около королевы с небольшим случайным смещением (offset),
	# чтобы новорождённые муравьи не накладывались друг на друга
	var spawn_pos: Vector2 = Vector2(976.0, 528.0) # Базовая позиция королевской камеры
	if _queen_node != null:
		var random_offset: Vector2 = Vector2(
			randf_range(-24.0, 24.0),
			randf_range(-8.0, 8.0)
		)
		spawn_pos = _queen_node.global_position + random_offset
	
	# Создаем экземпляр муравья через актуальный для Godot 4 метод instantiate()
	var new_ant: AntController = ANT_SCENE.instantiate() as AntController
	if new_ant == null:
		return
	new_ant.ant_id = GameManager.get_next_ant_id()
	new_ant.global_position = spawn_pos
	new_ant.z_index = 4
	
	# Добавляем муравья в контейнер муравьев на сцене
	if _ants_container != null and is_instance_valid(_ants_container):
		_ants_container.add_child(new_ant)
	else:
		_find_scene_nodes()
		if _ants_container != null and is_instance_valid(_ants_container):
			_ants_container.add_child(new_ant)
		else:
			get_tree().current_scene.add_child(new_ant)
	
	# Назначаем муравью начальную задачу (по умолчанию защитник)
	new_ant.assign_job(Enums.JobType.DEFEND)
	
	# Регистрируем рождение муравья в менеджере игры
	# Это увеличивает счетчики и автоматически вызывает сигнал ant_count_changed,
	# который обновляет верхний HUD
	GameManager.register_ant_born()
	
	# Немедленно обновляем состояние кнопки
	_update_button_state()


## Вспомогательный метод поиска узлов на сцене
func _find_scene_nodes() -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	if _ants_container == null or not is_instance_valid(_ants_container):
		_ants_container = tree.root.find_child("Ants", true, false) as Node2D
	if _queen_node == null or not is_instance_valid(_queen_node):
		_queen_node = tree.get_first_node_in_group("queen") as Node2D
		if _queen_node == null:
			_queen_node = tree.root.find_child("Queen", true, false) as Node2D
