#version 120
uniform sampler2D colors;
#define N 16
uniform int light_count;
uniform float[N] lightPosX;
uniform float[N] lightPosY;
uniform float[N] colorR;
uniform float[N] colorG;
uniform float[N] colorB;
uniform float[N] radius;

void main()
{
	vec4 color = vec4(0.0);
	for (int i = 0; i < light_count; ++i) {
		vec2 dist = gl_FragCoord.xy - vec2(lightPosX[i], lightPosY[i]);
		float mult = (radius[i] * radius[i]) / dot(dist, dist);
		mult = clamp(mult, 0.0, 1.0);
		color += vec4(colorR[i], colorG[i], colorB[i], 1.0) * mult;
	}
	color = clamp(color, 0.0, 1.0);
	gl_FragColor = texture2D(colors, gl_TexCoord[0].xy) * color;
}
