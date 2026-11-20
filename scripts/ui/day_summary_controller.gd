class_name DaySummaryController
extends Control

## Day Summary modal — shown between days with ants born/lost, food gathered,
## day rating badge, and a "Continue →" button to start the next day.

signal continue_pressed()

@onready var _title_label:   Label  = $Panel/VBox/TitleLabel
@onready var _born_label:    Label  = $Panel/VBox/StatsBox/BornLabel
@onready var _lost_label:    Label  = $Panel/VBox/StatsBox/LostLabel
@onready var _food_label:    Label  = $Panel/VBox/StatsBox/FoodLabel
@onready var _rating_label:  Label  = $Panel/VBox/RatingLabel
@onready var _continue_btn:  Button = $Panel/VBox/ContinueBtn

var _last_stats: Dictionary = {}


func _ready() -> void:
	hide()
	GameManager.connect("day_ended", _on_day_ended)
	GameManager.connect("game_won",  func(rating: String, fs: Dictionary) -> void: show_victory(rating, fs))
	GameManager.connect("game_over", func(reason: String) -> void: show_defeat(reason))
	_continue_btn.connect("pressed", _on_continue_pressed)


## Called by GameManager.day_ended signal — populate and show modal.
func _on_day_ended(day: int, stats: Dictionary) -> void:
	_last_stats = stats

	# If game already in VICTORY or DEFEAT we don't show day summary
	if GameManager.game_state == Enums.GameState.VICTORY or \
	   GameManager.game_state == Enums.GameState.DEFEAT:
		return

	_title_label.text    = "Day %d Complete!" % day
	_born_label.text     = "Ants born:    %d" % stats.get("ants_born", 0)
	_lost_label.text     = "Ants lost:    %d" % stats.get("ants_lost", 0)
	_food_label.text     = "Food gathered: %d" % stats.get("food_gathered", 0)
	_rating_label.text   = _day_rating(stats)
	_continue_btn.text   = "Day %d →" % (day + 1) if day < 10 else "Final Summary"

	show()


func _on_continue_pressed() -> void:
	hide()
	emit_signal("continue_pressed")
	GameManager.start_next_day()


## Simple per-day rating based on survival ratio.
func _day_rating(stats: Dictionary) -> String:
	var born: int = stats.get("ants_born", 0)
	var lost: int = stats.get("ants_lost", 0)
	if lost == 0 and born > 0:
		return "⭐⭐⭐  Excellent!"
	elif lost <= 2:
		return "⭐⭐  Good"
	elif lost <= 5:
		return "⭐  Struggled"
	else:
		return "☠  Heavy Losses"


## Show the final victory panel.
func show_victory(rating: String, final_stats: Dictionary) -> void:
	_title_label.text   = "🏆  Colony Survived 10 Days!"
	_born_label.text    = "Total ants alive:   %d" % final_stats.get("total_workers", 0)
	_lost_label.text    = "Days survived:  %d / 10" % final_stats.get("days_survived", 10)
	_food_label.text    = ""
	_rating_label.text  = "Final Rating:  " + rating
	_continue_btn.text  = "Play Again"
	_continue_btn.disconnect("pressed", _on_continue_pressed)
	_continue_btn.connect("pressed", _on_restart_pressed)
	show()


## Show the final defeat panel.
func show_defeat(reason: String) -> void:
	_title_label.text   = "💀  Colony Collapsed"
	_born_label.text    = reason
	_lost_label.text    = ""
	_food_label.text    = ""
	_rating_label.text  = ""
	_continue_btn.text  = "Try Again"
	_continue_btn.disconnect("pressed", _on_continue_pressed)
	_continue_btn.connect("pressed", _on_restart_pressed)
	show()


func _on_restart_pressed() -> void:
	hide()
	GameManager.start_new_run()
