extends Node2D

@onready var area = $DunkArea

@export var team: Constants.Team = Constants.Team.FROG

func _ready():
	if team == 1 :
		$StaticBody2D/BackCollision.position.x = 9
		$StaticBody2D/FrontCollision.position.x = 69
		$GoalArea.position.x = 14
	$StaticBody2D/AnimatedSprite2D.play("hoop_%s" % team)

func _on_body_dunk_area_entered(body):
	if body is Player and body.team_id != team:
		body.player_near_hoop(self)
		

func _on_body_dunk_area_exited(body):
	if body is Player and body.team_id != team:
		body.player_left_hoop(self)


func _on_area_2d_body_entered(body: Node2D) -> void:
	if body is Ball :
		var from_above = body.linear_velocity.y > 1
		if from_above :
			print("Shoot from above")
			var team_id = body.shooting_team

			# If the player shoots on his own hoop, the points come to the other team
			if team_id == team:
				team_id = 1 - team_id

			ScoreManager.add_score_points(team_id, body.shooting_point_factor)
