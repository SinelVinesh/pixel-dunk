extends CharacterBody2D
class_name Player

class AnimationSettings :
	var name: String
	var file: String
	var looping: bool
	var speed: float

	func _init(new_name: String, new_file: String, new_looping: bool, new_speed: float):
		self.name = new_name
		self.file = new_file
		self.looping = new_looping
		self.speed = new_speed

# Character's metadata
@export_group("Character Metadata")
## PLayer's name, used to load the animated sprite
@export var character_name: String = "Frog_01"

# Player movement and physics properties
@export_group("Movement")
## Base horizontal and vertical movement speed
@export var move_speed: float = 300.0
## How quickly the player reaches max speed (higher = faster acceleration)
@export var acceleration: float = 30.0
## Deceleration factor when not moving (0-1, lower = more slippery)
@export var friction: float = 0.85

@export_group("Jumping")
## Vertical force applied when jumping
@export var jump_force: float = 600.0
## Gravity force applied each frame when in air
@export var gravity: float = 30.0
## Multiplier for gravity when rising, makes ascent faster or slower (1.0 = normal, lower = higher jumps)
@export_range(0.5, 1.0, 0.05) var rise_gravity_multiplier: float = 0.8
## Multiplier for gravity when falling, makes descent faster than ascent (1.0 = same speed, higher = fall faster)
@export_range(1.0, 3.0, 0.1) var fall_gravity_multiplier: float = 1.4
## Multiplier for gravity when holding the ball | lower = slower fall, more floaty (0.4 = slower fall, 1.0 = normal rise or fall multiplier)
@export_range(0.4, 1.0, 0.05) var holding_ball_gravity_multiplier: float = 0.7
## Maximum downward velocity to prevent excessive falling speed (in pixels per second) | lower = faster fall (0 = no limit)
@export var max_fall_speed: float = 1000.0
## Time in seconds player can still jump after leaving a platform
@export_range(0.0, 0.3, 0.01) var coyote_time: float = 0.1

@export_group("Double Jump")
## Whether double jumping is enabled for this player
@export var double_jump_enabled: bool = true
## Force multiplier for double jump (relative to regular jump)
@export_range(0.1, 1.5, 0.05) var double_jump_force_multiplier: float = 0.8
## Air control multiplier during double jump (lower = less control)
@export_range(0.1, 1.0, 0.05) var double_jump_control_multiplier: float = 0.7

@export_group("Dash")
## Speed multiplier when dashing
@export var dash_force: float = 1000.0
## How long a dash lasts in seconds
@export var dash_duration: float = 0.3
## Maximum number of dashes before needing to recharge
@export var max_dash_count: int = 2
## Time in seconds to recharge one dash
@export var dash_recharge_time: float = 2.0
## Pause dash recharge timer when player is in the air
@export var pause_recharge_in_air: bool = true
## Pause the dash recharge timer when dashing
@export var pause_recharge_when_dashing: bool = true
## Reset the dash recharge timer after a dash is used
@export var reset_timer_after_dash: bool = true

@export_group("Game")
## Character ID: f1 (Frog 1), f2 (Frog 2), r1 (Rabbit 1), r2 (Rabbit 2)
@export var character_id: String = "f1"
## Speed of the ball when passed
@export var pass_speed: float = 1300.0
## Player team (0 = blue team, 1 = red team)
@export var team_id: int = 0
## Player ID for identification (1-4)
@export var player_id: int = 1
## Speed of the ball when the player shoots
@export var shoot_speed: float = 1200.0
## Length of the trajectory curve in SHOOTING state
@export var trajectory_length: float = 80

## Input prefix for this player (e.g., "p1_" for player 1)
var input_prefix: String = ""

var shoot_direction: Vector2 = Vector2.ZERO

# State machine - Defines the possible states of the player
enum PlayerState {
	FREE,            # Normal movement without the ball
	BALL_POSSESSION, # Holding the ball (restricted movement)
	DASHING,         # Currently performing a dash
	JUMPING,         # In the air after jumping (first jump)
	DOUBLE_JUMPING,   # In the air after a second jump
	DUNKING,
	SHOOTING
}
var current_state: int = PlayerState.JUMPING  # Current state of the player

# Animations
enum PlayerAnimation {
	IDLE,
	AIM,
	CARRY,
	DASH,
	JUMP,
	DOUBLE_JUMP,
	RUN,
	SHOOT,
	PASS,
	LAND,
	FALL
}

var animation_settings: Dictionary[PlayerAnimation, AnimationSettings] = {}

# Player status variables
var has_ball: bool = false         # Whether the player is holding the ball
var on_ground: bool = false        # Whether the player is touching the ground
var was_on_ground: bool = false    # Track previous ground state for detecting when player starts falling
var dash_count: int = 0            # Current number of dashes available
var can_double_jump: bool = false  # Whether the player can perform a double jump
var in_dash: bool = false          # Whether the player is currently dashing
var dash_direction: Vector2 = Vector2.ZERO  # Direction of the current dash
var dash_timer: float = 0.0        # Time remaining in the current dash
var coyote_timer: float = 0.0      # Timer for coyote time (jumping after falling)
var can_coyote_jump: bool = false  # Whether player can use coyote jump
var preserve_dash_momentum_with_ball: bool = false # It's to prevent the player from flying when the dashing diagonally or upwards, change the method if you find a better solution - Abdoul
# Node references - Links to child nodes in the scene
@onready var sprite: Sprite2D = $Sprite2D  # Player's visual sprite
@onready var ground_check: RayCast2D = $GroundCheck  # Ray for detecting ground
@onready var dash_particles: GPUParticles2D = $DashParticles  # Particle effect for dashing
@onready var ball_position: Marker2D = $Node_Flipper/BallPosition  # Position where ball appears when held
@onready var dash_cooldown_timer: Timer = $DashCooldownTimer  # Timer for recharging dashes
@onready var animation_player: AnimationPlayer = $AnimationPlayer  # Controls animations
@onready var node_flipper : Node2D = $Node_Flipper # Used to flip its child nodes
@onready var pass_direction_line: Line2D = $PassDirectionLine # Line showing pass direction
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D # Used to flip the player sprite


# Sound effect nodes
@onready var jump_sound: AudioStreamPlayer = $JumpSound  # Sound when jumping
@onready var dash_sound: AudioStreamPlayer = $DashSound  # Sound when dashing
@onready var pass_sound: AudioStreamPlayer = $PassSound  # Sound when passing

# Hoop
@onready var hoop_r: Node2D = $"../HoopR"
@onready var hoop_f: Node2D = $"../HoopF"
var hoop: Node2D
var near_hoop: bool = false
var current_hoop: Node2D = null

# Input state variables
var move_direction: Vector2 = Vector2.ZERO  # Direction player is trying to move
var looking_direction: Vector2 = Vector2.RIGHT  # Direction player is facing
var dash_pressed: bool = false  # Whether dash button was just pressed
var jump_pressed: bool = false  # Whether jump button was just pressed
var pass_pressed: bool = false  # Whether pass button was just pressed
var shoot_pressed: bool = false
var shoot_released: bool = false

# Used to store the ball reference
var ball

# Animation related var
var animation_to_wait_for: String = ""

# Signals - Events that other nodes can connect to
signal dash_used(player)  # Emitted when a dash is used
signal dash_recharged(player)  # Emitted when a dash is recharged


# Called when the node enters the scene tree for the first time
func _ready() -> void:
	# Initialize dash particles (turned off by default)
	dash_particles.emitting = false

	# Initialize dash count to max (we'll start with full dashes)
	dash_count = max_dash_count
	emit_signal("dash_recharged", self)

	# Configure dash cooldown timer
	dash_cooldown_timer.wait_time = dash_recharge_time

	# Initialize dash state
	in_dash = false
	dash_timer = 0.0

	# Initialize ground tracking
	was_on_ground = false
	can_coyote_jump = false
	coyote_timer = 0.0

	# Set up visual indicators for player number and team
	_update_visual_indicators()


# Called every physics frame (~60 times per second)
func _physics_process(delta: float) -> void:
	# Process player input
	get_input()

	# Update ground detection
	was_on_ground = on_ground
	on_ground = ground_check.is_colliding()

	# Handle coyote time
	update_coyote_time(delta)

	# Handle behavior based on current state
	match current_state:
		PlayerState.FREE:
			handle_free_movement(delta)
		PlayerState.BALL_POSSESSION:
			handle_ball_possession(delta)
		PlayerState.DASHING:
			handle_dash(delta)
		PlayerState.JUMPING:
			handle_jump(delta)
		PlayerState.DOUBLE_JUMPING:
			handle_double_jump(delta)
		PlayerState.DUNKING:
			handle_dunk(delta)
		PlayerState.SHOOTING:
			handle_shooting(delta)

	# Manage dash cooldown timer - pause when having the ball
	manage_dash_cooldown()

	# Apply movement and handle collisions
	move_and_slide()

	# Update animations based on state and movement
	update_animations()

	# Attach ball if has ball, else, do nothing
	_manage_ball_attachment(ball)

	# Update some nodes transform to flip according to looking direction
	_handle_transform_flip()

func _build_animation_settings() -> void:
	animation_settings = {
		PlayerAnimation.IDLE: AnimationSettings.new("idle_%s" % character_name, "res://assets/Characters/%s/IDLE/idle.png" % character_name, true, 16),
		PlayerAnimation.AIM: AnimationSettings.new("aim_%s" % character_name, "res://assets/Characters/%s/AIM/aim.png" % character_name, true, 16),
		PlayerAnimation.CARRY: AnimationSettings.new("carry_%s" % character_name, "res://assets/Characters/%s/CARRY/dribble.png" % character_name, true, 16),
		PlayerAnimation.DASH: AnimationSettings.new("dash_%s" % character_name, "res://assets/Characters/%s/DASH/dash.png" % character_name, false, 16),
		PlayerAnimation.JUMP: AnimationSettings.new("jump_%s" % character_name, "res://assets/Characters/%s/JUMP/jump.png" % character_name, true, 16),
		PlayerAnimation.DOUBLE_JUMP: AnimationSettings.new("double_jump_%s" % character_name, "res://assets/Characters/%s/JUMP DOUBLE/double_jump.png" % character_name, true, 24),
		PlayerAnimation.RUN: AnimationSettings.new("run_%s" % character_name, "res://assets/Characters/%s/RUN/run.png" % character_name, true, 16),
		PlayerAnimation.SHOOT: AnimationSettings.new("shoot_%s" % character_name, "res://assets/Characters/%s/SHOOT/shoot.png" % character_name, false, 32),
		PlayerAnimation.PASS: AnimationSettings.new("pass_%s" % character_name, "res://assets/Characters/%s/PASS/pass.png" % character_name, false, 24),
		PlayerAnimation.LAND: AnimationSettings.new("land_%s" % character_name, "res://assets/Characters/%s/LAND/land.png" % character_name, true, 16),
		PlayerAnimation.FALL: AnimationSettings.new("fall_%s" % character_name, "res://assets/Characters/%s/FALL/fall.png" % character_name, true, 16),
	}


# Load the correct assets in the animated sprite component based on the Character's name
func load_animated_sprite() -> void:
	_build_animation_settings()
	var sprite_frames = animated_sprite.sprite_frames
	for animation in PlayerAnimation.values(): 
		var settings = animation_settings[animation]
		sprite_frames.add_animation(settings.name)
		sprite_frames.set_animation_loop(settings.name, settings.looping)
		sprite_frames.set_animation_speed(settings.name, settings.speed)
		var animation_sheet = load(settings.file)
		var frame_count = animation_sheet.get_width() / 32
		for i in range(frame_count):
			var atlas = AtlasTexture.new()
			atlas.atlas = animation_sheet
			atlas.region = Rect2(32 * i,0,32, 32)
			sprite_frames.add_frame(settings.name, atlas)
	return 

# Update coyote time system
func update_coyote_time(delta: float) -> void:
	# Start coyote time when player just left the ground (and wasn't jumping)
	if was_on_ground and !on_ground and current_state == PlayerState.FREE:
		can_coyote_jump = true
		coyote_timer = coyote_time

		# Transition to JUMPING state after the coyote time window
		# This ensures proper gravity is applied during falls
		if velocity.y >= 0:  # Only if falling (not jumping upward)
			# We'll use a delayed state change - after coyote time expires
			# State will be changed in the timer check below
			pass

	# Count down coyote timer
	if can_coyote_jump:
		coyote_timer -= delta
		if coyote_timer <= 0:
			can_coyote_jump = false

			# If player is falling and didn't use coyote jump, transition to JUMPING state
			if !on_ground and current_state == PlayerState.FREE and velocity.y >= 0:
				current_state = PlayerState.JUMPING
				# Don't allow double jump when walking off ledge unless configured
				can_double_jump = double_jump_enabled

# Process input and update input state variables
func get_input() -> void:
	# Get directional input (WASD or arrow keys)
	# Store full directional input for dashing purposes
	var input_dir = Vector2.ZERO

	# Use input prefix if available, otherwise use default inputs
	if input_prefix.is_empty():
		# Legacy input system without prefix (backward compatibility)
		input_dir.x = Input.get_axis("move_left", "move_right")
		input_dir.y = Input.get_axis("move_up", "move_down")

		jump_pressed = Input.is_action_just_pressed("jump")
		dash_pressed = Input.is_action_just_pressed("dash")
		pass_pressed = Input.is_action_just_pressed("pass")
		shoot_pressed = Input.is_action_pressed("shoot")
		shoot_released = Input.is_action_just_released("shoot")
	else:
		# Prefixed input for multiplayer
		input_dir.x = Input.get_axis(input_prefix + "move_left", input_prefix + "move_right")
		input_dir.y = Input.get_axis(input_prefix + "move_up", input_prefix + "move_down")

		if input_dir.x < 0:
			animated_sprite.flip_h = true
		elif input_dir.x > 0:
			animated_sprite.flip_h = false

		jump_pressed = Input.is_action_just_pressed(input_prefix + "jump")
		dash_pressed = Input.is_action_just_pressed(input_prefix + "dash")
		pass_pressed = Input.is_action_just_pressed(input_prefix + "pass")
		shoot_pressed = Input.is_action_pressed(input_prefix + "shoot")
		shoot_released = Input.is_action_just_released(input_prefix + "shoot")

	var raw_move = input_dir.normalized()

	# For normal movement, we'll restrict vertical input when on ground
	if on_ground and current_state != PlayerState.DASHING:
		# Only allow horizontal movement when on ground (prevents "flying")
		move_direction = Vector2(raw_move.x, 0)
	else:
		# In air or during dash, use full directional movement
		move_direction = raw_move

	# Update looking direction if we're actively moving
	if move_direction.length() > 0.1:
		looking_direction = move_direction.normalized()

	# Update pass direction line
	update_pass_direction_line(input_dir)
	shoot_direction = input_dir

# Apply gravity consistently based on vertical velocity
func apply_gravity() -> void:
	var gravity_modifier = 1.0

	if velocity.y > 0:
		animation_handler(PlayerAnimation.FALL)
		# Falling - apply higher gravity
		gravity_modifier = fall_gravity_multiplier
	else:
		# Rising - apply reduced gravity based on rise_gravity_multiplier
		gravity_modifier = rise_gravity_multiplier

	# If player has ball, apply additional reduction
	if has_ball:
		gravity_modifier *= holding_ball_gravity_multiplier

	# Apply gravity with appropriate modifiers
	velocity.y += gravity * gravity_modifier

	# Clamp to maximum fall speed (slower if holding ball)
	var max_speed = max_fall_speed
	if has_ball:
		max_speed = max_fall_speed * holding_ball_gravity_multiplier

	velocity.y = min(velocity.y, max_speed)

# Handle movement when in the FREE state (not holding ball)
func handle_free_movement(delta: float) -> void:
	# Apply movement with acceleration if input is detected
	if move_direction.length() > 0.1:
		animation_handler(PlayerAnimation.RUN)
		# For horizontal movement
		velocity.x = lerp(velocity.x, move_direction.x * move_speed, acceleration * delta)

		# Remove ability to control vertical movement in the air
		# This prevents "flying" in FREE state
	else:
		animation_handler(PlayerAnimation.IDLE)
		# Apply friction when not moving to slow down
		velocity.x = velocity.x * friction
		if !on_ground:
			# Apply reduced air friction to vertical movement
			velocity.y = velocity.y * friction

	# Apply gravity when in the air
	if !on_ground:
		apply_gravity()

	# Handle jumping (regular or coyote)
	if jump_pressed:
		if on_ground:
			# Regular jump from the ground
			perform_jump()
		elif can_coyote_jump:
			# Coyote jump - still can jump shortly after leaving ground
			perform_jump()
			can_coyote_jump = false  # Use up coyote jump

	# Handle dashing if player has dash charges available
	if dash_pressed and dash_count > 0:
		start_dash()

# Perform a jump (shared logic for regular and coyote jumps)
func perform_jump() -> void:
	animation_handler(PlayerAnimation.JUMP)
	velocity.y = -jump_force
	jump_sound.play()
	current_state = PlayerState.JUMPING

	can_double_jump = double_jump_enabled
	can_coyote_jump = false  # Use up coyote jump

# Perform a double jump
func _perform_double_jump() -> void:
	animation_handler(PlayerAnimation.DOUBLE_JUMP)
	velocity.y = -jump_force * double_jump_force_multiplier  # Use configurable multiplier
	jump_sound.play()
	current_state = PlayerState.DOUBLE_JUMPING
	can_double_jump = false

# Handle movement when holding the ball (BALL_POSSESSION state)
func handle_ball_possession(delta: float) -> void:
	# Movement is restricted to dashing only when having the ball
	# Only apply friction when not in a dash or immediately after a dash
	if not in_dash and (dash_timer <= 0 or not preserve_dash_momentum_with_ball):
		animation_handler(PlayerAnimation.CARRY)
		velocity.x = velocity.x * 0.8  # Apply strong friction to slow down the player

	# Only apply vertical friction when in the air
	if !on_ground:
		velocity.y = velocity.y * friction * 1.2

	# Apply gravity when in the air
	if !on_ground:
		apply_gravity()

	# Handle dashing if player has dash charges available
	if dash_pressed and dash_count > 0:
		start_dash()

	if shoot_pressed and current_state != PlayerState.SHOOTING and has_ball:
		current_state = PlayerState.SHOOTING

	# Handle passing the ball to teammates
	if pass_pressed:
		pass_ball(ball)

	if jump_pressed:
		if near_hoop and current_hoop != null:
			_perform_dunk()
			return

		if on_ground:
			perform_jump()
		else:
			_perform_double_jump()
			pass


# Handle behavior during a dash (DASHING state)
func handle_dash(delta: float) -> void:
	# Countdown dash timer
	dash_timer -= delta

	if dash_timer <= 0:
		# End dash when timer expires
		in_dash = false
		dash_particles.emitting = false

		# Reset momentum based on configuration and ball possession
		if not has_ball or not preserve_dash_momentum_with_ball:
			velocity = Vector2.ZERO

		# Return to appropriate state based on ball possession and ground state
		if has_ball:
			current_state = PlayerState.BALL_POSSESSION
		elif !on_ground:
			# If in the air, go to jumping state
			current_state = PlayerState.JUMPING
		else:
			current_state = PlayerState.FREE
	else:
		# Apply constant velocity in dash direction
		velocity = dash_direction * dash_force

		# Apply gravity during dash to ensure consistent behavior for vertical dashes
		# This allows upward/diagonal dashes to naturally arc down
		if !on_ground:
			apply_gravity()

		# PS: Handle picking up the ball during dash is done in the pick_up_ball() function

	# If pass pressed
	if pass_pressed:
		pass_ball(ball)

# Handle behavior during a jump (JUMPING state)
func handle_jump(delta: float) -> void:
	# Apply horizontal movement with reduced control in air
	if move_direction.length() > 0.1 and not has_ball:
		velocity.x = lerp(velocity.x, move_direction.x * move_speed, acceleration * delta * 0.8)
	else:
		# Apply air friction (slightly reduced)
		velocity.x = velocity.x * (friction + 0.05)

	# Apply gravity
	apply_gravity()

	if jump_pressed and near_hoop and current_hoop != null:
		_perform_dunk()
	# Handle double jump if available
	if jump_pressed and can_double_jump and double_jump_enabled:
		_perform_double_jump()

	# Handle dash in air
	if dash_pressed and dash_count > 0:
		start_dash()

	# Transition back to free state when landing
	if on_ground:
		if  not has_ball:
			current_state = PlayerState.FREE
		else:
			current_state = PlayerState.BALL_POSSESSION

	# If pass pressed
	if pass_pressed:
		pass_ball(ball)

	if shoot_pressed and current_state != PlayerState.SHOOTING and has_ball:
		current_state = PlayerState.SHOOTING

# Handle behavior during a double jump (DOUBLE_JUMPING state)
func handle_double_jump(delta: float) -> void:
	# Similar to regular jump, but with even less control using the configurable multiplier
	if move_direction.length() > 0.1 and not has_ball:
		velocity.x = lerp(velocity.x, move_direction.x * move_speed, acceleration * delta * double_jump_control_multiplier)
	else:
		velocity.x = velocity.x * (friction + 0.05)

	# Apply gravity
	apply_gravity()

	# Handle dash in air
	if dash_pressed and dash_count > 0:
		start_dash()

	# Transition back to free state when landing
	if on_ground:
		if  not has_ball:
			current_state = PlayerState.FREE
		else:
			current_state = PlayerState.BALL_POSSESSION

	# If pass pressed
	if pass_pressed:
		pass_ball(ball)

	if shoot_pressed and current_state != PlayerState.SHOOTING and has_ball:
		current_state = PlayerState.SHOOTING

# Start a dash - used by multiple states
func start_dash() -> void:
	animation_handler(PlayerAnimation.DASH)
	# For dashing, we want to use the raw input direction to allow diagonal dashes,
	# if multiplayer, we have a prefix like "p1_"
	var dash_input: Vector2
	var prefix = input_prefix
	if prefix.is_empty():
		prefix = ""

	dash_input = Input.get_vector(
		prefix + "move_left",
		prefix + "move_right",
		prefix + "move_up",
		prefix + "move_down"
	).normalized()

	# Get dash direction (use raw input or looking direction)
	dash_direction = dash_input if dash_input.length() > 0.1 else looking_direction

	# Apply dash effects
	dash_count -= 1  # Use up one dash charge
	dash_timer = dash_duration  # Set the dash duration timer
	in_dash = true  # Flag as currently dashing
	current_state = PlayerState.DASHING  # Change to dashing state

	# Reset and start the dash cooldown timer
	if dash_count == max_dash_count - 1 or reset_timer_after_dash:
		# Reset the timer completely by stopping it
		dash_cooldown_timer.stop()
		# Start a new timer cycle
		dash_cooldown_timer.wait_time = dash_recharge_time
		dash_cooldown_timer.start()

	# Visual and audio feedback
	dash_particles.emitting = true  # Start particle effect
	dash_sound.play()  # Play sound effect
	animation_player.play("dash_squash_stretch")  # Play animation

	# Trigger signal for UI/game systems
	emit_signal("dash_used", self)

# Reset the dash counter to maximum
func reset_dash_count() -> void:
	dash_count = max_dash_count
	emit_signal("dash_recharged", self)

# Handle picking up the ball
func pick_up_ball(ball) -> void:
	# Do nothing if player already has the ball
	if has_ball:
		return

	# Store the previous ball just in case we need it later
	# var previous_ball_handler = ball.ball_handler

	# Attempt to pick up the ball - this might fail if the current handler is dashing
	ball._handle_freeze(true, self)

	# Check if we actually got the ball (steal might have been rejected)
	if ball.ball_handler != self:
		return  # Steal was rejected, don't update player state

	#Set has ball
	has_ball = true

	# If dashing, remain in dash state and let it finish naturally
	if current_state == PlayerState.DASHING:
		# Stay in DASHING state to complete the dash
		# The dash will transition to BALL_POSSESSION state when it ends naturally
		pass
	else:
		# If not dashing, switch directly to ball possession
		current_state = PlayerState.BALL_POSSESSION

	# Recharge dash by 1 point when getting the ball (regardless of previous state)
	# Only recharge if not already at max
	if dash_count < max_dash_count:
		dash_count += 1
		# Stop the cooldown timer to prevent extra recharges
		dash_cooldown_timer.stop()
		emit_signal("dash_recharged", self)

	# If dash was fully empty and needs to start recharging for the remaining point
	# if dash_count < max_dash_count:
	# 	dash_cooldown_timer.start()

# Pass the ball to a teammate
func pass_ball(ball) -> void:
	# Do nothing if has no ball
	if not has_ball or not ball:
		return

	# Get the pass direction from input
	var pass_direction = Vector2.ZERO
	animation_handler(PlayerAnimation.PASS,true)
	if input_prefix.is_empty():
		pass_direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	else: # Multiplayer
		pass_direction = Input.get_vector(
			input_prefix + "move_left",
			input_prefix + "move_right",
			input_prefix + "move_up",
			input_prefix + "move_down"
		)

	# If no input direction, use looking direction
	if pass_direction.length() < 0.1:
		pass_direction = looking_direction

	# Normalize the direction
	pass_direction = pass_direction.normalized()

	# Release the ball
	var shooting_point_factor = 1
	if abs(position.x - hoop.position.x) > abs(hoop_f.position.x - hoop.position.x)/2:
		shooting_point_factor = 2
	ball.set_shooting_team(team_id, shooting_point_factor)
	has_ball = false
	ball._handle_freeze(false, self)

	# Apply pass velocity to the ball - completely override any previous velocity
	# This ensures the ball travels exactly in the intended direction without dipping
	ball.linear_velocity = pass_direction * pass_speed

	# Reset player state
	current_state = PlayerState.JUMPING if not on_ground else PlayerState.FREE

	# Play pass sound
	pass_sound.play()

	# Points are now tracked directly in the Ball script when the ball is caught
	# This prevents points from being added for self-passes

# Check for ball in pickup range
func check_for_ball(area):
	# Check if the area owner is a ball, if yes, pick up ball
	if area.owner == get_parent().get_node("Ball"):
		# Store ball reference
		ball = area.owner

		# Check if this player is allowed to pick up the ball
		if ball.can_pickup(self):
			# Pick up ball - this will handle proper state transition
			# regardless of current state (including while dashing)
			pick_up_ball(ball)

# Update animations based on state and movement
func update_animations() -> void:
	# Update sprite orientation based on facing direction
	if looking_direction.x < 0:
		sprite.flip_h = true
	elif looking_direction.x > 0:
		sprite.flip_h = false

	# Choose animation based on current state and movement
	if current_state == PlayerState.DASHING:
		animation_player.play("dash")
	elif current_state == PlayerState.JUMPING or current_state == PlayerState.DOUBLE_JUMPING:
		animation_player.play("jump")
	elif abs(velocity.x) > 10 or abs(velocity.y) > 10:
		animation_player.play("run")
	else:
		animation_player.play("idle")

	# Adjust animation speed based on movement speed
	var speed_factor = clamp(velocity.length() / move_speed, 0.5, 2.0)
	animation_player.speed_scale = speed_factor

# Manage the dash cooldown timer based on player state and options
func manage_dash_cooldown() -> void:
	# Determine if we should pause the timer based on configuration
	var should_pause = false
	# Check if we should pause while in the air
	if pause_recharge_in_air and !on_ground:
		should_pause = true
	# Check if we should pause during dashing
	if pause_recharge_when_dashing and current_state == PlayerState.DASHING:
		should_pause = true
	# Check if we should pause while having the ball
	if has_ball:
		should_pause = true

	# Handle timer pause/unpause based on conditions
	if should_pause:
		if !dash_cooldown_timer.is_paused() and dash_cooldown_timer.time_left > 0:
			dash_cooldown_timer.set_paused(true)
	else:
		if dash_cooldown_timer.is_paused():
			dash_cooldown_timer.set_paused(false)

	# Start the timer if it's not running and we need to recharge
	if dash_count < max_dash_count and !dash_cooldown_timer.is_paused() and !dash_cooldown_timer.time_left > 0:
		dash_cooldown_timer.start()

# Called when the dash cooldown timer completes
func _on_dash_cooldown_timer_timeout() -> void:
	if dash_count < max_dash_count:
		# Restore one dash charge
		dash_count += 1
		emit_signal("dash_recharged", self)

	# Continue timer if not at max dashes
	if dash_count < max_dash_count:
		dash_cooldown_timer.start()  # Continue recharging

# Called when an area 2d enters check ball area 2d
func _on_check_ball_a_2d_area_entered(area: Area2D) -> void:
	# Check if the area owner is the ball
	check_for_ball(area)

# Handle ball attachment
func _manage_ball_attachment(ball):
	if has_ball and ball != null:
		ball.global_position = ball_position.global_position # Attach ball
	else:
		pass

# Used to "flip" transform of desired nodes, just add them
func _handle_transform_flip():
	pass
	if velocity.x < 0: # Turn to face left
		node_flipper.scale.x = abs(node_flipper.scale.x) * -1
	elif velocity.x > 0: # Turn to face right
		node_flipper.scale.x = abs(node_flipper.scale.x)

# Set player ID (used for identification)
func set_player_id(id: int) -> void:
	player_id = id
	print("Player ID set in Player.gd: " + str(player_id))

	# Update visuals when player ID changes
	if is_inside_tree():
		_update_visual_indicators()
	else:
		# If not in tree yet, call deferred when ready
		call_deferred("_update_visual_indicators")

# Update player visuals based on player ID and team
func _update_visual_indicators() -> void:
	# Update tooltip texture based on team_id
	var tooltip = $Sprite2D_tooltip
	if tooltip:
		var texture_path = "res://entities/player/assets/Character_Tooltip" + str(team_id + 1) + ".png"
		tooltip.texture = load(texture_path)

	# Update the player label in the tooltip
	var player_label = $Sprite2D_tooltip/PlayerLabel
	if player_label:
		player_label.text = "P" + str(player_id)

	print("Player visual updated - ID: " + str(player_id))

# Update the pass direction indicator line
func update_pass_direction_line(input_dir: Vector2) -> void:
	if has_ball:
		pass_direction_line.visible = true

		var pass_direction = input_dir.normalized()
		if pass_direction.length() < 0.1:
			pass_direction = looking_direction

		if current_state != PlayerState.SHOOTING:
			pass_direction_line.points = PackedVector2Array([
				Vector2.ZERO,
				pass_direction * 50  # Line length
			])
		else:
			_draw_trajectory_curve_raycast(shoot_direction)
	else:
		pass_direction_line.visible = false

func _draw_trajectory_curve(direction: Vector2) -> void:
	var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
	var time_step := 0.1
	var num_points := trajectory_length

	var points = PackedVector2Array()

	var position = ball.position - global_position
	var velocity = direction.normalized() * shoot_speed

	for i in range(num_points):
		points.append(position)

		# Apply gravity to vertical velocity
		velocity.y += gravity * time_step * ball.shoot_gravity_scale
		# Apply velocity to position
		position += velocity * time_step

	pass_direction_line.points = points
	
func _draw_trajectory_curve_raycast(direction: Vector2) -> void:
	#print("Recorded direction from draw curve: ", direction)
	var space_state = get_world_2d().direct_space_state
	var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
	var time_step := 0.1
	var num_points := trajectory_length

	var points = PackedVector2Array()

	var position = ball.position - global_position
	var velocity = direction * shoot_speed
	
	var bounce_encountered = 0
	
	var mass = ball.mass 
	
	var next_pt_bounce = false
	
	for i in range(num_points):
		if (!next_pt_bounce): points.append(position)

		velocity.y += gravity * time_step * ball.shoot_gravity_scale
		var next_position = position + velocity * time_step
		
		var ray_query = PhysicsRayQueryParameters2D.create(
			position + global_position,
			next_position + global_position
		)
		ray_query.collision_mask = ball.collision_mask
		ray_query.exclude = [ball.get_rid()]  # Don't collide with the ball itself
		
		var ray_result = space_state.intersect_ray(ray_query)
		
		if ray_result:
			# Collision detected - calculate bounce
			var collision_point = ray_result.position - global_position
			var collision_normal = ray_result.normal
			
			# Add collision point to trajectory
			points.append(collision_point)
			
			bounce_encountered += 1
			next_pt_bounce = true
			
			# Calculate bounce velocity using reflection formula
			var dot_product = velocity.dot(collision_normal)
			var reflected_velocity = velocity.bounce(collision_normal)
			
			velocity = reflected_velocity * ball.bounce_speed_loss
			position = collision_point + collision_normal * 0.1
			
			if velocity.length() < 50.0:
				break
				
			if bounce_encountered > 1:
				break
		else:
			# No collision, continue normal trajectory
			position = next_position
			next_pt_bounce = false
		
		# Stop if trajectory goes too far down
		if position.y > 1000:
			break
		
	pass_direction_line.points = points

func player_near_hoop(param_hoop):
	print("Player :", player_id, " near hoop: ", param_hoop)
	near_hoop = true
	current_hoop = param_hoop

func player_left_hoop(param_hoop):
	print("Player :", player_id, " left hoop: ", param_hoop)
	if current_hoop == param_hoop:
		near_hoop = false
		current_hoop = null

func handle_dunk(delta: float) -> void:
	if move_direction.length() > 0.1:
		velocity.x = lerp(velocity.x, move_direction.x * move_speed * 0.3, acceleration * delta * 0.5)
	else:
		velocity.x = velocity.x * (friction + 0.1)

	velocity.y += gravity * 0.5
	velocity.y = min(velocity.y, max_fall_speed * 0.7)

	apply_gravity()

func _perform_dunk() -> void:
	print("Performing dunk")
	if not has_ball or not near_hoop or current_hoop == null:
		return

	if ball == null:
		print("Erreur : le nœud Ball n'est pas trouvé !")
		return
	current_state = PlayerState.DUNKING
	var dunking_from_above = global_position.y < current_hoop.global_position.y
	var player_tween = create_tween()
	player_tween.set_trans(Tween.TRANS_QUAD)
	player_tween.set_ease(Tween.EASE_IN_OUT)

	var start_pos = global_position
	var end_pos = current_hoop.global_position

	var arc_height = 80
	if dunking_from_above:
		arc_height = 40

	var tween_duration = 1.0 if dunking_from_above else 0.8

	player_tween.tween_method(
	func(t: float):
		if dunking_from_above:
			var modified_t = 1.0 - pow(1.0 - t, 10)
			var new_pos = start_pos.lerp(end_pos, modified_t)
			global_position = new_pos
		else:
			var new_pos = start_pos.lerp(end_pos, t)
			var arc_offset = arc_height * (1.0 - (2.0 * t - 1.0) * (2.0 * t - 1.0))
			new_pos.y -= arc_offset
			global_position = new_pos
	,0.0, 1.0, tween_duration)

	player_tween.tween_callback(func():
		ball.get_node('Area2D').set_monitoring(false)
		ball.get_node('Area2D').set_monitorable(false)
		has_ball = false
		ball._handle_freeze(false, self)
		ball.set_shooting_team(team_id, 0)

		# Add score for the dunk
		var score_manager = get_node_or_null("/root/ScoreManager")
		if score_manager:
			score_manager.add_score_points(team_id, 3)

		# Return to normal state after small delay
		var return_timer = get_tree().create_timer(0.5)
		return_timer.timeout.connect(func():
			current_state = PlayerState.JUMPING if not on_ground else PlayerState.FREE
		)
	)

func shoot_ball(ball) -> void:
	animation_handler(PlayerAnimation.SHOOT,true)
	# Do nothing if has no ball
	if not has_ball or not ball:
		current_state = PlayerState.JUMPING if not on_ground else PlayerState.FREE
		return

	## Get the pass direction from input
	#var shot_direction = Vector2.ZERO
	#if input_prefix.is_empty():
		#shot_direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	#else: # Multiplayer
		#shot_direction = Input.get_vector(
			#input_prefix + "move_left",
			#input_prefix + "move_right",
			#input_prefix + "move_up",
			#input_prefix + "move_down"
		#)

	# If no input direction, use looking direction
	if shoot_direction.length() < 0.1:
		shoot_direction = looking_direction

	## Normalize the direction
	#shoot_direction = shoot_direction.normalized()

	# Release the ball
	has_ball = false
	ball._handle_freeze(false, self)

	ball.set_gravity_scale(ball.shoot_gravity_scale)
	
	print("Recorded direction from shoot ball: ", shoot_direction)

	ball.linear_velocity = shoot_direction * shoot_speed
	current_state = PlayerState.JUMPING if not on_ground else PlayerState.FREE

	var shooting_point_factor = 1
	# If the player shoot from the over end of the field set the shooting point factor to 2
	print("Distance from hoop: ", abs(position.x - hoop.position.x))
	print("Distance from hoop_f: ", abs(position.x - hoop_f.position.x))
	print("Distance from hoop_r: ", abs(position.x - hoop_r.position.x))
	if abs(position.x - hoop.position.x) > abs(hoop_f.position.x - hoop.position.x)/2:
		shooting_point_factor = 2
	ball.set_shooting_team(team_id, shooting_point_factor)


func handle_shooting(delta: float) -> void:
	animation_handler(PlayerAnimation.AIM)
	velocity.x = velocity.x * 0.8  # Apply strong friction to slow down the player
	apply_gravity()
	if shoot_released:
		shoot_ball(ball)

func animation_handler(animation: PlayerAnimation, wait_for_animation: bool = false) -> void:
	var settings = animation_settings[animation]
	if animated_sprite.is_playing() and animated_sprite.animation == animation_to_wait_for :
		return
	else :
		animation_to_wait_for = ""
	if animated_sprite.animation != settings.name :
		animated_sprite.play(settings.name)
		print("[ANIMATION] Playing animation: ", settings.name)
		print("[ANIMATION] Number of frames: ", animated_sprite.sprite_frames.get_frame_count(settings.name))
		if wait_for_animation:
			animation_to_wait_for = settings.name

func assign_hoop() -> void:
	# Get HoopF if Team.FROG, HoopR if Team.RABBIT
	hoop = hoop_f if team_id == 0 else hoop_r
