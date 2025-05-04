extends RigidBody2D
class_name Ball

# Ball properties
@export_group("Properties")
@export var bounce_speed_loss: float = 0.95 #Speed loss value per bounce
@export var steal_cooldown_duration: float = 1.0 # Duration in seconds the previous handler cannot pickup the ball

# Ball effects
@export_group("Effects")
@export var bounce_fx : PackedScene #Particle to use for bounce impact effect
@export var steal_sound : AudioStream #Sound to play when ball is stolen

@onready var ball_rotation: float = rotation #Store ball default rotation
@onready var ball_radius: float = $CollisionShape2D.shape.radius #Store ball radius
@onready var bounce_sound = $BounceSound #Store bounce sfx node
@onready var default_gravity_scale = get_gravity_scale() # Store default gravity scale
@onready var ball_area : Area2D = $Area2D # Store ball area 2D node
@onready var steal_cooldown_timer: Timer = $StealCooldownTimer # Timer for cooldown after ball is stolen
@onready var steal_sound_player: AudioStreamPlayer = $StealSound # Sound player for steal effect

var last_state: PhysicsDirectBodyState2D #State that contains contact collision infos
var min_velocity : float # Minimum velocity to apply bounce vfx / sfx
var ball_handler # Node for the player currently holding the ball
var previous_handler # Node for the player that previously held the ball
var handlers_to_ignore = [] # Array of players that temporarily cannot pickup the ball

# The gravity scale to exaggerate the ball's shooting trajectory
var shoot_gravity_scale: float = 1.8

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
	bounce_sound.volume_db = linear_to_db((((max(abs(linear_velocity.x), abs(linear_velocity.y))) - min_velocity) / 450) * 2) #Normalize current highest linear velocity between x or y into 0 - 2

	#Play bounce sfx
	bounce_sound.play()

	#Spawn bounce vfx to contact location
	if abs(linear_velocity.x) > (min_velocity * 5) or abs(linear_velocity.y) > (min_velocity * 5):
		for i in range(last_state.get_contact_count()): #Get state infos for each contact
			var contact_position = last_state.get_contact_local_position(i) #Store contacte location
			var bounce_fx_to_spawn = bounce_fx.instantiate() #Instantiate bounce particle vfx
			add_child(bounce_fx_to_spawn) #Explicit content (not what you think)
			bounce_fx_to_spawn.global_position = contact_position #Set bounce particle vfx location
			bounce_fx_to_spawn._spawn_particle() #Call the function to emit particles
			#print(str(bounce_fx_to_spawn.global_position)) #For debug

#Called each physic simulation
func _integrate_forces(state):
	last_state = state #Store state in last state

# Handle activate / deactivate ball collision and gravity when picked up / passed
# Condition: true = freeze ball for pickup, false = unfreeze ball for pass
# Handler: player who has ball
func _handle_freeze(condition : bool, handler):
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
		else:
			ball_handler = handler # Set ball handler to current player who has ball
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

		# Set previous handler to current handler before clearing
		if ball_handler != null:
			previous_handler = ball_handler

		ball_handler = null # Clear ball handler

# Handle ball stealing from one player to another
func handle_ball_steal(new_handler):
	# Store the player who's losing the ball
	previous_handler = ball_handler

	# If the previous handler is a valid player
	if previous_handler != null:
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
	return not handlers_to_ignore.has(player)

# Called when the steal cooldown timer times out
func _on_steal_cooldown_timeout():
	# Remove the previous handler from the ignore list
	if previous_handler != null and handlers_to_ignore.has(previous_handler):
		handlers_to_ignore.erase(previous_handler)
