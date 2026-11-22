class_name SelectionPopup
extends PanelContainer

## Floating context menu that appears after selecting ants with Shift+RMB.
## Allows assigning a specific role or unpinning all selected ants.

signal role_chosen(job: Enums.JobType)
signal unpin_chosen()
signal popup_closed()

@onready var _title_label: Label = $MarginContainer/VBoxContainer/HeaderHBox/TitleLabel
@onready var _close_btn: Button = $MarginContainer/VBoxContainer/HeaderHBox/CloseBtn
@onready var _btn_forage: Button = $MarginContainer/VBoxContainer/RolesGrid/BtnForage
@onready var _btn_dig: Button = $MarginContainer/VBoxContainer/RolesGrid/BtnDig
@onready var _btn_nurse: Button = $MarginContainer/VBoxContainer/RolesGrid/BtnNurse
@onready var _btn_defend: Button = $MarginContainer/VBoxContainer/RolesGrid/BtnDefend
@onready var _btn_unpin: Button = $MarginContainer/VBoxContainer/BtnUnpin

func _ready() -> void:
	add_to_group("selection_popup")
	hide()
	if _close_btn != null:
		_close_btn.pressed.connect(_on_close_pressed)
	if _btn_forage != null:
		_btn_forage.pressed.connect(func() -> void: _on_role_pressed(Enums.JobType.FORAGE))
	if _btn_dig != null:
		_btn_dig.pressed.connect(func() -> void: _on_role_pressed(Enums.JobType.DIG))
	if _btn_nurse != null:
		_btn_nurse.pressed.connect(func() -> void: _on_role_pressed(Enums.JobType.NURSE))
	if _btn_defend != null:
		_btn_defend.pressed.connect(func() -> void: _on_role_pressed(Enums.JobType.DEFEND))
	if _btn_unpin != null:
		_btn_unpin.pressed.connect(_on_unpin_pressed)

func open_at(screen_pos: Vector2, ant_count: int) -> void:
	if _title_label != null:
		_title_label.text = "🎯 Selected: %d" % ant_count

	# Position popup near mouse, clamped to viewport bounds
	var vp_size: Vector2 = get_viewport_rect().size
	var popup_w: float = 180.0
	var popup_h: float = 160.0
	var target_x: float = clampf(screen_pos.x + 10.0, 10.0, vp_size.x - popup_w - 10.0)
	var target_y: float = clampf(screen_pos.y + 10.0, 10.0, vp_size.y - popup_h - 10.0)
	position = Vector2(target_x, target_y)

	show()

func close_popup() -> void:
	hide()
	popup_closed.emit()

func _on_role_pressed(job: Enums.JobType) -> void:
	role_chosen.emit(job)
	hide()

func _on_unpin_pressed() -> void:
	unpin_chosen.emit()
	hide()

func _on_close_pressed() -> void:
	close_popup()
