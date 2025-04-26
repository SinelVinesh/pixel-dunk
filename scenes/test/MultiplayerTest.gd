extends Node2D

# Holds reference to the player scene
@export var player_scene: PackedScene

# Configuration variables
var max_players: int = 4  # Fixed at 4 players for 2v2

# References to UI elements
@onready var controllers_label: Label = $UI/ConfigPanel/ControllersLabel
@onready var game_status_label: Label = $UI/GameStatusLabel
@onready var controls_panel: Panel = $UI/ControlsPanel
@onready var controls_button: Button = $UI/ControlsButton
@onready var close_button: Button = $UI/ControlsPanel/CloseButton
@onready var reset_button: Button = $UI/ConfigPanel/ResetButton

# Game state
var game_running: bool = false

# Multiplayer manager reference
var multiplayer_manager: Node

# Called when the node enters the scene tree for the first time
func _ready():
	# Get the MultiplayerManager singleton
	multiplayer_manager = get_node("/root/MultiplayerManager")
	if not multiplayer_manager:
		push_error("MultiplayerManager autoload not found!")
		return

	# Connect button signals
	controls_button.pressed.connect(_on_controls_button_pressed)
	close_button.pressed.connect(_on_close_button_pressed)
	reset_button.pressed.connect(_on_reset_button_pressed)

	# Update controller info
	_update_controller_info()

	# Configure multiplayer manager with 4 players for 2v2
	multiplayer_manager.max_players = max_players
	multiplayer_manager.player_scene = player_scene

	# Get spawn points
	_update_spawn_points()

	# Clear focus from all UI elements at startup
	_clear_all_focus()

	# Start the game automatically
	_start_game()

# Process function for gameplay
func _process(delta):
	# We'll periodically update controller info
	_update_controller_info()

# Show controls panel
func _on_controls_button_pressed():
	controls_panel.visible = true
	controls_button.release_focus()

# Hide controls panel
func _on_close_button_pressed():
	controls_panel.visible = false
	close_button.release_focus()

# Reset the scene
func _on_reset_button_pressed():
	_reset_game()

# Get latest information about connected controllers
func _update_controller_info():
	var connected_controllers = Input.get_connected_joypads()
	controllers_label.text = "Controllers: %d Connected" % connected_controllers.size()

# Update the spawn points in the multiplayer manager
func _update_spawn_points():
	multiplayer_manager.spawn_points.clear()

	# Add paths to all spawn points
	for i in range(1, 5):
		var spawn_point = get_node_or_null("SpawnPoints/SpawnPoint" + str(i))
		if spawn_point:
			multiplayer_manager.spawn_points.append(get_path_to(spawn_point))

# Start or restart the game
func _start_game():
	# Clear any existing players
	_clear_existing_players()

	# Update multiplayer manager configuration
	multiplayer_manager.max_players = max_players
	_update_spawn_points()

	# Spawn players
	multiplayer_manager.spawn_players(self)

	# Set player teams for 2v2 mode
	# Players 1&3 vs Players 2&4
	if multiplayer_manager.active_players.size() > 0:
		multiplayer_manager.active_players[0].team_id = 0  # Blue team
		multiplayer_manager.active_players[0]._update_visual_indicators()
	if multiplayer_manager.active_players.size() > 1:
		multiplayer_manager.active_players[1].team_id = 1  # Red team
		multiplayer_manager.active_players[1]._update_visual_indicators()
	if multiplayer_manager.active_players.size() > 2:
		multiplayer_manager.active_players[2].team_id = 0  # Blue team
		multiplayer_manager.active_players[2]._update_visual_indicators()
	if multiplayer_manager.active_players.size() > 3:
		multiplayer_manager.active_players[3].team_id = 1  # Red team
		multiplayer_manager.active_players[3]._update_visual_indicators()

	# Update player count display
	game_status_label.text = "Players: %d" % multiplayer_manager.active_players.size()

	# Start the game
	game_running = true

# Reset the game state
func _reset_game():
	# Stop the game
	game_running = false

	# Clear existing players
	_clear_existing_players()

	# Update player count display
	game_status_label.text = "Players: 0"

	# Release focus from the button
	reset_button.release_focus()

	# Reset the ball
	var ball = get_node_or_null("Ball")
	if ball:
		ball.global_position = Vector2(576, 214)
		if ball.has_method("reset"):
			ball.reset()

	# Restart the game
	_start_game()

# Clear any existing player instances
func _clear_existing_players():
	for player in multiplayer_manager.active_players:
		if is_instance_valid(player):
			player.queue_free()
	multiplayer_manager.active_players.clear()

# Clears focus from all UI buttons in the scene
func _clear_all_focus():
	reset_button.release_focus()
	controls_button.release_focus()
	close_button.release_focus()

# Called when an input event occurs
func _unhandled_input(event):
	# Clear focus when Escape is pressed
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			_clear_all_focus()
			# Also close controls panel if open
			if controls_panel.visible:
				controls_panel.visible = false
