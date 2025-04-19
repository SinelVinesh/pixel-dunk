extends Sprite2D

# This script generates a simple placeholder sprite for the player
# It will be replaced with proper art later

func _ready():
	# Create a simple colored rectangle as placeholder
	var image = Image.create(32, 48, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.2, 0.4, 0.8, 1.0))

	# Add some details to make it more recognizable
	for y in range(8, 16):
		for x in range(8, 24):
			if y == 8 or y == 15 or x == 8 or x == 23:
				# Draw the face outline
				image.set_pixel(x, y, Color(0.1, 0.1, 0.1, 1.0))
			elif (x == 12 and y == 12) or (x == 20 and y == 12):
				# Draw the eyes
				image.set_pixel(x, y, Color(0.1, 0.1, 0.1, 1.0))
			elif x > 14 and x < 18 and y == 14:
				# Draw the mouth
				image.set_pixel(x, y, Color(0.1, 0.1, 0.1, 1.0))

	# Create the texture from the image
	var texture = ImageTexture.create_from_image(image)
	self.texture = texture
