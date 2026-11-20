class_name TaskSliderWidget
extends Control

## Task Slider UI Widget — 4 HSliders for indirect ant job control.
## Connected to TaskAllocationManager; dragging one redistributes the others.

signal slider_changed(job: Enums.JobType, new_pct: float)

const JOB_LABELS: Dictionary = {
	Enums.JobType.FORAGE: "Forage",
	Enums.JobType.DIG: "Dig",
	Enums.JobType.NURSE: "Nurse",
	Enums.JobType.DEFEND: "Defend",
}

const SLIDER_COLORS: Dictionary = {
	Enums.JobType.FORAGE: Color(0.6, 0.35, 0.1),
	Enums.JobType.DIG:    Color(0.9, 0.6, 0.1),
	Enums.JobType.NURSE:  Color(0.2, 0.75, 0.3),
	Enums.JobType.DEFEND: Color(0.85, 0.15, 0.15),
}

const JOB_ICONS: Dictionary = {
	Enums.JobType.FORAGE: "res://assets/ui/icon_forage.png",
	Enums.JobType.DIG:    "res://assets/ui/icon_dig.png",
	Enums.JobType.NURSE:  "res://assets/ui/icon_nurse.png",
	Enums.JobType.DEFEND: "res://assets/ui/icon_defend.png",
}

## Whether a particular slider is locked from redistribution.
var _locked: Dictionary = {
	Enums.JobType.FORAGE: false,
	Enums.JobType.DIG:    false,
	Enums.JobType.NURSE:  false,
	Enums.JobType.DEFEND: false,
}

var _sliders:     Dictionary = {}   # JobType -> HSlider
var _labels:      Dictionary = {}   # JobType -> Label
var _lock_btns:   Dictionary = {}   # JobType -> Button
var _updating:    bool = false

@onready var _container: VBoxContainer = $PanelContainer/MarginContainer/VBoxContainer


func _ready() -> void:
	_build_ui()
	_refresh_labels()
	# Listen to job quota changes driven externally (e.g. ant death)
	TaskAllocationManager.connect("quotas_updated", _on_quotas_updated)


## Build the slider rows programmatically so the scene stays lightweight.
func _build_ui() -> void:
	for job in JOB_LABELS.keys():
		var row: HBoxContainer = HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		# Icon from sprite sheet
		var icon_rect: TextureRect = TextureRect.new()
		icon_rect.custom_minimum_size = Vector2(24, 24)
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if JOB_ICONS.has(job) and ResourceLoader.exists(JOB_ICONS[job]):
			icon_rect.texture = load(JOB_ICONS[job])
		row.add_child(icon_rect)

		# Color swatch
		var swatch: ColorRect = ColorRect.new()
		swatch.color = SLIDER_COLORS[job]
		swatch.custom_minimum_size = Vector2(6, 28)
		row.add_child(swatch)

		# Label "Forage (12)"
		var lbl: Label = Label.new()
		lbl.custom_minimum_size = Vector2(90, 0)
		lbl.text = JOB_LABELS[job] + " (0)"
		_labels[job] = lbl
		row.add_child(lbl)

		# HSlider 0–100 step 1
		var slider: HSlider = HSlider.new()
		slider.min_value = 0.0
		slider.max_value = 100.0
		slider.step = 1.0
		slider.value = 25.0
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.connect("value_changed", func(v: float) -> void: _on_slider_changed(job, v))
		_sliders[job] = slider
		row.add_child(slider)

		# Lock toggle button
		var lock_btn: Button = Button.new()
		lock_btn.text = "🔓"
		lock_btn.toggle_mode = true
		lock_btn.custom_minimum_size = Vector2(32, 0)
		lock_btn.connect("toggled", func(pressed: bool) -> void: _on_lock_toggled(job, pressed))
		_lock_btns[job] = lock_btn
		row.add_child(lock_btn)

		_container.add_child(row)


func _on_slider_changed(job: Enums.JobType, value: float) -> void:
	if _updating:
		return
	_updating = true
	var new_pct: float = value / 100.0
	TaskAllocationManager.set_task_percentage(job, new_pct)
	# Reflect actual values back (TAM normalizes to sum=1.0)
	_sync_sliders_from_tam()
	_refresh_labels()
	emit_signal("slider_changed", job, new_pct)
	_updating = false


func _on_lock_toggled(job: Enums.JobType, pressed: bool) -> void:
	_locked[job] = pressed
	TaskAllocationManager.lock_slider(job, pressed)
	_lock_btns[job].text = "🔒" if pressed else "🔓"
	if _sliders.has(job):
		_sliders[job].editable = not pressed


func _on_quotas_updated() -> void:
	if not _updating:
		_sync_sliders_from_tam()
		_refresh_labels()


## Pull current percentages from TAM and push them into sliders without looping.
func _sync_sliders_from_tam() -> void:
	_updating = true
	for job in _sliders.keys():
		var pct: float = TaskAllocationManager.get_task_percentage(job)
		_sliders[job].value = pct * 100.0
	_updating = false


## Update all labels to show "Forage (12)" headcount format.
func _refresh_labels() -> void:
	var total: int = GameManager.total_workers_alive
	for job in _labels.keys():
		var pct: float = TaskAllocationManager.get_task_percentage(job)
		var count: int = int(round(pct * float(total)))
		_labels[job].text = JOB_LABELS[job] + " (" + str(count) + ")"


## Programmatically set a slider value (e.g. from tutorial or preset buttons).
func set_slider_value(job: Enums.JobType, pct: float) -> void:
	if _sliders.has(job):
		_sliders[job].value = clamp(pct, 0.0, 1.0) * 100.0
