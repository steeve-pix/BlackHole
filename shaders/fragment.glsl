#version 330 core
out vec4 FragColor;

uniform vec2 u_resolution;
uniform float u_time;

// Ray marching constants
const int MAX_STEPS = 100;
const float MAX_DIST = 100.0;
const float SURF_DIST = 0.001;

// Sphere SDF
float sdSphere(vec3 p, float radius){
    return length(p) - radius;
}

void main() {
    vec2 uv = (gl_FragCoord.xy - 0.5 * u_resolution.xy) / u_resolution.y;

    // Ray origin (camera position)
    vec3 ro = vec3(0.0, 0.0, -3.0);

    // Ray direction
    vec3 rd = normalize(vec3(uv, 1.0));

    // Ray marching
    float d = 0.0;
    for (int i = 0; i < MAX_STEPS; i++) {
        vec3 p = ro + rd * d;
        float dist = sdSphere(p, 0.8);   // Black hole radius

        if (dist < SURF_DIST)
        {
            // Hit the black hole
            FragColor = vec4(0.0, 0.0, 0.0, 1.0);
            return;
        }

        if (d > MAX_DIST)
        break;

        d += dist;
    }

    // Background + simple accretion disk
    float disk = 0.0;
    float angle = atan(uv.y, uv.x);
    float distFromCenter = length(uv);

    disk += 0.04 / abs(distFromCenter - 1.1);
    disk = clamp(disk, 0.0, 1.0);

    vec3 color = vec3(0.0);
    color += disk * vec3(1.8, 0.7, 0.2) * (1.0 + 0.5 * sin(angle * 3.0 + u_time));

    // Very faint stars / background
    color += 0.02 * vec3(0.8, 0.9, 1.0) * smoothstep(0.9, 0.0, fract(sin(uv.x * 100.0 + uv.y * 50.0) * 43758.5453));

    FragColor = vec4(color, 1.0);
}