extends RigidBody2D
class_name Ball

# Ball properties
@export_group("Properties")
@export var bounce_speed_loss: float = 0.95 # Speed loss value per bounce
@export var steal_cooldown_duration: float = 1.0 # Duration in seconds the previous handler cannot pickup the ball

# Ball effects
@export_group("Effects")
@export var bounce_fx: PackedScene # Particle to use for bounce impact effect
@export var steal_sound: AudioStream # Sound to play when ball is stolen

@onready var ball_rotation: float = rotation # Store ball default rotation
@onready var ball_radius: float = $CollisionShape2D.shape.radius # Store ball radius
@onready var bounce_sound = $BounceSound # Store bounce sfx node
@onready var default_gravity_scale = get_gravity_scale() # Store default gravity scale
@onready var ball_area: Area2D = $Area2D # Store ball area 2D node
@onready var steal_cooldown_timer: Timer = $StealCooldownTimer # Timer for cooldown after ball is stolen
@onready var steal_sound_player: AudioStreamPlayer = $StealSound # Sound player for steal effect

var last_state: PhysicsDirectBodyState2D # State that contains contact collision infos
var min_velocity: float # Minimum velocity to apply bounce vfx / sfx
var ball_handler # Node for the player currently holding the ball
var previous_handler # Node for the player that previously held the ball
var previous_passer # Node for the player who last passed the ball
var handlers_to_ignore = [] # Array of players that temporarily cannot pickup the ball

var shooting_point_factor: int
var shooting_team: int

# The gravity scale to exaggerate the ball's shooting trajectory
var shoot_gravity_scale: float = 1.8
var team_to_ignore: int = -1

#On ball spawn
func _ready() -> void:
	# Create steal cooldown timer if it doesn't exist
	if not has_node("StealCooldownTimer"):
		var timer = Timer.new()
		timer.name = "StealCooldownTimer"
		timer.one_shot = true
		timer.autostart = false
		add_child(timer)
		steal_cooldown_timer = timer

	steal_cooldown_timer.timeout.connect(_on_steal_cooldown_timeout)

	$"/root/ScoreManager".connect("scored_by_team", _on_scored_by_team)

	#Initially launch ball to the right
	#linear_velocity = Vector2(300, -0) #For test

#Called every frame
func _process(delta: float) -> void:
	pass

#Called each time collides with a body
func _on_body_entered(body: Node) -> void:
	#Apply speed loss on bounce
	linear_velocity = linear_velocity.normalized() * linear_velocity.length() * bounce_speed_loss

	#Reduces volume according to max current linear velocity (x or y)
	bounce_sound.volume_db = linear_to_db((((max(abs(linear_velocity.x), abs(linear_velocity.y))) - min_velocity) / 450) * 2) # Normalize current highest linear velocity between x or y into 0 - 2

	#Play bounce sfx
	bounce_sound.play()

	#Spawn bounce vfx to contact location
	if abs(linear_velocity.x) > (min_velocity * 5) or abs(linear_velocity.y) > (min_velocity * 5):
		for i in range(last_state.get_contact_count()): # Get state infos for each contact
			var contact_position = last_state.get_contact_local_position(i) # Store contacte location
			var bounce_fx_to_spawn = bounce_fx.instantiate() # Instantiate bounce particle vfx
			add_child(bounce_fx_to_spawn) # Explicit content (not what you think)
			bounce_fx_to_spawn.global_position = contact_position # Set bounce particle vfx location
			bounce_fx_to_spawn._spawn_particle() # Call the function to emit particles
			#print(str(bounce_fx_to_spawn.global_position)) #For debug

#Called each physic simulation
func _integrate_forces(state):
	last_state = state # Store state in last state

# Handle activate / deactivate ball collision and gravity when picked up / passed
# Condition: true = freeze ball for pickup, false = unfreeze ball for pass
# Handler: player who has ball
func _handle_freeze(condition: bool, handler):
	if condition:
		set_contact_monitor(false) # Disable contact monitor

		# Set gravity scale to 0 to prevent gravity accumulation while held
		set_gravity_scale(0)

		set_collision_layer_value(5, false) # Set no collision layer

		# Set no monitoring and not monitorable for ball area 2d
		ball_area.set_monitoring(false)
		ball_area.set_monitorable(false)

		# Check if ball is being stolen from another player
		if ball_handler != null and ball_handler != handler:
			handle_ball_steal(handler)
			# Note: ball_handler is now set in handle_ball_steal if the steal was successful
		else:
			ball_handler = handler # Set ball handler to current player who has ball

			# Also update ScoreManager for normal ball pickup
			var score_manager = get_node_or_null("/root/ScoreManager")
			if score_manager and handler != null:
				# Only add stackable points if:
				# - There is a previous passer (ball was actually passed)
				# - Current handler is not the previous passer (not catching your own pass)
				# - Previous passer and current handler are on the same team
				if previous_passer != null and previous_passer != handler and previous_passer.team_id == handler.team_id:
					score_manager.add_pass_points()

				# Always check ball possession to handle team changes
				score_manager.check_ball_possession(handler)

				# Reset previous passer after successful catch is processed
				previous_passer = null
	else:
		# Reset gravity to default before passing
		set_gravity_scale(default_gravity_scale)

		set_contact_monitor(true) # Enable contact monitor
		set_collision_layer_value(5, true) # Set enabled collision layer

		# Set monitoring and monitorable for ball area 2d
		ball_area.set_monitoring(true)
		ball_area.set_monitorable(true)

		# Note: When passing, linear_velocity will be set completely in the Player's pass_ball() function
		# We don't want to zero it here anymore, as we prefer to have the complete velocity set later
		# This helps with keeping player momentum in passes

		# Record who is passing the ball before clearing the handler
		if ball_handler != null:
			previous_passer = ball_handler
			previous_handler = ball_handler

		ball_handler = null # Clear ball handler

# Handle ball stealing from one player to another
func handle_ball_steal(new_handler):
	# Store the player who's losing the ball
	previous_handler = ball_handler

	# If the previous handler is a valid player
	if previous_handler != null:
		# Check if the current handler is dashing or if they're on the same team - if so, ignore steal attempt
		if previous_handler.current_state == previous_handler.PlayerState.DASHING or previous_handler.team_id == new_handler.team_id:
			return # Abort steal, ball handler keeps the ball

		# Add previous handler to ignore list
		handlers_to_ignore.append(previous_handler)

		# Tell the previous handler they no longer have the ball
		previous_handler.has_ball = false
		previous_handler.current_state = previous_handler.PlayerState.FREE

		# Show steal effect
		show_steal_effect()

		# Start the cooldown timer
		steal_cooldown_timer.wait_time = steal_cooldown_duration
		steal_cooldown_timer.start()

		# Set the new handler
		ball_handler = new_handler

		# Check if teams have changed and handle score reset if needed
		var score_manager = get_node_or_null("/root/ScoreManager")
		if score_manager:
			score_manager.check_ball_possession(new_handler)
	else:
		# If there was no previous handler, just set the new one
		ball_handler = new_handler

		# Update the score manager with the new ball handler
		var score_manager = get_node_or_null("/root/ScoreManager")
		if score_manager:
			score_manager.check_ball_possession(new_handler)

# Show a visual effect when the ball is stolen
func show_steal_effect():
	# Simple visual feedback using a tween to flash the ball
	var tween = create_tween()
	tween.tween_property($Sprite2D, "modulate", Color(1, 0.5, 0, 1), 0.1) # Flash orange
	tween.tween_property($Sprite2D, "modulate", Color(1, 1, 1, 1), 0.1)
	tween.tween_property($Sprite2D, "modulate", Color(1, 0.5, 0, 1), 0.1)
	tween.tween_property($Sprite2D, "modulate", Color(1, 1, 1, 1), 0.1)

	# Play steal sound if it exists
	if steal_sound_player and steal_sound_player.stream:
		steal_sound_player.play()

# Check if a player can pick up the ball
func can_pickup(player) -> bool:
	var result = not handlers_to_ignore.has(player) and team_to_ignore != player.team_id
	# If the ball is picked up by the other team, allow the scoring team to pick it again
	if result:
		team_to_ignore = -1
	return result

# Called when the steal cooldown timer times out
func _on_steal_cooldown_timeout():
	handlers_to_ignore = []

# Setting shooting team and point factor
func set_shooting_team(team: int, point_factor: int) -> void:
	shooting_team = team
	shooting_point_factor = point_factor

func _on_scored_by_team(team_id: int) -> void:
	linear_velocity.y = 0
	linear_velocity.x = 0
	team_to_ignore = team_id
