extends Control

var score_manager: Node

@onready var blue_label = $Background/T2_Score
@onready var red_label = $Background/T1_Score
@onready var combo_label = $Background/Potential_Score

func _ready():
	# Get the ScoreManager singleton
	score_manager = get_node("/root/ScoreManager")
	if not score_manager:
		push_error("ScoreManager autoload not found!")
	else:
	# Connect to score updated signal
		score_manager.score_updated.connect(_on_score_updated)
		combo_label.text = "01"

func _on_score_updated(blue_score: int, red_score: int, stackable: int):

	if blue_label:
		blue_label.text = "%02d" % blue_score

	if red_label:
		red_label.text = "%02d" % red_score

	if combo_label:
		combo_label.text = "%02d" % stackable

func _update_timer():
	var timer_label = $Background/Time_Value
	var time_left = GameManager.get_time_left()
	if timer_label:
		var minute_left = int(time_left / 60)
		var second_left = int(time_left) % 60
		timer_label.text = "%02d:%02d" % [minute_left, second_left]
