extends CPUParticles2D

#Explicit content (you degenerate)
func _spawn_particle():
	pass
	set_emitting(true)

#Destroy when finished emitting
func _on_finished() -> void:
	pass
	queue_free()
