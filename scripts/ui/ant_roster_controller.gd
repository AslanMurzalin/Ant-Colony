class_name AntRosterController
extends Control

## Ant Roster Menu — Displays the live activity, role, health, and status of every ant in the colony.
## Toggled via Tab key or the "📋 Roster" HUD button.

@onready var _panel: PanelContainer = $PanelContainer
@onready var _title_label: Label = $PanelContainer/MarginContainer/VBoxContainer/HeaderHBox/TitleLabel
@onready var _summary_label: Label = $PanelContainer/MarginContainer/VBoxContainer/SummaryLabel
@onready var _unpin_all_btn: Button = $PanelContainer/MarginContainer/VBoxContainer/HeaderHBox/UnpinAllBtn
@onready var _close_btn: Button = $PanelContainer/MarginContainer/VBoxContainer/HeaderHBox/CloseBtn
@onready var _ant_list_container: VBoxContainer = $PanelContainer/MarginContainer/VBoxContainer/ScrollContainer/AntList

var _refresh_timer: float = 0.0
const REFRESH_INTERVAL: float = 0.3

const JOB_COLORS: Dictionary = {
	Enums.JobType.FORAGE: Color(0.72, 0.45, 0.20),
	Enums.JobType.DIG:    Color(0.95, 0.60, 0.15),
	Enums.JobType.NURSE:  Color(0.25, 0.85, 0.40),
	Enums.JobType.DEFEND: Color(0.90, 0.25, 0.25),
	Enums.JobType.IDLE:   Color(0.65, 0.65, 0.65),
}

const JOB_NAMES: Dictionary = {
	Enums.JobType.FORAGE: "🌾 Forager",
	Enums.JobType.DIG:    "⛏ Digger",
	Enums.JobType.NURSE:  "🍼 Nurse",
	Enums.JobType.DEFEND: "⚔ Defender",
	Enums.JobType.IDLE:   "💤 Idle",
}

func _ready() -> void:
	hide()
	if _close_btn != null:
		_close_btn.pressed.connect(close_roster)
	if _unpin_all_btn != null:
		_unpin_all_btn.pressed.connect(func() -> void:
			TaskAllocationManager.unpin_all_ants()
			refresh_roster()
		)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_TAB:
			toggle_roster()
			get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if not visible:
		return
	_refresh_timer -= delta
	if _refresh_timer <= 0.0:
		_refresh_timer = REFRESH_INTERVAL
		refresh_roster()

func open_roster() -> void:
	show()
	_refresh_timer = 0.0
	refresh_roster()

func close_roster() -> void:
	hide()

func toggle_roster() -> void:
	if visible:
		close_roster()
	else:
		open_roster()

func refresh_roster() -> void:
	if _ant_list_container == null:
		return

	var raw_workers: Array = get_tree().get_nodes_in_group("workers")
	var workers: Array[AntController] = []
	for w in raw_workers:
		if is_instance_valid(w) and w is AntController:
			workers.append(w as AntController)

	# Update header count and summary
	var total: int = workers.size()
	if _title_label != null:
		_title_label.text = "🐜 Colony Roster (%d / 50)" % total

	var counts: Dictionary = {
		Enums.JobType.FORAGE: 0,
		Enums.JobType.DIG: 0,
		Enums.JobType.NURSE: 0,
		Enums.JobType.DEFEND: 0,
		Enums.JobType.IDLE: 0
	}
	var pinned_count: int = 0
	for w in workers:
		var j: Enums.JobType = w.current_job
		counts[j] = counts.get(j, 0) + 1
		if w.is_manually_pinned:
			pinned_count += 1

	if _summary_label != null:
		_summary_label.text = "🌾 Foragers: %d  |  ⛏ Diggers: %d  |  🍼 Nurses: %d  |  ⚔ Defenders: %d  |  📌 Pinned: %d" % [
			counts[Enums.JobType.FORAGE],
			counts[Enums.JobType.DIG],
			counts[Enums.JobType.NURSE],
			counts[Enums.JobType.DEFEND],
			pinned_count
		]

	# Rebuild rows efficiently
	# Clear old children
	for child in _ant_list_container.get_children():
		child.queue_free()

	if workers.is_empty():
		var empty_lbl: Label = Label.new()
		empty_lbl.text = "No worker ants alive in the colony."
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.modulate = Color(0.7, 0.7, 0.7)
		_ant_list_container.add_child(empty_lbl)
		return

	# Sort workers stably by persistent ant_id
	workers.sort_custom(func(a: AntController, b: AntController) -> bool:
		return a.ant_id < b.ant_id
	)

	for ant in workers:
		var card: PanelContainer = _create_ant_card(ant)
		_ant_list_container.add_child(card)

func _create_ant_card(ant: AntController) -> PanelContainer:
	var card: PanelContainer = PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 6)
	card.add_child(margin)

	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	margin.add_child(hbox)

	# Left colored job bar
	var swatch: ColorRect = ColorRect.new()
	swatch.color = JOB_COLORS.get(ant.current_job, Color.WHITE)
	swatch.custom_minimum_size = Vector2(5, 34)
	hbox.add_child(swatch)

	# Middle text VBox
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 2)
	hbox.add_child(vbox)

	# Top line: "Ant #1 [🌾 Forager]  HP: 20/20"
	var top_line: HBoxContainer = HBoxContainer.new()
	vbox.add_child(top_line)

	var name_lbl: Label = Label.new()
	name_lbl.text = "Ant #%d" % (ant.ant_id if ant.ant_id > 0 else 1)
	name_lbl.add_theme_font_size_override("font_size", 14)
	top_line.add_child(name_lbl)

	var job_lbl: Label = Label.new()
	var pin_str: String = " 📌" if ant.is_manually_pinned else ""
	job_lbl.text = " [%s%s]" % [JOB_NAMES.get(ant.current_job, "Worker"), pin_str]
	job_lbl.modulate = JOB_COLORS.get(ant.current_job, Color.WHITE)
	job_lbl.add_theme_font_size_override("font_size", 13)
	top_line.add_child(job_lbl)

	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_line.add_child(spacer)

	var hp_lbl: Label = Label.new()
	hp_lbl.text = "HP: %d/20" % int(ant.health)
	hp_lbl.modulate = Color(0.4, 0.9, 0.4) if ant.health > 10.0 else Color(0.9, 0.3, 0.3)
	hp_lbl.add_theme_font_size_override("font_size", 12)
	top_line.add_child(hp_lbl)

	# Middle line: status description
	var status_lbl: Label = Label.new()
	status_lbl.text = ant.get_action_description()
	status_lbl.modulate = Color(0.85, 0.85, 0.85)
	status_lbl.add_theme_font_size_override("font_size", 12)
	status_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(status_lbl)

	# Action buttons row: Assign roles or unpin
	var actions_hbox: HBoxContainer = HBoxContainer.new()
	actions_hbox.add_theme_constant_override("separation", 4)
	vbox.add_child(actions_hbox)

	var role_list: Array[Enums.JobType] = [
		Enums.JobType.FORAGE,
		Enums.JobType.DIG,
		Enums.JobType.NURSE,
		Enums.JobType.DEFEND
	]
	var role_btn_labels: Dictionary = {
		Enums.JobType.FORAGE: "🌾 Forage",
		Enums.JobType.DIG:    "⛏ Dig",
		Enums.JobType.NURSE:  "🍼 Nurse",
		Enums.JobType.DEFEND: "⚔ Defend"
	}

	for role in role_list:
		var r_btn: Button = Button.new()
		r_btn.text = role_btn_labels[role]
		r_btn.tooltip_text = "Directly assign: %s" % JOB_NAMES.get(role, "")
		r_btn.custom_minimum_size = Vector2(58, 22)
		r_btn.add_theme_font_size_override("font_size", 11)
		if ant.current_job == role and ant.is_manually_pinned:
			r_btn.disabled = true
		r_btn.pressed.connect(func() -> void:
			_assign_role_to_ant(ant, role)
		)
		actions_hbox.add_child(r_btn)

	if ant.is_manually_pinned:
		var unpin_btn: Button = Button.new()
		unpin_btn.text = "🔓 Auto"
		unpin_btn.tooltip_text = "Unpin — return to slider auto-allocation"
		unpin_btn.custom_minimum_size = Vector2(52, 22)
		unpin_btn.add_theme_font_size_override("font_size", 11)
		unpin_btn.pressed.connect(func() -> void:
			_unpin_ant(ant)
		)
		actions_hbox.add_child(unpin_btn)

	# View button on the right
	var view_btn: Button = Button.new()
	view_btn.text = "🔎 View"
	view_btn.custom_minimum_size = Vector2(64, 28)
	view_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	view_btn.tooltip_text = "Pan camera to this ant"
	view_btn.pressed.connect(func() -> void:
		_focus_on_ant(ant)
	)
	hbox.add_child(view_btn)

	return card

func _assign_role_to_ant(ant: AntController, role: Enums.JobType) -> void:
	if not is_instance_valid(ant):
		return
	ant.assign_job_manually(role)
	var total_alive: int = get_tree().get_nodes_in_group("workers").size()
	TaskAllocationManager.recalculate_job_targets(total_alive)
	refresh_roster()

func _unpin_ant(ant: AntController) -> void:
	if not is_instance_valid(ant):
		return
	ant.unpin_job()
	var new_job: Enums.JobType = TaskAllocationManager.request_job_for_ant(ant)
	ant.assign_job(new_job)
	var total_alive: int = get_tree().get_nodes_in_group("workers").size()
	TaskAllocationManager.recalculate_job_targets(total_alive)
	refresh_roster()

func _focus_on_ant(ant: AntController) -> void:
	if not is_instance_valid(ant):
		return
	var camera: CameraController = get_tree().get_first_node_in_group("camera") as CameraController
	if camera != null:
		camera.center_on_position(ant.global_position)
