#version 330 core
out vec4 FragColor;

uniform vec2 u_resolution;
uniform float u_time;
uniform float u_yaw;
uniform float u_pitch;
uniform float u_zoom;  // Add this to main.cpp if missing

const int MAX_STEPS = 380;
const float BH_RADIUS = 1.0;
const float PHOTON_RADIUS = 1.5;
const float STEP_SIZE = 0.032;

// Noise
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1,311.7))) * 43758.5453); }
float noise(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    f = f*f*(3.-2.*f);
    return mix(mix(hash(i), hash(i+vec2(1,0)), f.x), mix(hash(i+vec2(0,1)), hash(i+vec2(1,1)), f.x), f.y);
}
float fbm(vec2 p) {
    float v = 0.0, a = 0.5;
    for(int i = 0; i < 7; i++) {
        v += a * noise(p); p *= 2.03; a *= 0.48;
    }
    return v;
}

// === ULTRA REALISTIC SPACE BACKGROUND ===
vec3 getRealisticBackground(vec3 rd, float time) {
    vec2 uv = vec2(atan(rd.z, rd.x), acos(rd.y)) * 2.8;
    vec3 col = vec3(0.0006, 0.0011, 0.0038);

    // Multi-layer nebulae (depth + color variation)
    float n1 = fbm(uv * 0.7 + vec2(time*0.004, time*0.006));
    float n2 = fbm(uv * 2.4 + vec2(-time*0.005, time*0.003));
    float n3 = fbm(uv * 6.0);

    col += vec3(0.07, 0.04, 0.13) * n1 * 0.55;
    col += vec3(0.09, 0.05, 0.02) * n2 * 0.4;
    col += vec3(0.02, 0.07, 0.11) * n3 * 0.3;

    // Stars with size variation + twinkling
    float starsSmall = pow(fbm(uv * 110.0), 5.5);
    float starsBig = pow(fbm(uv * 38.0 + time*0.08), 6.2);
    col += vec3(1.0) * (starsSmall * 2.8 + starsBig * 1.6);

    return clamp(col * 1.1, 0.0, 2.0);
}

void main() {
    vec2 uv = (gl_FragCoord.xy - 0.5 * u_resolution.xy) / u_resolution.y;

    float camDist = max(u_zoom, 6.0);
    float cy = radians(u_yaw), cp = radians(u_pitch);
    vec3 ro = vec3(camDist * cos(cp) * sin(cy), camDist * sin(cp) * 0.7, camDist * cos(cp) * cos(cy));

    vec3 target = vec3(0.0);
    vec3 ww = normalize(target - ro);
    vec3 uu = normalize(cross(ww, vec3(0,1,0)));
    vec3 vv = cross(uu, ww);
    vec3 rd = normalize(uv.x * uu + uv.y * vv + 0.95 * ww);  // Wider FOV

    vec3 p = ro;
    vec3 diskAccum = vec3(0.0);
    bool hitBH = false;

    for(int i = 0; i < MAX_STEPS; i++) {
        float r = length(p);
        if (r < BH_RADIUS) { hitBH = true; break; }
        if (r > 40.0) break;

        // Stronger GR lensing
        float bend = 0.28 * STEP_SIZE / (r * r * r);
        rd = normalize(rd - p * bend);

        p += rd * STEP_SIZE;

        // Improved volumetric accretion disk
        float diskH = abs(p.y);
        float diskR = length(p.xz);
        if (diskH < 0.085 && diskR > 1.6 && diskR < 11.0) {
            float angle = atan(p.z, p.x);
            float turb = fbm(vec2(diskR * 9.0 + u_time*1.8, angle * 22.0));

            float temp = pow(max(diskR - 1.4, 0.1), -0.78);  // Realistic temperature profile
            float doppler = 1.0 + 2.4 * sin(angle + u_time * 4.2);
            float beaming = pow(max(dot(normalize(p), rd), 0.0), 6.0);

            vec3 hot = vec3(5.5, 1.8, 0.6);
            vec3 cool = vec3(1.6, 0.5, 0.08);
            vec3 dcol = mix(cool, hot, clamp(doppler * 0.65, 0.0, 1.0));

            diskAccum += dcol * temp * (0.65 + turb) * (1.0 + beaming * 3.5) * STEP_SIZE * 11.0;
        }

        // Photon sphere ring
        if (abs(r - PHOTON_RADIUS) < 0.09) {
            diskAccum += vec3(3.2, 2.1, 0.9) * 0.25 * (1.0 - abs(r - PHOTON_RADIUS)/0.09);
        }
    }

    vec3 color = hitBH ? vec3(0.0) : getRealisticBackground(rd, u_time);
    color += diskAccum * 1.25;

    // Extra lensing glow
    color += 0.022 / (length(uv) + 0.03) * vec3(3.0, 1.7, 0.9);

    // Tonemapping for filmic look
    color = color / (color + 1.0);
    color = pow(color, vec3(0.95));

    FragColor = vec4(color, 1.0);
}