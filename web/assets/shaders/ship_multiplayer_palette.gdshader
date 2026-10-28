shader_type canvas_item;

void fragment() {
	vec4 source = texture(TEXTURE, UV);
	float luminance = dot(source.rgb, vec3(0.2126, 0.7152, 0.0722));
	float grayscale = mix(0.62, 1.0, smoothstep(0.78, 0.93, luminance));
	COLOR = vec4(vec3(grayscale), source.a) * COLOR;
}
