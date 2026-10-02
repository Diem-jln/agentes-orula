#version 300 es
precision highp float;

in vec2 vTexCoord;
out vec4 outColor;

uniform sampler2D uDrawTex;
uniform float uBeatTension;
uniform float uVoiceEnergy; // Energía de rap
uniform float uTime;

uniform float uGlitchTrigger;
uniform float uInvertTrigger;
uniform float uShockwave;
uniform int uColorPalette;

float hash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

void main() {
    vec2 uv = vTexCoord;

    // Distorsión por onda de choque expansiva
    if (uShockwave > 0.01) {
        vec2 centerOffset = uv - vec2(0.5);
        float d = length(centerOffset);
        float waveRadius = (1.0 - uShockwave) * 0.85;
        float diff = abs(d - waveRadius);
        if (diff < 0.12) {
            float shockDisp = sin(diff * 28.0) * 0.030 * uShockwave;
            uv += normalize(centerOffset) * shockDisp;
        }
    }

    // Glitch horizontal en quiebres vocales o acentos
    if (uGlitchTrigger > 0.05) {
        float sliceY = floor(uv.y * 36.0);
        float sliceNoise = hash(vec2(sliceY, floor(uTime * 30.0)));
        if (sliceNoise > 0.60) {
            float sliceOffset = (hash(vec2(sliceY, uTime)) - 0.5) * 0.045 * uGlitchTrigger;
            uv.x += sliceOffset;
        }
    }

    vec2 uvCenter = (uv - 0.5) * 2.0;
    float distSq = dot(uvCenter, uvCenter);

    // Aberración cromática anamórfica
    float caShift = (0.0016 + uBeatTension * 0.0035 + uVoiceEnergy * 0.0040 + uGlitchTrigger * 0.010) * (distSq + 0.12);
    float densityR = texture(uDrawTex, uv + vec2(caShift, 0.0)).r;
    float densityG = texture(uDrawTex, uv).r;
    float densityB = texture(uDrawTex, uv - vec2(caShift, 0.0)).r;

    // Curva de densidad sin ruido residual
    float density = smoothstep(0.035, 0.86, densityG);

    // Destello anamórfico horizontal (Streak de lente de cine) que reacciona directamente al rap
    float streak = 0.0;
    float streakOffset = 0.010 + uVoiceEnergy * 0.018;
    streak += texture(uDrawTex, uv + vec2(streakOffset, 0.0)).r * 0.38;
    streak += texture(uDrawTex, uv - vec2(streakOffset, 0.0)).r * 0.38;
    streak += texture(uDrawTex, uv + vec2(streakOffset * 2.2, 0.0)).r * 0.22;
    streak += texture(uDrawTex, uv - vec2(streakOffset * 2.2, 0.0)).r * 0.22;
    streak = pow(streak, 2.6) * (0.6 + uBeatTension * 0.7 + uVoiceEnergy * 1.2);

    // Paletas cromáticas de alto contraste
    vec3 baseBg = vec3(0.008, 0.010, 0.012);
    vec3 smokeCol = vec3(0.025, 0.038, 0.032);
    vec3 midTone = vec3(0.020, 0.230, 0.145);
    vec3 coreHighlight = vec3(0.880, 0.560, 0.180);

    if (uColorPalette == 1) {
        // Obsidiana ébano / Amatista sombría / Oro fundido
        smokeCol = vec3(0.038, 0.020, 0.042);
        midTone = vec3(0.260, 0.080, 0.360);
        coreHighlight = vec3(0.980, 0.780, 0.220);
    } else if (uColorPalette == 2) {
        // Petróleo / Turquesa oxidado / Cobre volcánico
        smokeCol = vec3(0.015, 0.035, 0.038);
        midTone = vec3(0.030, 0.270, 0.250);
        coreHighlight = vec3(0.950, 0.420, 0.150);
    }

    // Composición tonal multicapa
    vec3 col = mix(baseBg, smokeCol, smoothstep(0.01, 0.24, density));
    col = mix(col, midTone, smoothstep(0.09, 0.58, density));

    // Núcleos densos
    float coreMask = smoothstep(0.44, 0.94, (densityR + densityG + densityB) * 0.333);
    vec3 coreColor = coreHighlight * (1.15 + uBeatTension * 0.35 + uVoiceEnergy * 0.45);
    col = mix(col, coreColor, coreMask * 0.92);

    // Destellos especulares + Streak anamórfico
    col += pow(densityB, 3.8) * coreHighlight * (0.22 + uBeatTension * 0.20);
    col += streak * coreHighlight * 0.85;

    // INVERSIÓN NEGATIVA CEREMONIAL
    if (uInvertTrigger > 0.01) {
        vec3 invBg = vec3(0.93, 0.94, 0.92);
        vec3 invFilaments = vec3(0.06, 0.10, 0.08);
        vec3 invCore = vec3(0.88, 0.28, 0.08);

        vec3 invCol = mix(invBg, invFilaments, smoothstep(0.04, 0.65, density));
        invCol = mix(invCol, invCore, coreMask);
        col = mix(col, invCol, uInvertTrigger);
    }

    // Viñeta perimetral pura sin grano
    float vignette = smoothstep(1.78, 0.32, distSq);
    col *= vignette;

    outColor = vec4(clamp(col, 0.0, 1.0), 1.0);
}