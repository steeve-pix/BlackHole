#version 330 core
out vec4 FragColor;

uniform vec2 u_resolution;
uniform float u_time;
uniform float u_yaw;
uniform float u_pitch;

const int MAX_STEPS = 180;
const float MAX_DIST = 100.0;
const float SURF_DIST = 0.001;
const float BH_RADIUS = 1.0;

// Noise
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1,311.7))) * 43758.5453); }
float noise(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    f = f*f*(3.-2.*f);
    return mix(mix(hash(i), hash(i+vec2(1,0)), f.x),
            mix(hash(i+vec2(0,1)), hash(i+vec2(1,1)), f.x), f.y);
}
float fbm(vec2 p) {
    float v = 0., a = 0.5;
    for(int i=0; i<5; i++) { v += a*noise(p); p *= 2.02; a *= 0.5; }
    return v;
}

vec3 getBackground(vec2 uv) {
    vec3 bg = vec3(0.004, 0.006, 0.015);
    float stars = fbm(uv * 250.0);
    bg += vec3(0.9, 0.95, 1.0) * smoothstep(0.93, 1.0, stars) * 1.1;
    return bg;
}

vec3 applyLensing(vec3 ro, vec3 rd) {
    vec3 toCenter = -ro;
    float impact = length(cross(toCenter, rd));
    float deflection = 8.0 * BH_RADIUS / (impact + 0.5);   // Stronger lensing
    return normalize(rd + normalize(toCenter) * deflection * 0.18);
}

float sdSphere(vec3 p, float r) { return length(p) - r; }

void main() {
    vec2 uv = (gl_FragCoord.xy - 0.5 * u_resolution.xy) / u_resolution.y;

    float camDist = 7.0;
    float cy = radians(u_yaw);
    float cp = radians(u_pitch);
    vec3 ro = vec3(camDist * cos(cp) * sin(cy), camDist * sin(cp) * 0.6, camDist * cos(cp) * cos(cy));

    vec3 rd = normalize(vec3(uv * 1.2, 1.0));
    rd = applyLensing(ro, rd);

    float d = 0.0;
    bool hit = false;

    for(int i = 0; i < MAX_STEPS; i++) {
        vec3 p = ro + rd * d;
        if(sdSphere(p, BH_RADIUS) < SURF_DIST) {
            hit = true;
            break;
        }
        if(d > MAX_DIST) break;
        d += sdSphere(p, BH_RADIUS) * 0.65;
    }

    vec3 color = getBackground(uv);

    if(hit) {
        color = vec3(0.0);   // Black hole
    } else {
        vec3 p = ro + rd * d * 1.1;
        float r = length(p.xz);
        float h = abs(p.y);

        // Accretion Disk - very visible
        if(h < 0.25 && r > 1.4 && r < 8.0) {
            float angle = atan(p.z, p.x);
            float brightness = 9.0 / (r + 0.8);
            float doppler = 1.0 + 2.0 * sin(angle + u_time * 2.0);
            float beaming = pow(max(dot(normalize(p), rd), 0.0), 4.0);

            vec3 diskColor = mix(vec3(3.0, 0.7, 0.1), vec3(0.6, 1.4, 2.8), (doppler + 1.0)*0.3);
            color += brightness * diskColor * (1.0 + beaming * 2.0);
        }

        // Photon ring
        float photon = abs(length(p) - 1.5);
        if(photon < 0.25) color += vec3(2.8, 1.6, 0.9) * (0.9 / (photon + 0.1));
    }

    // Very strong outer glow
    float centerDist = length(uv);
    color += 0.18 / (centerDist + 0.3) * vec3(1.8, 0.9, 0.5);

    color = color / (color + 1.0);
    color = pow(color, vec3(0.85));

    FragColor = vec4(color, 1.0);
}