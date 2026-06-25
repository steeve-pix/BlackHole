#version 330 core
out vec4 FragColor;

uniform vec2 u_resolution;
uniform float u_time;

void main() {
    vec2 uv = (gl_FragCoord.xy - 0.5 * u_resolution.xy) / u_resolution.y;

    float d = length(uv);                    // distance from center

    // Black hole event horizon
    float horizon = smoothstep(0.18, 0.17, d);

    // Acretion disk glow
    float disk = 0.0;
    disk += 0.025 / abs(d - 0.22);           // inner bright ring
    disk += 0.015 / abs(d - 0.28);           // outer ring
    disk = clamp(disk, 0.0, 1.2);

    // Make it brighter on one side
    float angle = atan(uv.y, uv.x);
    float doppler = 1.0 + 0.6 * sin(angle + u_time * 0.5);

    vec3 color = vec3(0.0);
    color += horizon * vec3(0.0);                 // pure black

    // Orange red accretiom disk
    vec3 diskColor = vec3(1.8, 0.6, 0.1) * doppler;
    color += disk * diskColor * 0.8;

    color += 0.08 / (d + 0.3) * vec3(0.9, 0.4, 0.2);

    FragColor = vec4(color, 1.0);
}