extends RigidBody2D
class_name Ball

# Ball properties
@onready var ball_rotation: float = rotation #Store ball default rotation

@onready var ball_radius: float = $CollisionShape2D.shape.radius


#On ball spawn
func _ready() -> void:
	pass
	
	#Initially launch ball to the right
	#linear_velocity = Vector2(300, -0) #For test

#Called every frame
func _process(delta: float) -> void:
	
	#Rotate ball based on movement
	angular_velocity = linear_velocity.x / ball_radius
	
	pass
