extends RigidBody2D
class_name Ball

# Ball properties
@export_group("Properties")
@export var bounce_speed_loss: float = 0.95 #Speed loss value per bounce

# Ball effects
@export_group("Effects")
@export var bounce_fx : PackedScene #Particle to use for bounce impact effect

@onready var ball_rotation: float = rotation #Store ball default rotation
@onready var ball_radius: float = $CollisionShape2D.shape.radius #Store ball radius
@onready var bounce_sound = $BounceSound #Store bounce sfx node
@onready var default_gravity_scale = get_gravity_scale() # Store default gravity scale
@onready var ball_area : Area2D = $Area2D # Store ball area 2D node

var last_state: PhysicsDirectBodyState2D #State that contains contact collision infos
var min_velocity : float # Minimum velocity to apply bounce vfx / sfx
var ball_handler # Node for the player currently holding the ball


#On ball spawn
func _ready() -> void:
	pass

	#Initially launch ball to the right
	#linear_velocity = Vector2(300, -0) #For test

#Called every frame
func _process(delta: float) -> void:
	pass

#Called each time collides with a body
func _on_body_entered(body: Node) -> void:
	pass

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

		ball_handler = null # Clear ball handler
