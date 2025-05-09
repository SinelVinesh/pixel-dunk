extends Button

@onready var control = self


var scale_factor := 1.2 # Facteur d'agrandissement
var tween_duration := 0.2   # Durée de l'animation
var initial_scale = Vector2(1.0, 1.0)


func _ready() -> void:
	initial_scale = scale


func _on_button_mouse_entered() -> void:
	pass # Replace with function body.
		# Animation avec Tween (scale agrandi)
	var tween = create_tween()  # Crée un Tweener dynamiquement
	tween.tween_property(self, "scale", initial_scale * scale_factor, tween_duration) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _on_button_mouse_exited() -> void:
	pass # Replace with function body.
		# Animation avec Tween (retour à la taille normale)
	var tween = create_tween()  # Crée un Tweener pour l'effet inverse
	tween.tween_property(self, "scale", initial_scale, tween_duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
