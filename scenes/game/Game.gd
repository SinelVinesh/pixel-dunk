extends Node2D

# Holds reference to the player scene
@export var player_scene: PackedScene

# Configuration variables
var max_players: int = 4 # Fixed at 4 players for 2v2

@export_group("Score Sequence")
## Duration of celebration period before fade to black (in seconds)
@export var celebration_duration: float = 1.5

# Game state
var game_running: bool = false

# Multiplayer manager reference
var multiplayer_manager: Node

# Score manager reference
var score_manager: Node

# Dash indicators references
var dash_indicators = []

# Game ending factors
var slow_time: bool = false

# Called when the node enters the scene tree for the first time
func _ready():
	GameManager.time_over.connect(end_game)
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
	if slow_time and Engine.time_scale > 0.1:
		Engine.time_scale = lerp(Engine.time_scale, 0.05, delta * 7)
		if Engine.time_scale <= 0.1:
			GameManager.emit_game_ended()
			Engine.time_scale = 1
		

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
	# Reset Scores
	ScoreManager.reset_scores()
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
		multiplayer_manager.active_players[0].team_id = 0 # Blue team
		multiplayer_manager.active_players[0]._update_visual_indicators()
		multiplayer_manager.active_players[0].assign_hoop()
		multiplayer_manager.active_players[0].character_name = "Rabbit_01"
		multiplayer_manager.active_players[0].load_animated_sprite()
	if multiplayer_manager.active_players.size() > 1:
		multiplayer_manager.active_players[1].team_id = 1 # Red team
		multiplayer_manager.active_players[1]._update_visual_indicators()
		multiplayer_manager.active_players[1].assign_hoop()
		multiplayer_manager.active_players[1].character_name = "Frog_01"
		multiplayer_manager.active_players[1].load_animated_sprite()
	if multiplayer_manager.active_players.size() > 2:
		multiplayer_manager.active_players[2].team_id = 0 # Blue team
		multiplayer_manager.active_players[2]._update_visual_indicators()
		multiplayer_manager.active_players[2].assign_hoop()
		multiplayer_manager.active_players[2].character_name = "Rabbit_02"
		multiplayer_manager.active_players[2].load_animated_sprite()
	if multiplayer_manager.active_players.size() > 3:
		multiplayer_manager.active_players[3].team_id = 1 # Red team
		multiplayer_manager.active_players[3]._update_visual_indicators()
		multiplayer_manager.active_players[3].assign_hoop()
		multiplayer_manager.active_players[3].character_name = "Frog_02"
		multiplayer_manager.active_players[3].load_animated_sprite()


	# Create dash indicators for all players
	_create_dash_indicators()

	# Connect dash signals from all players
	_connect_player_signals()
	# Start the game
	game_running = true
	GameManager.start_game()
	
	# Connect to scoring events
	ScoreManager.scored_by_team.connect(_on_score_sequence_start)

# Handle scoring sequence when a team scores
func _on_score_sequence_start(team_scored: int) -> void:
	await play_score_sequence(team_scored)

# Main score sequence coroutine
func play_score_sequence(team_scored: int) -> void:
	
	# 1. Pause timer immediately
	GameManager.pause_timer()
	
	# 2. Freeze all players for 0.5s and prevent ball interaction
	_freeze_all_players(true)
	# _freeze_ball(true)
	
	# 3. Play crowd cheer sound
	_play_crowd_cheer()
	
	# 4. Show score effect (optional visual highlight) - TODO EN PARLER A VINESH
	# _show_score_effect(team_scored)
	
	# Wait for celebration period
	await get_tree().create_timer(0.5).timeout
	
	# 5. Fade to black to hide repositioning
	await _fade_to_black()
	
	# 6. Reposition players to spawn points
	_reposition_players()
	
	# 7. Give ball to defending team (team that got scored on)
	var defending_team = 1 - team_scored
	_give_ball_to_team(defending_team)
	
	# 8. Wait during black screen
	await get_tree().create_timer(celebration_duration).timeout
	
	# 9. Fade back from black
	await _fade_from_black()
	
	# 10. Play whistle sound
	_play_whistle()
	
	# 11. Unfreeze players and resume timer
	_freeze_all_players(false)
	# _freeze_ball(false)
	GameManager.resume_timer()
	
# Freeze/unfreeze all players
func _freeze_all_players(freeze: bool) -> void:
	for player in multiplayer_manager.active_players:
		if is_instance_valid(player):
			player.game_frozen = freeze
			if freeze:
				# Stop current movement
				player.velocity = Vector2.ZERO

# Freeze/unfreeze ball interaction
func _freeze_ball(freeze: bool) -> void:
	var ball = get_node_or_null("Ball")
	if ball:
		if freeze:
			ball.linear_velocity = Vector2.ZERO
			ball.gravity_scale = 0
		else:
			ball.gravity_scale = 1

# Play crowd cheer sound effect
func _play_crowd_cheer() -> void:
	# Create AudioStreamPlayer if it doesn't exist
	var crowd_sound = get_node_or_null("CrowdCheer")
	if not crowd_sound:
		crowd_sound = AudioStreamPlayer.new()
		crowd_sound.name = "CrowdCheer"
		add_child(crowd_sound)
		# Use existing hip-hop music as placeholder for crowd cheer
		crowd_sound.stream = load("res://assets/audio/Applause-crowd-cheering-cut.mp3")
		# crowd_sound.volume_db = -20.0 # Lower volume for effect
	
	# Play the sound
	if crowd_sound.stream:
		crowd_sound.play()
	else:
		print("Crowd cheer sound would play here")

# Show visual score effect
func _show_score_effect(team_scored: int) -> void:
	# Create a temporary label to show points gained
	var score_label = Label.new()
	score_label.text = "SCORE!"
	score_label.add_theme_font_size_override("font_size", 48)
	
	# Set color based on team
	if team_scored == 0:
		score_label.add_theme_color_override("font_color", Color.CYAN)
	else:
		score_label.add_theme_color_override("font_color", Color.RED)
	
	# Position in center of screen
	score_label.position = Vector2(get_viewport().size.x / 2 - 100, get_viewport().size.y / 2 - 50)
	add_child(score_label)
	
	# Animate and remove
	var tween = create_tween()
	tween.parallel().tween_property(score_label, "modulate:a", 0.0, 1.0)
	tween.parallel().tween_property(score_label, "scale", Vector2(1.5, 1.5), 1.0)
	await tween.finished
	score_label.queue_free()

# Fade to black
func _fade_to_black() -> void:
	# Get or create the overlay as a CanvasLayer to ensure it's on top
	var fade_canvas = get_node_or_null("FadeCanvas")
	if not fade_canvas:
		fade_canvas = CanvasLayer.new()
		fade_canvas.name = "FadeCanvas"
		fade_canvas.layer = 100 # High layer to be on top of everything
		add_child(fade_canvas)
		
		var fade_overlay = ColorRect.new()
		fade_overlay.name = "FadeOverlay"
		fade_overlay.color = Color.BLACK
		fade_overlay.modulate.a = 0.0
		fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fade_canvas.add_child(fade_overlay)
	
	var fade_overlay = fade_canvas.get_node("FadeOverlay")
	# Update size to cover entire viewport
	fade_overlay.size = get_viewport().size
	fade_overlay.position = Vector2.ZERO
	
	var tween = create_tween()
	tween.tween_property(fade_overlay, "modulate:a", 1.0, 0.5)
	await tween.finished

# Fade from black
func _fade_from_black() -> void:
	var fade_canvas = get_node_or_null("FadeCanvas")
	if fade_canvas:
		var fade_overlay = fade_canvas.get_node("FadeOverlay")
		var tween = create_tween()
		tween.tween_property(fade_overlay, "modulate:a", 0.0, 0.5)
		await tween.finished

# Reposition players to their spawn points
func _reposition_players() -> void:
	for i in range(multiplayer_manager.active_players.size()):
		var player = multiplayer_manager.active_players[i]
		if is_instance_valid(player) and i < multiplayer_manager.spawn_points.size():
			var spawn_node = get_node(multiplayer_manager.spawn_points[i])
			if spawn_node:
				player.global_position = spawn_node.global_position
				player.velocity = Vector2.ZERO

# Give ball to a specific team
func _give_ball_to_team(team_id: int) -> void:
	var ball = get_node_or_null("Ball")
	if not ball:
		return
	
	# Find first player of the defending team
	for player in multiplayer_manager.active_players:
		if is_instance_valid(player) and player.team_id == team_id:
			# Position ball near the player
			ball.global_position = player.global_position + Vector2(0, -30)
			ball.linear_velocity = Vector2.ZERO
			# Give ball to player
			player.pick_up_ball(ball)
			break

# Play whistle sound
func _play_whistle() -> void:
	# Create AudioStreamPlayer if it doesn't exist
	var whistle_sound = get_node_or_null("Whistle")
	if not whistle_sound:
		whistle_sound = AudioStreamPlayer.new()
		whistle_sound.name = "Whistle"
		add_child(whistle_sound)
		# Use existing buzzer sound as placeholder for whistle
		whistle_sound.stream = load("res://assets/audio/mixkit-basketball-buzzer-1647.wav")
		whistle_sound.volume_db = -10.0
	
	# Play the sound
	if whistle_sound.stream:
		whistle_sound.play()
	else:
		print("Whistle sound would play here")

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
		if player.team_id == 0: # Blue team
			dash_label.modulate = Color(0.3, 0.3, 1.0)
		else: # Red team
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

func end_game():
	$Buzzer.play()
	slow_time = true
