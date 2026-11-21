# Plan for Next One — Переход на ручное управление муравьями

> **Автор:** Aslan (Dev B)  
> **Дата:** 2026-11-22  
> **Статус:** Проектирование

---

## 1. Проблема

Текущая система управления муравьями через **ползунки (TaskSliderWidget)** не позволяет давать точные задания конкретным муравьям:

- Нельзя приказать одному конкретному муравью **лечить матку** или **копать только туннели**.
- Слайдеры задают лишь процентные доли — `TaskAllocationManager` сам распределяет роли, и муравьи часто **зависают на месте**, не понимая, что им делать.
- Непрямой контроль приводит к тому, что муравьи переключаются между задачами хаотично, теряя прогресс (недокопанные туннели, брошенные личинки).
- Игрок чувствует **потерю агентства** — нет ощущения, что ты управляешь колонией.

---

## 2. Решение: Ручное назначение ролей

### 2.1 Способ A — Назначение через Roster (боковая панель)

У нас уже есть **Ant Roster** (`AntRosterController`) — боковая панель (Tab), показывающая всех муравьёв с их ID, ролью, HP и текущим действием.

**Изменения:**
- В каждую карточку муравья (`_create_ant_card`) добавить **кнопку-dropdown** (или ряд из 4 иконок-кнопок) для выбора роли:
  - 🌾 Forage | ⛏ Dig | 🍼 Nurse | ⚔ Defend
- При нажатии на кнопку:
  1. Вызывается `ant.assign_job(selected_job)` напрямую.
  2. Муравей помечается как **вручную назначенный** (`is_manually_pinned = true`).
  3. `TaskAllocationManager` **больше не переназначает** этого муравья при перерасчёте квот.
- Визуально: закреплённый муравей получает иконку 📌 рядом с ролью.

**Пример карточки (после доработки):**
```
┌──────────────────────────────────────────────────┐
│ ■  Ant #3  [🍼 Nurse] 📌       HP: 18/20        │
│    Feeding larva #2                              │
│    [🌾] [⛏] [🍼] [⚔]           [🔎 View]       │
└──────────────────────────────────────────────────┘
```

---

### 2.2 Способ B — Быстрое назначение через Shift+ПКМ (box-select)

Для быстрого назначения ролей прямо на карте без открытия ростера:

1. Игрок зажимает **Shift + ПКМ** и **тянет рамку** выделения на карте.
2. Все муравьи, попавшие в рамку, **подсвечиваются** (обводка / мерцание).
3. Появляется **всплывающее меню** рядом с рамкой:
   - 4 кнопки ролей: 🌾 | ⛏ | 🍼 | ⚔
   - Текст: "Выбрано: X муравьёв"
4. При нажатии на роль → все выделенные муравьи получают эту роль + флаг `is_manually_pinned = true`.
5. Нажатие Escape / клик мимо → отмена выделения.

---

## 3. Техническая реализация

### 3.1 Новый флаг в `AntController`

```gdscript
# scripts/entities/ant_controller.gd
var is_manually_pinned: bool = false
```

Когда `is_manually_pinned == true`, `TaskAllocationManager` пропускает этого муравья при автораспределении.

### 3.2 Изменения в `TaskAllocationManager`

```gdscript
# scripts/managers/task_allocation_manager.gd

func request_job_for_ant(ant: AntController) -> Enums.JobType:
    # Если муравей закреплён вручную — не переназначать
    if ant.is_manually_pinned:
        return ant.current_job
    # ... существующая логика автораспределения ...
```

Также при `recalculate_job_targets()` — учитывать закреплённых муравьёв в счётчиках, чтобы авто-муравьи корректно заполняли оставшиеся квоты.

### 3.3 Доработка `AntRosterController`

В `_create_ant_card()` — добавить ряд кнопок под статусом:

```gdscript
# После status_lbl, перед view_btn:
var role_hbox: HBoxContainer = HBoxContainer.new()
role_hbox.add_theme_constant_override("separation", 4)

for job_type in [Enums.JobType.FORAGE, Enums.JobType.DIG, Enums.JobType.NURSE, Enums.JobType.DEFEND]:
    var role_btn: Button = Button.new()
    role_btn.text = JOB_NAMES.get(job_type, "?").substr(0, 2)  # Emoji only
    role_btn.custom_minimum_size = Vector2(32, 24)
    role_btn.tooltip_text = "Assign: %s" % JOB_NAMES.get(job_type, "")
    role_btn.pressed.connect(func() -> void:
        _assign_role_to_ant(ant, job_type)
    )
    # Подсветить текущую роль
    if ant.current_job == job_type:
        role_btn.disabled = true
    role_hbox.add_child(role_btn)

# Кнопка "открепить" — вернуть в автораспределение
var unpin_btn: Button = Button.new()
unpin_btn.text = "🔓"
unpin_btn.tooltip_text = "Unpin — return to auto-allocation"
unpin_btn.visible = ant.is_manually_pinned
unpin_btn.pressed.connect(func() -> void:
    ant.is_manually_pinned = false
    refresh_roster()
)
role_hbox.add_child(unpin_btn)

vbox.add_child(role_hbox)
```

Новый метод:
```gdscript
func _assign_role_to_ant(ant: AntController, job: Enums.JobType) -> void:
    if not is_instance_valid(ant):
        return
    ant.is_manually_pinned = true
    ant.assign_job(job)
    TaskAllocationManager.recalculate_job_targets(
        get_tree().get_nodes_in_group("workers").size()
    )
    refresh_roster()
```

### 3.4 Новый `SelectionManager` (или расширение `GridCursor`)

Для Shift+ПКМ выделения нужен новый синглтон или расширение `GridCursor`:

```gdscript
# scripts/managers/selection_manager.gd (Autoload)
class_name SelectionManager
extends Node

signal ants_selected(ants: Array[AntController])
signal selection_cleared()

var is_selecting: bool = false
var selection_start: Vector2 = Vector2.ZERO
var selection_end: Vector2 = Vector2.ZERO
var selected_ants: Array[AntController] = []

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_RIGHT and Input.is_key_pressed(KEY_SHIFT):
            if event.pressed:
                _start_selection(event.global_position)
            else:
                _end_selection(event.global_position)
                
func _start_selection(pos: Vector2) -> void:
    is_selecting = true
    selection_start = pos
    selection_end = pos

func _process(_delta: float) -> void:
    if is_selecting:
        selection_end = get_viewport().get_mouse_position()
        queue_redraw()  # Рисуем рамку

func _end_selection(pos: Vector2) -> void:
    is_selecting = false
    selection_end = pos
    var rect: Rect2 = Rect2(selection_start, selection_end - selection_start).abs()
    
    selected_ants.clear()
    for node in get_tree().get_nodes_in_group("workers"):
        if node is AntController and rect.has_point(node.global_position):
            selected_ants.append(node as AntController)
    
    if not selected_ants.is_empty():
        ants_selected.emit(selected_ants)
    else:
        selection_cleared.emit()
```

### 3.5 Popup меню назначения ролей (для box-select)

```gdscript
# scripts/ui/selection_popup.gd
class_name SelectionPopup
extends PanelContainer

signal role_assigned(ants: Array[AntController], job: Enums.JobType)

func show_for_ants(ants: Array[AntController], screen_pos: Vector2) -> void:
    # Показать popup с кнопками ролей
    # При нажатии — назначить всем выделенным муравьям выбранную роль
    # Установить is_manually_pinned = true для каждого
    pass
```

---

## 4. Взаимодействие слайдеров и ручного назначения

Слайдеры **остаются** как инструмент для быстрого начального распределения, но:

- Слайдеры управляют только **незакреплёнными** (`is_manually_pinned == false`) муравьями.
- В `TopBarHUD` добавить счётчик: `"Pinned: 3 / 12 ants"` — чтобы игрок видел, сколько муравьёв под ручным управлением.
- Если игрок хочет вернуть всех в авторежим — кнопка "Unpin All" в ростере.

---

## 5. Визуальный фидбек

- **Закреплённый муравей:** маленькая иконка 📌 над спрайтом (или подсветка).
- **Выделенные муравьи (box-select):** мерцающая обводка белым цветом.
- **Рамка выделения:** полупрозрачный прямоугольник (как в RTS).

---

## 6. Порядок реализации

| Шаг | Задача | Файлы |
|-----|--------|-------|
| 1 | Добавить `is_manually_pinned` в `AntController` | `ant_controller.gd` |
| 2 | Изменить TAM — пропускать закреплённых | `task_allocation_manager.gd` |
| 3 | Добавить кнопки ролей в Ant Roster | `ant_roster_controller.gd` |
| 4 | Создать `SelectionManager` | `selection_manager.gd` (новый) |
| 5 | Создать `SelectionPopup` | `selection_popup.gd` + `.tscn` (новые) |
| 6 | Визуальный фидбек (📌 и рамка) | `ant_controller.gd`, `selection_manager.gd` |
| 7 | Обновить `Contracts.md` | `Contracts.md` |
| 8 | Тестирование полного цикла | — |

---

## 7. Итог

Эта система даёт игроку **полный контроль** над каждым муравьём, сохраняя при этом возможность автораспределения через слайдеры для незакреплённых муравьёв. Два способа назначения (ростер + box-select) покрывают как точечное, так и массовое управление.
