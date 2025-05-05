extends Node

# Points values
@export var dunk_points: int = 2
@export var shoot_points: int = 3
@export var pass_points: int = 1

# Team scores
var blue_team_score: int = 0
var red_team_score: int = 0

# Current stackable points (resets when team loses ball)
var stackable_points: int = 0
var last_ball_team: int = -1 # -1 = no team has the ball yet

# Score signals
signal score_updated(blue_score: int, red_score: int, stackable: int)

# Called when the node enters the scene tree
func _ready():
	# Reset everything on ready
	reset_scores()

# Reset all scores
func reset_scores() -> void:
	blue_team_score = 0
	red_team_score = 0
	stackable_points = 0
	last_ball_team = -1
	emit_signal("score_updated", blue_team_score, red_team_score, stackable_points)

# Handle successful pass
func add_pass_points() -> void:
	stackable_points += pass_points
	emit_signal("score_updated", blue_team_score, red_team_score, stackable_points)

# Add points for scoring (dunk or shoot)
func add_score_points(team_id: int, is_dunk: bool) -> void:
	var base_points = dunk_points if is_dunk else shoot_points
	var total_points = base_points + stackable_points

	if team_id == 0: # Blue team
		blue_team_score += total_points
	elif team_id == 1: # Red team
		red_team_score += total_points

	# Reset stackable points after scoring
	stackable_points = 0
	emit_signal("score_updated", blue_team_score, red_team_score, stackable_points)

# Check if ball changed teams and reset stackable points if needed
func check_ball_possession(ball_handler) -> void:
	if ball_handler == null:
		return

	var current_team = ball_handler.team_id

	# If ball was just picked up for the first time
	if last_ball_team == -1:
		last_ball_team = current_team
		return

	# If ball changed to the opposite team, reset stackable points
	if current_team != last_ball_team:
		stackable_points = 0
		emit_signal("score_updated", blue_team_score, red_team_score, stackable_points)

	# Update the last team that had the ball
	last_ball_team = current_team
