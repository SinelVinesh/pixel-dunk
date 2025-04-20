extends Node2D

# This script is for testing the Player functionality

@onready var player = $Player
@onready var dash_counter_label = $UI/DashCounterLabel
@onready var state_label = $UI/StateLabel
@onready var velocity_label = $UI/VelocityLabel
@onready var dash_recharge_label = $UI/DashRechargeLabel
@onready var input_setup = $InputSetup
@onready var ball = $Ball

func _ready():
	# Connect player signals
	player.dash_used.connect(_on_player_dash_used)
	player.dash_recharged.connect(_on_player_dash_recharged)

	# Update UI
	_update_ui()

func _process(_delta):
	_update_ui()

func _update_ui():
	# Update dash counter
	dash_counter_label.text = "Dash: %d/%d" % [player.dash_count, player.max_dash_count]

	# Update state
	var state_text = "State: "
	match player.current_state:
		player.PlayerState.FREE:
			state_text += "Free"
		player.PlayerState.BALL_POSSESSION:
			state_text += "Ball Possession"
		player.PlayerState.DASHING:
			state_text += "Dashing"
		player.PlayerState.JUMPING:
			state_text += "Jumping"
		player.PlayerState.DOUBLE_JUMPING:
			state_text += "Double Jumping"

	state_label.text = state_text

	# Update velocity
	velocity_label.text = "Velocity: %.1f, %.1f" % [player.velocity.x, player.velocity.y]

	# Update dash recharge text
	update_dash_recharge_ui()

# Update the dash recharge UI (text label only)
func update_dash_recharge_ui():
	# Get timer info
	var timer = player.dash_cooldown_timer
	var time_left = timer.time_left
	var is_paused = timer.is_paused()

	# Only show recharge if player is missing dashes
	if player.dash_count < player.max_dash_count:
		dash_recharge_label.visible = true

		if time_left > 0:
			# Format time remaining (1 decimal place)
			var time_text = "%.1fs" % time_left

			# Update label
			if is_paused:
				dash_recharge_label.text = "Dash Recharge: PAUSED (%s)" % time_text
			else:
				dash_recharge_label.text = "Dash Recharge: %s" % time_text
		else:
			# If timer isn't running but should be (waiting to start)
			dash_recharge_label.text = "Dash Recharge: Waiting..."
	else:
		# Hide elements if player has full dash count
		dash_recharge_label.visible = false

func _on_player_dash_used(_player):
	# Visual feedback when dash is used (could add screen shake, etc.)
	pass

func _on_player_dash_recharged(_player):
	# Visual feedback when dash recharges
	pass

func _on_give_ball_button_pressed():
	# Test function to simulate player picking up the ball
	player.pick_up_ball(get_node("Ball"))

	# Clear focus from the button to prevent space bar from re-triggering it
	release_button_focus()

func _on_reset_button_pressed():
	# Reset player position and state
	player.position = Vector2(400, 300)
	player.velocity = Vector2.ZERO
	player.current_state = player.PlayerState.JUMPING
	player.has_ball = false
	player.reset_dash_count()

	# Reset ball position and state

	## Old code
	#ball._handle_freeze(false, player)
	ball.position = Vector2(578, 262)
	ball.set_contact_monitor(true) # Enable contact monitor
	ball.set_collision_layer_value(5, true) # Set enabled collision layer
	# Set monitoring and monitorable for ball area 2d
	ball.ball_area.set_monitoring(true)
	ball.ball_area.set_monitorable(true)
	ball.linear_velocity = Vector2.ZERO # Stop current ball movement

	# Clear focus from the button to prevent space bar from re-triggering it
	release_button_focus()

func _on_controls_button_pressed():
	# Show control info
	$UI/ControlsPanel.visible = !$UI/ControlsPanel.visible

	# Clear focus from the button to prevent space bar from re-triggering it
	release_button_focus()

# Helper function to release focus from all buttons
func release_button_focus():
	# Clear focus on all buttons
	var buttons = get_tree().get_nodes_in_group("buttons")
	if buttons.size() > 0:
		# If buttons are in a group, clear focus from all of them
		for button in buttons:
			button.release_focus()
	else:
		# Otherwise clear focus from specific buttons
		$UI/GiveBallButton.release_focus()
		$UI/ResetButton.release_focus()
		$UI/ControlsButton.release_focus()
		if $UI/ControlsPanel.visible:
			$UI/ControlsPanel/CloseButton.release_focus()

	# Set focus mode to none for all buttons (optional, prevents keyboard navigation)
	# Uncomment these lines if you want to completely disable keyboard focus
	# $UI/GiveBallButton.focus_mode = Control.FOCUS_NONE
	# $UI/ResetButton.focus_mode = Control.FOCUS_NONE
	# $UI/ControlsButton.focus_mode = Control.FOCUS_NONE
	# $UI/ControlsPanel/CloseButton.focus_mode = Control.FOCUS_NONE
