extends Node2D

@onready var area = $DunkArea

signal player_near_hoop(body)

func _ready():
	area.connect("body_entered", Callable(self, "_on_body_dunk_area_entered"))
	area.connect("body_exited", Callable(self, "_on_body_dunk_area_exited"))

func _on_body_dunk_area_entered(body):
	if body.name == "Player":
		emit_signal("player_near_hoop", self)

func _on_body_dunk_area_exited(body):
	if body.name == "Player":
		body._on_player_left_hoop(self)
