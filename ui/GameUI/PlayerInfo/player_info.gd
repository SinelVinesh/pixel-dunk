extends Control

@export
var player_card_texture: Texture2D

func _ready() -> void:
	$TextureRect.texture = player_card_texture
