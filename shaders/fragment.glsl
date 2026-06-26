#version 330 core
out vec4 FragColor;

uniform vec2 u_resolution;
uniform float u_time;
uniform float u_yaw;
uniform float u_pitch;
uniform float u_zoom;

const int MAX_STEPS = 250;
const float BH_RADIUS = 1.0;
const float STEP_SIZE = 0.04;

// Noise functions
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1,311.7))) * 43758.5453);
}

float noise(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    f = f*f*(3.-2.*f);
    return mix(mix(hash(i), hash(i+vec2(1,0)), f.x),
            mix(hash(i+vec2(0,1)), hash(i+vec2(1,1)), f.x), f.y);
}

float fbm(vec2 p) {
    float v = 0.0, a = 0.5;
    for(int i = 0; i < 5; i++) { // reduced iterations for performance
        v += a * noise(p);
        p *= 2.02;
        a *= 0.5;
    }
    return v;
}

// Fixed background: Uses 3D Ray Direction so stars distort realistically!
vec3 getRealisticBackground(vec3 rd, float time) {
    // Map 3D ray direction to a 2D spherical/panoramic mapping
    vec2 skyUV = vec2(atan(rd.z, rd.x), acos(rd.y));

    vec3 color = vec3(0.002, 0.003, 0.008); // Crisp deep space blue-black

    // Very subtle nebula
    float nebula = fbm(skyUV * 1.5 + vec2(time * 0.005, time * 0.002));
    color += vec3(0.04, 0.02, 0.08) * nebula;

    // Main star field (sharp step for pin-prick stars)
    float stars = fbm(skyUV * 50.0);
    color += vec3(0.9, 0.95, 1.0) * smoothstep(0.92, 1.0, stars) * 1.5;

    // Dense small stars
    float dense = fbm(skyUV * 120.0);
    color += vec3(0.8, 0.9, 1.0) * smoothstep(0.95, 1.0, dense) * 0.8;

    return color;
}

void main() {
    vec2 uv = (gl_FragCoord.xy - 0.5 * u_resolution.xy) / u_resolution.y;

    // Camera setup
    float camDist = u_zoom;
    float cy = radians(u_yaw);
    float cp = radians(u_pitch);
    vec3 ro = vec3(camDist * cos(cp) * sin(cy), camDist * sin(cp) * 0.8, camDist * cos(cp) * cos(cy));

    // Build camera matrix to properly transform screen rays into world space
    vec3 target = vec3(0.0);
    vec3 ww = normalize(target - ro);
    vec3 uu = normalize(cross(ww, vec3(0.0, 1.0, 0.0)));
    vec3 vv = cross(uu, ww);
    vec3 rd = normalize(uv.x * uu + uv.y * vv + 1.5 * ww);

    vec3 color = vec3(0.0);
    vec3 diskColorAccum = vec3(0.0);

    // Raymarching tracking gravity lensing dynamically per step
    vec3 p = ro;
    bool hitBH = false;

    for(int i = 0; i < MAX_STEPS; i++) {
        float r = length(p);

        if(r < BH_RADIUS) {
            hitBH = true;
            break;
        }
        if(r > 20.0) break; // Escape velocity / out of bounds

        // Relativistic gravity bending effect
        vec3 gravityPull = -p / (r * r * r);
        rd = normalize(rd + gravityPull * 0.18 * STEP_SIZE);
        p += rd * STEP_SIZE;

        // Accretion Disk Intersection Check inside the warped space
        float diskR = length(p.xz);
        if(abs(p.y) < 0.08 && diskR > 1.5 && diskR < 6.0) {
            float angle = atan(p.z, p.x);
            float turb = fbm(vec2(diskR * 4.0, angle * 10.0 + u_time * 2.0));

            float brightness = 0.15 / (diskR - 1.2);
            // Doppler shift (blueshifted left side, redshifted right side)
            float doppler = 1.0 + 1.2 * sin(angle + u_time * 1.5);

            vec3 dCol = mix(vec3(4.0, 0.8, 0.1), vec3(0.2, 1.5, 4.0), clamp(doppler * 0.5, 0.0, 1.0));
            diskColorAccum += dCol * brightness * (0.4 + turb * 0.6) * STEP_SIZE * 15.0;
        }
    }

    if (hitBH) {
        color = vec3(0.0); // Event Horizon is pitch black
    } else {
        // Sample background using the final bent ray direction vector!
        color = getRealisticBackground(rd, u_time);
    }

    // Layer the disk coloration over the background
    color += diskColorAccum;

    // Subtle, tight gravitational lensing glow around the event horizon edge
    float centerGlow = 0.02 / (length(uv) + 0.05);
    color += centerGlow * vec3(2.1, 1.1, 0.7) * 0.5;

    // Tonemapping & Gamma Correction
    color = color / (color + vec3(1.0));
    color = pow(color, vec3(1.0 / 2.2));

    FragColor = vec4(color, 1.0);
}