#version 330 core
out vec4 FragColor;

uniform vec2 u_resolution;
uniform float u_time;

void main() {
    vec2 uv = (gl_FragCoord.xy - 0.5 * u_resolution.xy) / u_resolution.y;

    float d = length(uv);                    // distance from center
    float blackhole = smoothstep(0.15, 0.14, d);   // black sphere

    // Simple glow / accretion disk
    float glow = 0.02 / (d - 0.18);
    glow = clamp(glow, 0.0, 1.0);

    vec3 color = vec3(0.0);
    color += blackhole * vec3(0.0);                    // pure black
    color += glow * vec3(1.0, 0.4, 0.1);              // orange-red glow

    FragColor = vec4(color, 1.0);
}