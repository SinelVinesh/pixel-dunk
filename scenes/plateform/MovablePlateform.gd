extends Path2D

@export var loop: bool = true
@export var speed: float = 2.0
@export var speed_scale: float = 1.0

@onready var path = $PathFollow2D
@onready var animation = $AnimationPlayer

func _ready():
	if not loop:
		animation.play("move")
		animation.speed_scale = speed_scale
		set_process(false)

func _process(delta):
	if path:
		path.progress += speed * speed_scale * (1.0 if loop else delta)
