extends Node

# MultiplayerManager
# Handles configuration and management of local multiplayer in Pixel Dunk

# Number of players and their spawn points
@export var max_players: int = 4  # Default to 4 players for 2v2 mode
@export var spawn_points: Array[NodePath] = []

# Player scene to instance for each player
@export var player_scene: PackedScene

# Track active players
var active_players: Array[Node] = []
var player_devices: Dictionary = {} # Maps player index to input device index

# Input device constants
const DEVICE_KEYBOARD = -1
const FIRST_CONTROLLER = 0

# Called when the node enters the scene tree for the first time
func _ready():
	# Setup input actions if they haven't been set up yet
	setup_input_map()

	# Connect to joypad connection signals
	Input.joy_connection_changed.connect(_on_joy_connection_changed)

	# When running the MultiplayerManager scene directly, detect connected controllers
	if get_tree().current_scene == self:
		print_controller_info()

# Setup the input map actions for all players
func setup_input_map():
	# Define all the actions we'll use
	var actions = [
		"move_left", "move_right", "move_up", "move_down",
		"jump", "dash", "pass"
	]

	# Create player-specific actions
	for player_idx in range(1, max_players + 1):
		for action in actions:
			var player_action = "p{0}_{1}".format([player_idx, action])

			# Only add if it doesn't exist yet
			if not InputMap.has_action(player_action):
				InputMap.add_action(player_action)

# Configure input for all players based on available devices
func configure_player_inputs():
	var connected_controllers = get_connected_controllers()

	# If we have enough controllers for all players, assign controllers to everyone
	if connected_controllers.size() >= max_players:
		for player_idx in range(1, max_players + 1):
			# Player index is 1-based, but array is 0-based
			assign_controller_to_player(player_idx, connected_controllers[player_idx - 1])
	else:
		# Not enough controllers, so Player 1 gets keyboard and others get controllers
		assign_keyboard_to_player(1)

		# Assign controllers to remaining players if available
		var controller_index = 0
		for player_idx in range(2, max_players + 1):
			if controller_index < connected_controllers.size():
				assign_controller_to_player(player_idx, connected_controllers[controller_index])
				controller_index += 1

# Print information about connected controllers
func print_controller_info():
	var connected_joypads = Input.get_connected_joypads()
	print("Connected controllers: ", connected_joypads.size())

	for joypad_id in connected_joypads:
		var joypad_name = Input.get_joy_name(joypad_id)
		print("Controller #%d: %s" % [joypad_id, joypad_name])

# Get an array of connected controller device IDs
func get_connected_controllers() -> Array:
	return Input.get_connected_joypads()

# Assign keyboard input to a specific player
func assign_keyboard_to_player(player_idx: int):
	var player_prefix = "p{0}_".format([player_idx])

	# Store the device assignment
	player_devices[player_idx] = DEVICE_KEYBOARD

	# Movement - Keyboard (ZQSD/WASD + arrows)
	# Left
	add_keyboard_event(player_prefix + "move_left", KEY_Q) # AZERTY
	add_keyboard_event(player_prefix + "move_left", KEY_A) # QWERTY
	add_keyboard_event(player_prefix + "move_left", KEY_LEFT)

	# Right
	add_keyboard_event(player_prefix + "move_right", KEY_D)
	add_keyboard_event(player_prefix + "move_right", KEY_RIGHT)

	# Up
	add_keyboard_event(player_prefix + "move_up", KEY_Z) # AZERTY
	add_keyboard_event(player_prefix + "move_up", KEY_W) # QWERTY
	add_keyboard_event(player_prefix + "move_up", KEY_UP)

	# Down
	add_keyboard_event(player_prefix + "move_down", KEY_S)
	add_keyboard_event(player_prefix + "move_down", KEY_DOWN)

	# Actions
	add_keyboard_event(player_prefix + "jump", KEY_SPACE)
	add_keyboard_event(player_prefix + "dash", KEY_SHIFT)
	add_keyboard_event(player_prefix + "pass", KEY_E)

	print("Keyboard assigned to Player ", player_idx)

# Assign a specific controller to a specific player
func assign_controller_to_player(player_idx: int, device_idx: int):
	var player_prefix = "p{0}_".format([player_idx])

	# Store the device assignment
	player_devices[player_idx] = device_idx

	# Movement - Left stick and D-pad
	add_joy_axis_event(player_prefix + "move_left", device_idx, JOY_AXIS_LEFT_X, -1.0)
	add_joy_button_event(player_prefix + "move_left", device_idx, JOY_BUTTON_DPAD_LEFT)

	add_joy_axis_event(player_prefix + "move_right", device_idx, JOY_AXIS_LEFT_X, 1.0)
	add_joy_button_event(player_prefix + "move_right", device_idx, JOY_BUTTON_DPAD_RIGHT)

	add_joy_axis_event(player_prefix + "move_up", device_idx, JOY_AXIS_LEFT_Y, -1.0)
	add_joy_button_event(player_prefix + "move_up", device_idx, JOY_BUTTON_DPAD_UP)

	add_joy_axis_event(player_prefix + "move_down", device_idx, JOY_AXIS_LEFT_Y, 1.0)
	add_joy_button_event(player_prefix + "move_down", device_idx, JOY_BUTTON_DPAD_DOWN)

	# Actions - Face buttons and triggers
	add_joy_button_event(player_prefix + "jump", device_idx, JOY_BUTTON_A)
	add_joy_trigger_event(player_prefix + "dash", device_idx, JOY_AXIS_TRIGGER_LEFT)
	add_joy_trigger_event(player_prefix + "pass", device_idx, JOY_AXIS_TRIGGER_RIGHT)

	print("Controller ", device_idx, " assigned to Player ", player_idx)

# Spawn players at designated spawn points
func spawn_players(current_scene: Node):
	if player_scene == null:
		push_error("Player scene not assigned to MultiplayerManager")
		return

	configure_player_inputs()

	# Clear any previously spawned players
	for player in active_players:
		if is_instance_valid(player):
			player.queue_free()
	active_players.clear()

	# Spawn new players
	for player_idx in range(1, max_players + 1):
		# Only spawn if there's a valid device assigned
		if player_devices.has(player_idx):
			var spawn_position = Vector2.ZERO

			# Check if we have a spawn point for this player
			if player_idx <= spawn_points.size() and not spawn_points[player_idx-1].is_empty():
				var spawn_node = current_scene.get_node(spawn_points[player_idx-1])
				if spawn_node:
					spawn_position = spawn_node.global_position

			# Create player instance
			var player_instance = player_scene.instantiate()
			current_scene.add_child(player_instance)
			player_instance.global_position = spawn_position

			# Configure the player's input prefix
			player_instance.input_prefix = "p{0}_".format([player_idx])

			# Set player ID for identification
			if player_instance.has_method("set_player_id"):
				player_instance.set_player_id(player_idx)
				# Update visual indicators for color and id indicator
				player_instance._update_visual_indicators()

			active_players.append(player_instance)

	print("Spawned ", active_players.size(), " players")

# Add a keyboard event to the specified action
func add_keyboard_event(action_name: String, key_code: int):
	var event = InputEventKey.new()
	event.keycode = key_code
	InputMap.action_add_event(action_name, event)

# Add a joystick button event to the specified action
func add_joy_button_event(action_name: String, device_idx: int, button_index: int):
	var event = InputEventJoypadButton.new()
	event.device = device_idx
	event.button_index = button_index
	InputMap.action_add_event(action_name, event)

# Add a joystick axis event to the specified action
func add_joy_axis_event(action_name: String, device_idx: int, axis_index: int, axis_value: float):
	var event = InputEventJoypadMotion.new()
	event.device = device_idx
	event.axis = axis_index
	event.axis_value = axis_value
	InputMap.action_add_event(action_name, event)

# Add a trigger event (LT/RT) to the specified action
func add_joy_trigger_event(action_name: String, device_idx: int, trigger_axis: int):
	var event = InputEventJoypadMotion.new()
	event.device = device_idx
	event.axis = trigger_axis
	# Triggers in Godot use values from 0.0 (not pressed) to 1.0 (fully pressed)
	# Setting to 0.5 means half-pressed will activate the action
	event.axis_value = 0.5
	InputMap.action_add_event(action_name, event)

# Called every frame
func _process(delta):
	# Monitor for controller connection/disconnection
	if Input.is_joy_known(0):
		pass # Can implement dynamic controller reconnection handling here if needed

# Handle controller connected event
func _on_joy_connection_changed(device_idx: int, connected: bool):
	if connected:
		print("Controller connected: ", device_idx, " - ", Input.get_joy_name(device_idx))
	else:
		print("Controller disconnected: ", device_idx)

	# Reconfigure player inputs when controllers change
	configure_player_inputs()
