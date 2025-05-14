extends Node

var main_menu = preload("res://menus/main_menu/main_menu.tscn")
var main_menu_instance: Node
var game = preload("res://scenes/game/Game.tscn")
var game_instance: Node
var victory_screen = preload("res://ui/VictoryUI/VictoryUI.tscn").instantiate()

func _ready() -> void:
	main_menu_instance = main_menu.instantiate()
	main_menu_instance.connect('start_game',_load_game)
	add_child(main_menu_instance)
	GameManager.connect("game_ended",_load_victory_screen)
	victory_screen.connect("close_victory_screen",_load_main_menu)
	
func _load_main_menu():
	remove_child(victory_screen)
	main_menu_instance = main_menu.instantiate()
	main_menu_instance.connect('start_game',_load_game)
	add_child(main_menu_instance)
	
func _load_game() -> void:
	print("Ok")
	remove_child(main_menu_instance)
	game_instance = game.instantiate()
	add_child(game_instance)
	
func _load_victory_screen() -> void:
	print("Game Ended")
	remove_child(game_instance)
	add_child(victory_screen)
	victory_screen.initialize_victory_screen()
