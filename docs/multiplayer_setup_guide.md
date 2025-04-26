# Multiplayer System Setup Guide

This document explains how to set up and use the local multiplayer system for Pixel Dunk.

## 1. Setting up the Autoload

First, you need to add the MultiplayerManager as an autoload singleton:

1. Open the Godot Project Settings
2. Navigate to the "Autoload" tab
3. Add a new autoload with the following settings:
   - Path: `res://autoload/MultiplayerManager.tscn`
   - Name: `MultiplayerManager`
   - Enable the singleton by checking the "Enabled" box
4. Click "Add" to confirm and save your project settings

## 2. Input Map Setup

The MultiplayerManager will automatically set up the necessary input actions for all players when the game starts. Each player's inputs will be prefixed with `p1_`, `p2_`, etc.

For example:
- Player 1: `p1_move_left`, `p1_jump`, etc.
- Player 2: `p2_move_left`, `p2_jump`, etc.

The default control scheme is:
- All players can use controllers if enough are connected
- If controllers are limited, keyboard is used as a fallback

## 3. Testing Multiplayer

1. Open the `scenes/test/MultiplayerTest.tscn` scene
2. Connect controllers for your players (up to 4)
3. Run the scene
4. Click "Start Game" to begin the 2v2 match

## 4. Team Configuration

The multiplayer system is configured for 2v2 matches with 4 players:
- Team Blue: Players 1 and 3
- Team Red: Players 2 and 4

## 5. For Developers: Using the Multiplayer System

### Accessing the MultiplayerManager

You can access the MultiplayerManager from any script using:

```gdscript
var multiplayer_manager = get_node("/root/MultiplayerManager")
```

### Spawning Players

To spawn players in your own scenes:

1. Make sure your scene has spawn points (Marker2D nodes)
2. Configure the spawn points in the MultiplayerManager:

```gdscript
# Clear existing spawn points
multiplayer_manager.spawn_points.clear()

# Add your spawn points
for i in range(1, 5):
    var spawn_point = get_node_or_null("YourSpawnPointsParent/SpawnPoint" + str(i))
    if spawn_point:
        multiplayer_manager.spawn_points.append(get_path_to(spawn_point))

# Set the player scene to use
multiplayer_manager.player_scene = preload("res://entities/player/Player.tscn")

# Spawn the players
multiplayer_manager.spawn_players(self)
```

### Player Input System

Each player has an `input_prefix` property that is set to `p1_`, `p2_`, etc. This prefix is added to all input action names to handle multiple players.

For example:
- Instead of checking `Input.is_action_pressed("jump")`
- You check `Input.is_action_pressed(input_prefix + "jump")`

### Ball Passing Between Players

The ball system is designed to work with multiple players. When a player passes the ball, the system searches for the nearest teammate in the direction of passing.

Passing should be directed toward teammates (same team_id):
- Team Blue (team_id = 0): Players 1 and 3
- Team Red (team_id = 1): Players 2 and 4

Sample ball passing implementation:

```gdscript
# In your ball script or player script that handles passing
func pass_ball(from_player):
    # Get the MultiplayerManager
    var multiplayer_manager = get_node("/root/MultiplayerManager")
    var active_players = multiplayer_manager.active_players

    # Find the nearest teammate
    var nearest_teammate = null
    var shortest_distance = INF

    for player in active_players:
        # Skip the player who is passing
        if player == from_player:
            continue

        # Only pass to teammates (same team_id)
        if player.team_id == from_player.team_id:
            var distance = player.global_position.distance_to(from_player.global_position)

            # Check if in passing range
            if distance < from_player.pass_range and distance < shortest_distance:
                shortest_distance = distance
                nearest_teammate = player

    # Pass the ball to the nearest teammate if found
    if nearest_teammate:
        # Implementation details depend on your ball attachment/passing system
        detach_from_player(from_player)
        apply_pass_force_to(nearest_teammate.global_position)

        # Emit a signal for scoring/UI updates
        from_player.emit_signal("ball_passed", from_player, nearest_teammate.global_position, nearest_teammate)
```

## 6. Customizing Player Controls

If you want to modify the default controls:

1. Open the `MultiplayerManager.gd` script
2. Locate the `assign_keyboard_to_player` and `assign_controller_to_player` functions
3. Modify the input mappings as needed

## 7. Detecting Controllers

The system automatically detects connected controllers and assigns them to players based on availability.

To see connected controllers:
```gdscript
var connected_controllers = Input.get_connected_joypads()
print("Number of controllers: ", connected_controllers.size())
```

## 8. Troubleshooting

- **No controllers detected**: Make sure your controllers are connected before starting the game
- **Controller not working**: Try disconnecting and reconnecting the controller
- **Missing inputs**: Ensure the player's `input_prefix` is set correctly

## 9. Visual Player Identification

Each player has visual indicators to help differentiate them:

- **Team Color**: Blue for team 0 (players 1 & 3), Red for team 1 (players 2 & 4)
- **Player Number**: A number label above the player showing their player number (1-4)

When implementing your own player visuals, you can use the `_update_visual_indicators()` function in the Player script as a reference.
