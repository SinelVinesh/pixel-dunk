extends Node

var main_menu = preload("res://menus/main_menu/main_menu.tscn").instantiate()
var game = preload("res://scenes/game/Game.tscn").instantiate()

func _ready() -> void:
	main_menu.connect('start_game',_load_prematch_menu)
	add_child(main_menu)
	
func _load_prematch_menu() -> void:
	print("Ok")
	remove_child(main_menu)
	add_child(game)
