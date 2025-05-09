extends TextureRect  
class_name TextureRectAnimated  

@export var spriteHeight: int  
@export var spriteWidth: int  

@export var loop: bool = false     

@export var animating: bool = true  
@export var speed: int = 24 #fps
var delay: float = 0.0

var currentSprite: int = 0    

func _ready():
	delay = 1.0 / speed

func _process(delta: float):      
	#Stop here if the animation is not supposed to be running.
	if not animating:   
		return  
	delay -= delta
	if delay > 0:
		return
	#Set the new region of the sprite sheet to show
	texture.region = Rect2(spriteWidth * currentSprite, 0, spriteWidth, spriteHeight)  

	#Advance the counter
	currentSprite += 1
	  
	#Return to 0 if it already reached the end of the sheet
	var totalSprites: int = texture.atlas.get_width() / spriteWidth - 1
	if currentSprite > totalSprites:  
		currentSprite = 0        
		
		#If not looping, stop here.
		if not loop:  
			animating = false
	delay = 1.0 / speed


func start_animation():  
	currentSprite = 0
	animating = true
