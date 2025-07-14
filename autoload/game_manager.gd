extends Node

signal time_over
signal game_ended

func start_game():
	$GameTimer.start()

func _on_game_timer_timeout() -> void:
	time_over.emit()

func get_time_left() -> float:
	return $GameTimer.time_left

func pause_timer() -> void:
	$GameTimer.paused = true

func resume_timer() -> void:
	$GameTimer.paused = false
	
func emit_game_ended():
	print("game ended")
	game_ended.emit()
