extends Control

signal start_game

enum MenuState {
	TITLE,
	TRANSITION_TO_PREMATCH,
	PREMATCH,
	TRANSITION_TO_GAME
}

var current_state: int = MenuState.TITLE

func _input(event: InputEvent) -> void:
	match current_state:
		MenuState.TITLE:
			handle_title_input(event)
		MenuState.PREMATCH:
			handle_prematch_input(event)

func handle_title_input(event: InputEvent) -> void:
	if (event is InputEventKey and not event.is_pressed()) or (event is InputEventJoypadButton):
		# Transition to Prematch state and launch the correct animation
		$AnimationPlayer.play('to_prematch')
		current_state = MenuState.TRANSITION_TO_PREMATCH
	
		
func handle_prematch_input(event: InputEvent) -> void:
	if (event is InputEventKey and not event.is_pressed()) or (event is InputEventJoypadButton):
		start_game.emit()
		current_state = MenuState.TRANSITION_TO_GAME
		print("title.gd : emiting `start_game` signal")

func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	match anim_name:
		'to_prematch':
			current_state = MenuState.PREMATCH
			print("title.gd : changing to `prematch` state")
