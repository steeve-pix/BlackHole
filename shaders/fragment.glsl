#version 330 core
out vec4 FragColor;

uniform vec2 u_resolution;
uniform float u_time;
uniform float u_yaw;
uniform float u_pitch;
uniform float u_zoom;

const int MAX_STEPS = 280;
const float BH_RADIUS = 1.0;
const float STEP_SIZE = 0.04;

// High-fidelity Noise Functions
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1,311.7))) * 43758.5453);
}

float noise(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    f = f*f*(3.-2.*f);
    return mix(mix(hash(i), hash(i+vec2(1,0)), f.x),
            mix(hash(i+vec2(0,1)), hash(i+vec2(1,1)), f.x), f.y);
}

// 6 Octaves for highly detailed disk texture and organic nebulae
float fbm(vec2 p) {
    float v = 0.0, a = 0.5;
    for(int i = 0; i < 6; i++) {
        v += a * noise(p);
        p *= 2.02;
        a *= 0.5;
    }
    return v;
}

// Deep space background using clean 3D ray directions
vec3 getRealisticBackground(vec3 rd, float time) {
    vec2 skyUV = vec2(atan(rd.z, rd.x), acos(rd.y));
    vec3 color = vec3(0.001, 0.002, 0.006); // Rich space depth

    // Layer 1: Volumetric Nebula
    float nebula = fbm(skyUV * 1.6 + vec2(time * 0.008, time * 0.004));
    color += vec3(0.05, 0.03, 0.10) * nebula * 0.4;

    // Layer 2: Main crisp pin-prick stars
    float stars = fbm(skyUV * 70.0);
    color += vec3(0.96, 0.97, 1.0) * smoothstep(0.90, 1.0, stars) * 1.5;

    // Layer 3: Dense deep-field star clusters
    float dense = fbm(skyUV * 190.0 + time * 0.02);
    color += vec3(0.8, 0.9, 1.0) * smoothstep(0.94, 1.0, dense) * 0.8;

    return color;
}

void main() {
    vec2 uv = (gl_FragCoord.xy - 0.5 * u_resolution.xy) / u_resolution.y;

    // Camera ray generation
    float camDist = u_zoom;
    float cy = radians(u_yaw);
    float cp = radians(u_pitch);
    vec3 ro = vec3(camDist * cos(cp) * sin(cy), camDist * sin(cp) * 0.8, camDist * cos(cp) * cos(cy));

    vec3 target = vec3(0.0);
    vec3 ww = normalize(target - ro);
    vec3 uu = normalize(cross(ww, vec3(0.0, 1.0, 0.0)));
    vec3 vv = cross(uu, ww);
    vec3 rd = normalize(uv.x * uu + uv.y * vv + 1.6 * ww);

    vec3 color = vec3(0.0);
    vec3 diskAccum = vec3(0.0);

    vec3 p = ro;
    bool hitBH = false;

    for(int i = 0; i < MAX_STEPS; i++) {
        float r = length(p);

        if(r < BH_RADIUS) {
            hitBH = true;
            break;
        }
        if(r > 25.0) break; // Out of physics boundaries

        // Mathematically correct relativistic gravity bending scaled by step size
        vec3 gravity = -p / (r * r * r);
        rd = normalize(rd + gravity * 0.20 * STEP_SIZE);

        p += rd * STEP_SIZE;

        // Volumetric Accretion Disk simulation
        float diskHeight = abs(p.y);
        float diskR = length(p.xz);

        if(diskHeight < 0.10 && diskR > 1.5 && diskR < 8.0) {
            float angle = atan(p.z, p.x);

            // Highly detailed turbulence from Shader 1
            float turb = fbm(vec2(diskR * 6.0, angle * 14.0 + u_time * 3.5));

            // Smooth brightness falloff
            float brightness = 0.18 / (diskR - 1.3);

            // Relativistic Doppler shifting (Blueshift / Redshift spectrum)
            float doppler = 1.0 + 1.8 * sin(angle + u_time * 2.5);

            // Relativistic beaming (light concentrates towards the observer's movement vector)
            float beaming = pow(max(dot(normalize(p), rd), 0.0), 4.0);

            // Interpolate colors between scorching blue-white and deep plasma orange
            vec3 dCol = mix(vec3(4.0, 0.7, 0.12), vec3(0.2, 1.6, 4.0), clamp(doppler * 0.5, 0.0, 1.0));

            // Accumulate density over the step volume cleanly without overflowing
            diskAccum += dCol * brightness * (0.5 + turb * 0.5) * (1.0 + beaming) * STEP_SIZE * 8.0;
        }
    }

    // Determine Base Color (Black hole shadow vs background space)
    if(hitBH) {
        color = vec3(0.0);
    } else {
        color = getRealisticBackground(rd, u_time);
    }

    // Composite disk over the space backdrop
    color += diskAccum;

    float gravitationalGlow = 0.015 / (length(uv) + 0.04);
    color += gravitationalGlow * vec3(2.3, 1.3, 0.8) * 0.3;

    color = color / (color + vec3(1.0));
    color = pow(color, vec3(1.0 / 2.2));

    FragColor = vec4(color, 1.0);
}