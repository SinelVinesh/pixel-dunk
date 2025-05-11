extends Node2D

# Holds reference to the player scene
@export var player_scene: PackedScene

# Configuration variables
var max_players: int = 4  # Fixed at 4 players for 2v2


# Game state
var game_running: bool = false

# Multiplayer manager reference
var multiplayer_manager: Node

# Score manager reference
var score_manager: Node

# Dash indicators references
var dash_indicators = []

# Called when the node enters the scene tree for the first time
func _ready():
	# Get the MultiplayerManager singleton
	multiplayer_manager = get_node("/root/MultiplayerManager")
	if not multiplayer_manager:
		push_error("MultiplayerManager autoload not found!")
		return


	# Configure multiplayer manager with 4 players for 2v2
	multiplayer_manager.max_players = max_players
	multiplayer_manager.player_scene = player_scene

	# Get spawn points
	_update_spawn_points()

	# Start the game automatically
	_start_game()


# Process function for gameplay
func _process(delta):

	# Update dash indicators
	if game_running:
		_update_dash_indicators()

# Reset the scene
func _on_reset_button_pressed():
	_reset_game()

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
		multiplayer_manager.active_players[0].assign_hoop()
	if multiplayer_manager.active_players.size() > 1:
		multiplayer_manager.active_players[1].team_id = 1  # Red team
		multiplayer_manager.active_players[1]._update_visual_indicators()
		multiplayer_manager.active_players[1].assign_hoop()
	if multiplayer_manager.active_players.size() > 2:
		multiplayer_manager.active_players[2].team_id = 0  # Blue team
		multiplayer_manager.active_players[2]._update_visual_indicators()
		multiplayer_manager.active_players[2].assign_hoop()
	if multiplayer_manager.active_players.size() > 3:
		multiplayer_manager.active_players[3].team_id = 1  # Red team
		multiplayer_manager.active_players[3]._update_visual_indicators()
		multiplayer_manager.active_players[3].assign_hoop()


	# Create dash indicators for all players
	_create_dash_indicators()

	# Connect dash signals from all players
	_connect_player_signals()

	# Start the game
	game_running = true

# Create dash indicators for each player
func _create_dash_indicators():
	# Clean up any existing indicators first
	_clear_dash_indicators()

	# Create a panel for dash indicators if it doesn't exist
	var dash_panel = $BackUI.get_node_or_null("DashPanel")
	if not dash_panel:
		dash_panel = Panel.new()
		dash_panel.name = "DashPanel"
		dash_panel.size = Vector2(200, 120)
		dash_panel.position = Vector2(15, 160)

		var style = StyleBoxFlat.new()
		style.bg_color = Color(0, 0, 0, 0.4)
		style.corner_radius_top_left = 5
		style.corner_radius_top_right = 5
		style.corner_radius_bottom_right = 5
		style.corner_radius_bottom_left = 5
		dash_panel.add_theme_stylebox_override("panel", style)

		$BackUI.add_child(dash_panel)

	# Add title label
	var title_label = dash_panel.get_node_or_null("TitleLabel")
	if not title_label:
		title_label = Label.new()
		title_label.name = "TitleLabel"
		title_label.position = Vector2(15, 10)
		title_label.text = "Player Dash Status"
		dash_panel.add_child(title_label)

	# Create indicators for each player
	for i in range(multiplayer_manager.active_players.size()):
		var player = multiplayer_manager.active_players[i]

		# Create label for this player
		var dash_label = Label.new()
		dash_label.name = "Player" + str(player.player_id) + "DashLabel"
		dash_label.position = Vector2(15, 40 + (i * 20))

		# Set color based on team
		if player.team_id == 0:  # Blue team
			dash_label.modulate = Color(0.3, 0.3, 1.0)
		else:  # Red team
			dash_label.modulate = Color(1.0, 0.3, 0.3)

		dash_label.text = "Player " + str(player.player_id) + ": 0/0"
		dash_panel.add_child(dash_label)
		dash_indicators.append(dash_label)

# Connect to player signals for dash events
func _connect_player_signals():
	for player in multiplayer_manager.active_players:
		player.dash_used.connect(_on_player_dash_used)
		player.dash_recharged.connect(_on_player_dash_recharged)

# Update dash indicators based on current player states
func _update_dash_indicators():
	for i in range(min(dash_indicators.size(), multiplayer_manager.active_players.size())):
		var player = multiplayer_manager.active_players[i]
		var indicator = dash_indicators[i]

		if is_instance_valid(player) and is_instance_valid(indicator):
			var recharge_info = ""
			if player.dash_count < player.max_dash_count and player.dash_cooldown_timer.time_left > 0:
				recharge_info = " (%.1fs)" % player.dash_cooldown_timer.time_left

			indicator.text = "Player " + str(player.player_id) + ": " + str(player.dash_count) + "/" + str(player.max_dash_count) + recharge_info

# Handle player dash used event
func _on_player_dash_used(player):
	_update_dash_indicators()

# Handle player dash recharged event
func _on_player_dash_recharged(player):
	_update_dash_indicators()

# Clear dash indicators
func _clear_dash_indicators():
	for indicator in dash_indicators:
		if is_instance_valid(indicator):
			indicator.queue_free()
	dash_indicators.clear()

	var dash_panel = $BackUI.get_node_or_null("DashPanel")
	if dash_panel:
		for child in dash_panel.get_children():
			if child.name != "TitleLabel":
				child.queue_free()

# Reset the game state
func _reset_game():
	# Stop the game
	game_running = false

	# Clear existing players
	_clear_existing_players()

	# Clear dash indicators
	_clear_dash_indicators()

	# Reset scores
	if score_manager:
		score_manager.reset_scores()

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
