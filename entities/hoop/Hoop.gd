extends Node2D

@onready var area = $DunkArea

enum Team {
	RABBIT,
	FROG
}

@export var team: Team = Team.FROG

signal player_near_hoop(body)

func _ready():
	area.connect("body_entered", Callable(self, "_on_body_dunk_area_entered"))
	area.connect("body_exited", Callable(self, "_on_body_dunk_area_exited"))
	$StaticBody2D/AnimatedSprite2D.play("hoop_%s" % team)

func _on_body_dunk_area_entered(body):
	if body is Player:
		emit_signal("player_near_hoop", self)

func _on_body_dunk_area_exited(body):
	if body is Player:
		body._on_player_left_hoop(self)


func _on_area_2d_body_entered(body: Node2D) -> void:
	print(body.shooting_point_factor)
	$"/root/ScoreManager".add_score_points(body.shooting_team, body.shooting_point_factor) 
