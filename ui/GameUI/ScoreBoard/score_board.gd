extends Control

var score_manager: Node

func _ready():
	# Get the ScoreManager singleton
	_update_timer() 
	score_manager = get_node("/root/ScoreManager")
	if not score_manager:
		push_error("ScoreManager autoload not found!")
	else:
	# Connect to score updated signal
		score_manager.score_updated.connect(_on_score_updated)

func _on_score_updated(blue_score: int, red_score: int, stackable: int):
	var blue_label = $Background/T2_Score
	var red_label = $Background/T1_Score
	var combo_label = $Background/Potential_Score

	if blue_label:
		blue_label.text = "%02d" % blue_score

	if red_label:
		red_label.text = "%02d" % red_score

	if combo_label:
		combo_label.text = "%02d" % stackable

func _update_timer():
	var timer_label = $Background/Time_Value
	if timer_label:
		var minute_left = int($Timer.time_left / 60)
		var second_left = int($Timer.time_left) % 60
		timer_label.text = "%02d:%02d" % [minute_left, second_left]
