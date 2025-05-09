shader_type canvas_item;

void vertex() {
	// Called for every vertex the material is visible on.
}

void fragment() {
	// Called for every pixel the material is visible on.
	vec4 color = texture(TEXTURE, UV);
	COLOR = color;
	// vertical scroll
	vec2 uv = UV;
	uv.x += 0.17;
	uv.y += TIME * 0.1;
	color = texture(TEXTURE, uv);
	COLOR = color;
}

//void light() {
//	// Called for every pixel for every light affecting the CanvasItem.
//	// Uncomment to replace the default light processing function with this one.
//}
