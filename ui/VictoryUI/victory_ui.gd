extends Control

const victory_text_template = "[wave amp=40.0 freq=10.0 connected=1]%s[/wave]"
var quitable: bool = false
var frog_texture = "res://assets/assets/ui/png/Background/background_frog.png"
var rabbit_texture = "res://assets/assets/ui/png/Background/background_rabbit.png"
var common_texture = "res://assets/assets/ui/png/Background/background_rabbit_vs_frog.png"

signal close_victory_screen

func initialize_victory_screen():
	quitable = false
	get_tree().create_timer(2).timeout.connect(_on_wait_timer_timeout)
	var winner = ScoreManager.get_winner()
	match winner :
		Constants.Team.FROG :
			$VictoryText.text = victory_text_template%"[color=#ff0044]AMPHIBALL WINS ![/color]"
			$Background.texture = load(frog_texture)
			$Winner1.play("carry_0")
			$Winner2.play("carry_0")
		Constants.Team.RABBIT :
			$VictoryText.text = victory_text_template%"[color=#0095e9]RABBEAST WINS ![/color]"
			$Background.texture = load(rabbit_texture)
			$Winner1.play("carry_1")
			$Winner2.play("carry_1")
		Constants.Team.NONE :
			$Winner1.play("carry_1")
			$Winner2.play("carry_0")
			$Background.texture = load(common_texture)
			$VictoryText.text = victory_text_template%"EVERYBODY WINS !"

func _input(event: InputEvent) -> void:
	if quitable and ((event is InputEventKey and not event.is_pressed()) or (event is InputEventJoypadButton)):
		close_victory_screen.emit()
		quitable =false


func _on_wait_timer_timeout() -> void:
	print("quitable")
	quitable = true
