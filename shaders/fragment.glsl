#version 330 core
out vec4 FragColor;

uniform vec2 u_resolution;
uniform float u_time;
uniform float u_yaw;
uniform float u_pitch;
uniform float u_zoom;

const int MAX_STEPS = 420;
const float BH_RADIUS = 1.0;
const float PHOTON_RADIUS = 1.5;
const float STEP_SIZE = 0.027;

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

// Deep space
vec3 getRealisticBackground(vec3 rd, float time) {
    vec2 uv = vec2(atan(rd.z, rd.x), acos(rd.y)) * 3.0;
    vec3 col = vec3(0.0004, 0.0009, 0.0032);

    float n1 = fbm(uv * 0.7 + vec2(time*0.0035));
    float n2 = fbm(uv * 2.5 - vec2(time*0.0045));
    col += vec3(0.055, 0.03, 0.105) * n1 * 0.52;
    col += vec3(0.085, 0.05, 0.018) * n2 * 0.4;

    float stars = pow(fbm(uv * 105.0), 5.7);
    float bigStars = pow(fbm(uv * 40.0 + time*0.07), 6.4);
    col += vec3(1.0) * (stars * 2.7 + bigStars * 1.7);

    return clamp(col, 0.0, 2.0);
}

void main() {
    vec2 uv = (gl_FragCoord.xy - 0.5 * u_resolution.xy) / u_resolution.y;

    float camDist = u_zoom;
    float cy = radians(u_yaw), cp = radians(u_pitch);
    vec3 ro = vec3(camDist * cos(cp) * sin(cy), camDist * sin(cp) * 0.65, camDist * cos(cp) * cos(cy));

    vec3 target = vec3(0.0);
    vec3 ww = normalize(target - ro);
    vec3 uu = normalize(cross(ww, vec3(0,1,0)));
    vec3 vv = cross(uu, ww);
    vec3 rd = normalize(uv.x * uu + uv.y * vv + 0.9 * ww);   // Wide cinematic FOV

    vec3 p = ro;
    vec3 diskAccum = vec3(0.0);
    bool hitBH = false;

    for(int i = 0; i < MAX_STEPS; i++) {
        float r = length(p);
        if (r < BH_RADIUS) { hitBH = true; break; }
        if (r > 50.0) break;

        // Stronger GR lensing
        float bend = 0.34 * STEP_SIZE / (r * r * r + 0.05);
        rd = normalize(rd - normalize(p) * bend);

        p += rd * STEP_SIZE;

        // Thinner, more realistic volumetric disk
        float diskH = abs(p.y);
        float diskR = length(p.xz);
        if (diskH < 0.055 && diskR > 1.6 && diskR < 11.0) {  // thinner!
            float angle = atan(p.z, p.x);
            float turb = fbm(vec2(diskR * 9.5 + u_time * 2.0, angle * 20.0));

            float temp = pow(max(diskR - 1.5, 0.15), -0.8);  // hotter inside

            float doppler = 1.0 + 2.9 * sin(angle + u_time * 4.8);
            float beaming = pow(max(dot(normalize(p), rd), 0.0), 6.8);

            vec3 hot = vec3(7.0, 2.4, 0.8);
            vec3 cool = vec3(1.8, 0.5, 0.1);
            vec3 dcol = mix(cool, hot, clamp(doppler * 0.45, 0.0, 1.0));

            diskAccum += dcol * temp * (0.6 + turb * 0.6) * (1.0 + beaming * 4.2) * STEP_SIZE * 16.0;
        }

        // Photon ring
        if (abs(r - PHOTON_RADIUS) < 0.075) {
            diskAccum += vec3(4.5, 2.8, 1.2) * 0.28 * smoothstep(0.075, 0.0, abs(r - PHOTON_RADIUS));
        }
    }

    vec3 color = hitBH ? vec3(0.0) : getRealisticBackground(rd, u_time);
    color += diskAccum * 1.05;

    color += 0.025 / (length(uv) + 0.028) * vec3(3.4, 1.9, 1.0);

    // Filmic look
    color = color / (color + 1.0);
    color = pow(color, vec3(0.93));

    FragColor = vec4(color, 1.0);
}