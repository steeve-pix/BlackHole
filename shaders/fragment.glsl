#version 330 core
out vec4 FragColor;

uniform vec2 u_resolution;
uniform float u_time;
uniform float u_yaw;
uniform float u_pitch;
uniform float u_zoom;

const int MAX_STEPS = 400;
const float BH_RADIUS = 1.0;

// Pseudo-random noise hash
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Seamless 2D Noise
float noise(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    f = f*f*(3.-2.*f);
    return mix(mix(hash(i), hash(i+vec2(1,0)), f.x),
            mix(hash(i+vec2(0,1)), hash(i+vec2(1,1)), f.x), f.y);
}

// High-detail FBM for fine-streaked hot plasma
float fbm(vec2 p) {
    float v = 0.0, a = 0.5;
    for(int i = 0; i < 6; i++) {
        v += a * noise(p);
        p *= 2.25;
        a *= 0.42;
    }
    return v;
}

// Physically-bounded Thin Accretion Disk
float getGasDensity(vec3 p, out float velocityDot) {
    float r = length(p.xz);

    // Strict physics boundaries: Matter cannot orbit safely inside 2.6*Rs
    if (r < 2.6 * BH_RADIUS || r > 7.0 * BH_RADIUS) return 0.0;

    // Scale disk thickness to be razor thin relative to wide scales
    float diskThickness = 0.006 * r;
    float h = abs(p.y);

    // Sharp Gaussian falloff prevents volumetric blobbing
    float verticalFallback = exp(-(h * h) / (2.0 * diskThickness * diskThickness));

    // Relativistic shear: inner gas rotates substantially faster than outer gas
    float angle = atan(p.z, p.x);
    float orbitalSpeed = 0.75 / sqrt(r);

    // High angular multiplier creates ultra-fine hyper-velocity circular texturing
    float tex = fbm(vec2(r * 12.0 - u_time * 2.5, angle * 48.0 + u_time * orbitalSpeed));

    // Track rotation vector relative to incoming photon path
    vec3 tangent = normalize(vec3(-p.z, 0.0, p.x));
    vec3 viewDir = normalize(p);
    velocityDot = dot(tangent, viewDir);

    // Dynamic density drop-off
    float baseDensity = exp(-r * 0.4) * (1.0 / (r - 1.8));

    return baseDensity * verticalFallback * (0.15 + tex * 0.85);
}

// Background starfield mapped infinitely
vec3 getBackground(vec3 rd) {
    // Standardized mapping independent of ray position step variations
    vec2 uv = vec2(atan(rd.z, rd.x), acos(rd.y)) * 2.5;

    float n = fbm(uv * 1.5);
    vec3 spaceGas = vec3(0.008, 0.005, 0.018) * n;

    // Deep contrast pin-prick stars
    float stars = pow(fbm(uv * 75.0), 14.0);
    vec3 starField = vec3(2.0) * stars * 40.0;

    return spaceGas + starField;
}

void main() {
    vec2 uv = (gl_FragCoord.xy - 0.5 * u_resolution.xy) / u_resolution.y;

    // Camera Positioning
    float camDist = max(u_zoom, 3.5); // Bound minimum zoom to prevent clipping into disk
    float cy = radians(u_yaw), cp = radians(u_pitch);
    vec3 ro = vec3(camDist * cos(cp) * sin(cy), camDist * sin(cp), camDist * cos(cp) * cos(cy));

    vec3 target = vec3(0.0);
    vec3 ww = normalize(target - ro);
    vec3 uu = normalize(cross(ww, vec3(0,1,0)));
    vec3 vv = cross(uu, ww);
    vec3 rd = normalize(uv.x * uu + uv.y * vv + 1.5 * ww);

    vec3 p = ro;
    vec3 lightAccum = vec3(0.0);
    float opacityAccum = 0.0;
    bool hitBH = false;

    // --- ZOOM-ADAPTIVE SAFETY LIMITS ---
    // Automatically extend tracking box and outer escape barriers based on zoom depth
    float escapeRadius = max(camDist * 2.5, 60.0);

    for(int i = 0; i < MAX_STEPS; i++) {
        float r = length(p);

        // --- REALISTIC MATHEMATICAL CAPTURE ---
        // If a photon drops below the Photon Sphere threshold with low energy, it cannot escape.
        // Forcing a clean, hard event horizon cut-off removes unphysical "digital glitch" ray trails.
        if (r < BH_RADIUS * 1.002) {
            hitBH = true;
            break;
        }
        if (r > escapeRadius) break;

        // --- ADAPTIVE STEPPING SIZED BY ZOOM ---
        // Steps shrink micro-fine near center, but expand gracefully when zoomed far away
        float h_step = min(0.018 * r, 0.02 * camDist);

        // Mathematically strict Einstein deflection tensor mapping
        vec3 gravityForce = - (1.5 * BH_RADIUS * cross(cross(p, rd), p)) / (r * r * r * r * r);
        rd = normalize(rd + gravityForce * h_step);

        p += rd * h_step;

        // Disk calculations
        float velocityDot = 0.0;
        float dens = getGasDensity(p, velocityDot);

        if (dens > 0.0001) {
            // Relativistic Doppler and Velocity configurations
            float beta = 0.55 / sqrt(r);
            float gamma = 1.0 / sqrt(1.0 - beta * beta);
            float dopplerFactor = 1.0 / (gamma * (1.0 - beta * velocityDot));

            // Relativistic beaming concentration factor
            float beaming = pow(dopplerFactor, 4.8);

            // High-energy central heat profile
            float temperature = 4.5 / (r - 1.4 * BH_RADIUS);

            // Advanced physical color grading
            vec3 baseGasColor = mix(vec3(1.4, 0.12, 0.01), vec3(0.2, 0.65, 2.5), clamp((dopplerFactor - 0.65) * 1.5, 0.0, 1.0));
            // Add high-energy core compression highlights
            baseGasColor = mix(baseGasColor, vec3(2.5, 2.5, 2.5), clamp((dopplerFactor - 1.15) * 2.2, 0.0, 1.0));

            vec3 emission = baseGasColor * dens * temperature * beaming * 3.0;

            // Volumetric Integration
            float alpha = dens * h_step * 18.0;
            lightAccum += emission * (1.0 - opacityAccum) * h_step;
            opacityAccum += (1.0 - opacityAccum) * alpha;

            if (opacityAccum >= 0.99) break;
        }
    }

    // Compose final cosmic outputs
    vec3 finalColor = hitBH ? vec3(0.0) : getBackground(rd) * (1.0 - opacityAccum);
    finalColor += lightAccum;

    // Cinematic ACES Film Tone Mapping Curve
    finalColor = (finalColor * (2.51 * finalColor + 0.03)) / (finalColor * (2.43 * finalColor + 0.59) + 0.14);

    // Final Gamma Conversion
    finalColor = pow(clamp(finalColor, 0.0, 1.0), vec3(1.0 / 2.2));

    FragColor = vec4(finalColor, 1.0);
}