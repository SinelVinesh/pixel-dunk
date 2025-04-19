extends CharacterBody2D
class_name Player

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
@export_range(0.4, 1.0, 0.05) var holding_ball_gravity_multiplier: float = 0.6
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
## Maximum distance for passing the ball to teammates
@export var pass_range: float = 400.0
## Player team (0 = blue team, 1 = red team)
@export var team_id: int = 0

# State machine - Defines the possible states of the player
enum PlayerState {
	FREE,            # Normal movement without the ball
	BALL_POSSESSION, # Holding the ball (restricted movement)
	DASHING,         # Currently performing a dash
	JUMPING,         # In the air after jumping (first jump)
	DOUBLE_JUMPING   # In the air after a second jump
}
var current_state: int = PlayerState.JUMPING  # Current state of the player

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

# Node references - Links to child nodes in the scene
@onready var sprite: Sprite2D = $Sprite2D  # Player's visual sprite
@onready var ground_check: RayCast2D = $GroundCheck  # Ray for detecting ground
@onready var dash_particles: GPUParticles2D = $DashParticles  # Particle effect for dashing
@onready var ball_position: Marker2D = $BallPosition  # Position where ball appears when held
@onready var dash_cooldown_timer: Timer = $DashCooldownTimer  # Timer for recharging dashes
@onready var animation_player: AnimationPlayer = $AnimationPlayer  # Controls animations

# Sound effect nodes
@onready var jump_sound: AudioStreamPlayer = $JumpSound  # Sound when jumping
@onready var dash_sound: AudioStreamPlayer = $DashSound  # Sound when dashing
@onready var pass_sound: AudioStreamPlayer = $PassSound  # Sound when passing

# Input state variables
var move_direction: Vector2 = Vector2.ZERO  # Direction player is trying to move
var looking_direction: Vector2 = Vector2.RIGHT  # Direction player is facing
var dash_pressed: bool = false  # Whether dash button was just pressed
var jump_pressed: bool = false  # Whether jump button was just pressed
var pass_pressed: bool = false  # Whether pass button was just pressed

# Signals - Events that other nodes can connect to
signal ball_passed(source_player, target_position, target_player)  # Emitted when passing the ball
signal dash_used(player)  # Emitted when a dash is used
signal dash_recharged(player)  # Emitted when a dash is recharged

# Called when the node is added to the scene
func _ready() -> void:
	# Initialize dash particles (turned off by default)
	dash_particles.emitting = false

	# Reset the dash count to maximum
	reset_dash_count()

	# Configure dash cooldown timer
	dash_cooldown_timer.wait_time = dash_recharge_time

	# Initialize ground tracking
	was_on_ground = false
	can_coyote_jump = false
	coyote_timer = 0.0

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

	# Manage dash cooldown timer - pause when having the ball
	manage_dash_cooldown()

	# Apply movement and handle collisions
	move_and_slide()

	# Update animations based on state and movement
	update_animations()

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
	var raw_move = Input.get_vector("move_left", "move_right", "move_up", "move_down").normalized()

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

	# Update action button states
	dash_pressed = Input.is_action_just_pressed("dash")
	jump_pressed = Input.is_action_just_pressed("jump")
	pass_pressed = Input.is_action_just_pressed("pass")

# Apply gravity consistently based on vertical velocity
func apply_gravity() -> void:
	var gravity_modifier = 1.0

	if velocity.y > 0:
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
		# For horizontal movement
		velocity.x = lerp(velocity.x, move_direction.x * move_speed, acceleration * delta)

		# Remove ability to control vertical movement in the air
		# This prevents "flying" in FREE state
	else:
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

	# Check for ball pickup
	var ball = check_for_ball()
	if ball:
		pick_up_ball(ball)

# Perform a jump (shared logic for regular and coyote jumps)
func perform_jump() -> void:
	velocity.y = -jump_force
	jump_sound.play()
	current_state = PlayerState.JUMPING
	can_double_jump = double_jump_enabled
	can_coyote_jump = false  # Use up coyote jump

# Handle movement when holding the ball (BALL_POSSESSION state)
func handle_ball_possession(delta: float) -> void:
	# Movement is restricted to dashing only when having the ball
	# Stop all horizontal movement with high friction
	velocity.x = 0.0

	# Only apply vertical friction when in the air
	if !on_ground:
		velocity.y = velocity.y * friction * 1.2

	# Apply gravity when in the air
	if !on_ground:
		apply_gravity()

	# Handle dashing if player has dash charges available
	if dash_pressed and dash_count > 0:
		start_dash()

	# Handle passing the ball to teammates
	if pass_pressed:
		pass_ball()

# Handle behavior during a dash (DASHING state)
func handle_dash(delta: float) -> void:
	# Countdown dash timer
	dash_timer -= delta

	if dash_timer <= 0:
		# End dash when timer expires
		in_dash = false
		dash_particles.emitting = false

		# Immediately stop all momentum when dash ends
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

# Handle behavior during a jump (JUMPING state)
func handle_jump(delta: float) -> void:
	# Apply horizontal movement with reduced control in air
	if move_direction.length() > 0.1:
		velocity.x = lerp(velocity.x, move_direction.x * move_speed, acceleration * delta * 0.8)
	else:
		# Apply air friction (slightly reduced)
		velocity.x = velocity.x * (friction + 0.05)

	# Apply gravity
	apply_gravity()

	# Handle double jump if available
	if jump_pressed and can_double_jump and double_jump_enabled:
		velocity.y = -jump_force * double_jump_force_multiplier  # Use configurable multiplier
		jump_sound.play()
		current_state = PlayerState.DOUBLE_JUMPING
		can_double_jump = false

	# Handle dash in air
	if dash_pressed and dash_count > 0:
		start_dash()

	# Transition back to free state when landing
	if on_ground:
		current_state = PlayerState.FREE

# Handle behavior during a double jump (DOUBLE_JUMPING state)
func handle_double_jump(delta: float) -> void:
	# Similar to regular jump, but with even less control using the configurable multiplier
	if move_direction.length() > 0.1:
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
		current_state = PlayerState.FREE

# Start a dash - used by multiple states
func start_dash() -> void:
	# For dashing, we want to use the raw input direction to allow diagonal dashes
	var dash_input = Input.get_vector("move_left", "move_right", "move_up", "move_down").normalized()

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

# TODO Volahary - Handle picking up the ball
func pick_up_ball(ball) -> void:
	has_ball = true
	current_state = PlayerState.BALL_POSSESSION

	# Reset velocity when picking up the ball to prevent momentum carrying over
	velocity = Vector2.ZERO

	# Note: Logic to attach ball to the player would go here
	# ball.player_picked_up(self)

# TODO Volahary - Pass the ball to a teammate
func pass_ball() -> void:
	if not has_ball:
		return

	# Find nearest teammate
	var teammate = find_nearest_teammate()
	has_ball = false
	current_state = PlayerState.JUMPING

	# Play pass sound
	pass_sound.play()

	# Emit signal for the ball system to handle
	if teammate:
		emit_signal("ball_passed", self, teammate.global_position, teammate)

# TODO Volahary - Check for ball in pickup range
func check_for_ball():
	# This would be implemented with area detection
	# For now, return null as placeholder
	return null

# TODO Abdoul - Find the nearest teammate for passing
func find_nearest_teammate():
	# This would find the nearest teammate player
	# For now, return null as placeholder
	return null

# TODO Steeven - Find the position of the opponent's basket
func find_basket_position():
	# This would find the opponent's basket position
	# For now, return a placeholder position
	return Vector2(1000, 300)  # Example basket position

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
