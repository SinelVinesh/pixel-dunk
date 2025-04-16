extends Node
# This script sets up the necessary input actions for the player to use in Pixel Dunk.
# It configures both keyboard and controller inputs for all game actions.
# Add this as an autoload script in your project settings or call it from your main game entry point.

func _ready():
	setup_input_actions()

# Sets up all input actions used in the game
# This includes movement controls and game actions (jump, dash, pass)
func setup_input_actions():
	# Clear existing input actions (if needed)
	# WARNING: This will remove ALL input actions, comment this out if you have other actions to keep
	# for action in InputMap.get_actions():
	#    InputMap.erase_action(action)

	# ---- MOVEMENT INPUTS ----

	# Left movement - Move player left
	if not InputMap.has_action("move_left"):
		InputMap.add_action("move_left")
		add_keyboard_event_to_action("move_left", KEY_Q) # AZERTY layout
		add_keyboard_event_to_action("move_left", KEY_A) # QWERTY alternative
		add_keyboard_event_to_action("move_left", KEY_LEFT) # Arrow keys
		# Controller - Left stick and D-pad
		add_joy_axis_event_to_action("move_left", JOY_AXIS_LEFT_X, -1.0)
		add_joy_button_event_to_action("move_left", JOY_BUTTON_DPAD_LEFT)

	# Right movement - Move player right
	if not InputMap.has_action("move_right"):
		InputMap.add_action("move_right")
		add_keyboard_event_to_action("move_right", KEY_D) # AZERTY layout
		add_keyboard_event_to_action("move_right", KEY_RIGHT) # Arrow keys
		# Controller - Left stick and D-pad
		add_joy_axis_event_to_action("move_right", JOY_AXIS_LEFT_X, 1.0)
		add_joy_button_event_to_action("move_right", JOY_BUTTON_DPAD_RIGHT)

	# Down movement - Move player down (for platforming and positioning)
	if not InputMap.has_action("move_down"):
		InputMap.add_action("move_down")
		add_keyboard_event_to_action("move_down", KEY_S) # AZERTY layout
		add_keyboard_event_to_action("move_down", KEY_DOWN) # Arrow keys
		# Controller - Left stick and D-pad
		add_joy_axis_event_to_action("move_down", JOY_AXIS_LEFT_Y, 1.0)
		add_joy_button_event_to_action("move_down", JOY_BUTTON_DPAD_DOWN)

	# Up movement - Used primarily for aiming passes/shots upward
	# Note: In a basketball game, vertical movement is important for positioning
	if not InputMap.has_action("move_up"):
		InputMap.add_action("move_up")
		add_keyboard_event_to_action("move_up", KEY_Z) # AZERTY layout
		add_keyboard_event_to_action("move_up", KEY_W) # QWERTY alternative
		add_keyboard_event_to_action("move_up", KEY_UP) # Arrow keys
		# Controller - Left stick and D-pad
		add_joy_axis_event_to_action("move_up", JOY_AXIS_LEFT_Y, -1.0)
		add_joy_button_event_to_action("move_up", JOY_BUTTON_DPAD_UP)

	# ---- ACTION INPUTS ----

	# Jump - Used for platforming and getting height advantage
	if not InputMap.has_action("jump"):
		InputMap.add_action("jump")
		add_keyboard_event_to_action("jump", KEY_SPACE) # Spacebar
		add_joy_button_event_to_action("jump", JOY_BUTTON_A) # Xbox A button

	# Dash - Quick burst of speed for dodging or traversal
	if not InputMap.has_action("dash"):
		InputMap.add_action("dash")
		add_keyboard_event_to_action("dash", KEY_SHIFT) # Shift key
		add_joy_trigger_event_to_action("dash", JOY_AXIS_TRIGGER_LEFT) # Xbox LT button

	# Pass - Pass the ball to a teammate
	if not InputMap.has_action("pass"):
		InputMap.add_action("pass")
		add_keyboard_event_to_action("pass", KEY_E) # E key
		add_joy_trigger_event_to_action("pass", JOY_AXIS_TRIGGER_RIGHT) # Xbox RT button

	print("Pixel Dunk input actions have been set up successfully.")

# Adds a keyboard event to the specified action
# Parameters:
#   action_name: Name of the input action
#   key_code: Keyboard key code constant (from @GlobalScope)
func add_keyboard_event_to_action(action_name: String, key_code: int):
	var event = InputEventKey.new()
	event.keycode = key_code
	InputMap.action_add_event(action_name, event)

# Adds a joystick button event to the specified action
# Parameters:
#   action_name: Name of the input action
#   button_index: Controller button index (from @GlobalScope JOY_BUTTON_*)
func add_joy_button_event_to_action(action_name: String, button_index: int):
	var event = InputEventJoypadButton.new()
	event.button_index = button_index
	InputMap.action_add_event(action_name, event)

# Adds a joystick axis event to the specified action
# Parameters:
#   action_name: Name of the input action
#   axis_index: Controller axis index (from @GlobalScope JOY_AXIS_*)
#   axis_value: Threshold value (-1.0 for negative, 1.0 for positive)
func add_joy_axis_event_to_action(action_name: String, axis_index: int, axis_value: float):
	var event = InputEventJoypadMotion.new()
	event.axis = axis_index
	event.axis_value = axis_value
	InputMap.action_add_event(action_name, event)

# Adds a trigger event (LT/RT) to the specified action
# Parameters:
#   action_name: Name of the input action
#   trigger_axis: Trigger axis index (JOY_AXIS_TRIGGER_LEFT or JOY_AXIS_TRIGGER_RIGHT)
func add_joy_trigger_event_to_action(action_name: String, trigger_axis: int):
	var event = InputEventJoypadMotion.new()
	event.axis = trigger_axis
	# Triggers in Godot use values from 0.0 (not pressed) to 1.0 (fully pressed)
	# Setting to 0.5 means half-pressed will activate the action
	event.axis_value = 0.5
	InputMap.action_add_event(action_name, event)
