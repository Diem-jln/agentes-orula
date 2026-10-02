#version 300 es
precision highp float;

uniform sampler2D u_trail;
in vec2 i_P;
in float i_A;
in float i_T;

out vec2 v_P;
out float v_A;
out float v_T;

uniform vec2 i_dim;
uniform int pen;
uniform float[20] v;
uniform float[8] mps;
uniform int frame;

// Entradas de audio desacopladas
uniform float uBass;       // Tololoche / Bombo
uniform float uMid;        // Voz / Rap métrico
uniform float uHigh;       // Percusión / Requinto
uniform float uVortexWeight;
uniform float uShockwave;

vec2 bd(vec2 pos) {
    pos *= 0.5;
    pos += vec2(0.5);
    pos -= floor(pos);
    pos -= vec2(0.5);
    pos *= 2.0;
    return pos;
}

vec2 cr(float t) {
    vec2 G1 = vec2(mps[0], mps[1]);
    vec2 G2 = vec2(mps[2], mps[3]);
    vec2 G3 = vec2(mps[4], mps[5]);
    vec2 G4 = vec2(mps[6], mps[7]);
    vec2 A = G1 * -0.5 + G2 * 1.5 + G3 * -1.5 + G4 * 0.5;
    vec2 B = G1 + G2 * -2.5 + G3 * 2.0 + G4 * -0.5;
    vec2 C = G1 * -0.5 + G3 * 0.5;
    vec2 D = G2;
    return t * (t * (t * A + B) + C) + D;
}

void main() {
    vec2 dir = vec2(cos(i_T), sin(i_T));
    float hd = i_dim.x * 0.5;
    vec2 sp = 0.5 * (i_P + vec2(1.0));

    // Muestreo sensorial
    float sv = texture(u_trail, bd(sp + v[13] / hd * dir + vec2(0.0, v[12] / hd))).x;
    sv = max(sv, 0.000000001);

    // CONTROL DEL FLOW VOCAL (ELIMINACIÓN TOTAL DE ESTÁTICA):
    // Cuando el cantante rapea (uMid alto), los agentes NO deben dudar ni girar alocadamente.
    // Aumentamos masivamente la velocidad lineal frontal y estabilizamos la trayectoria.
    float rapEnergy = clamp(uMid * 1.6, 0.0, 1.0);
    float stepBoost = 1.0 + (uBass * 1.6) + (rapEnergy * 2.2);
    
    // Distancia de avance limpia y decidida
    float md = max(v[9] / hd + v[11] * pow(sv, v[10]) * 250.0 / hd, 0.85 / hd) * stepBoost;

    // El sensor se proyecta hacia adelante en línea recta cuando canta
    float sd = (v[0] / hd + v[2] * pow(sv, v[1]) * 250.0 / hd) * (1.0 + rapEnergy * 1.2 + uBass * 0.5);
    
    // El abanico sensorial se estrecha con el rap para crear filamentos finos como agujas
    float sa = (v[3] + v[5] * pow(sv, v[4])) * max(0.25, 1.0 - rapEnergy * 0.55);
    
    // La rotación caótica se suaviza: en pleno rap, los agentes fluyen en corrientes laminares
    float ra = (v[6] + v[8] * pow(sv, v[7])) * max(0.35, 1.0 - rapEnergy * 0.40);

    // Muestreo direccional
    float m = texture(u_trail, bd(sp + sd * vec2(cos(i_T), sin(i_T)))).x;
    float l = texture(u_trail, bd(sp + sd * vec2(cos(i_T + sa), sin(i_T + sa)))).x;
    float r = texture(u_trail, bd(sp + sd * vec2(cos(i_T - sa), sin(i_T - sa)))).x;

    // Navegación puramente orientada a vectores, CERO vibración en el lugar
    float h = i_T;
    if (m > l && m > r) {
        // Trayectoria pura
    }
    else if (l < r) {
        h -= ra;
    }
    else if (l > r) {
        h += ra;
    }
    // Si m == l == r (fondo negro), continúan de frente sin dispersarse

    vec2 nd = vec2(cos(h), sin(h));
    vec2 op = i_P + nd * md;

    // VÓRTICES Y ATRACTORES ORBITALES REACTIVOS
    if (uVortexWeight > 0.01) {
        float t = float(frame) * (0.0035 + rapEnergy * 0.004); // El rap acelera la velocidad orbital
        float orbitRadius = 0.36 + sin(t * 1.618) * 0.08 + (uBass * 0.18) - (rapEnergy * 0.10);
        vec2 attractorA = vec2(sin(t), cos(t * 1.1)) * orbitRadius;
        vec2 attractorB = -attractorA;

        vec2 deltaA = attractorA - i_P;
        vec2 deltaB = attractorB - i_P;
        float distA = max(length(deltaA), 0.045);
        float distB = max(length(deltaB), 0.045);

        vec2 tangentA = vec2(-deltaA.y, deltaA.x) / distA;
        vec2 tangentB = vec2(-deltaB.y, deltaB.x) / distB;

        float vortexPower = 0.0013 * uVortexWeight * (1.0 + uBass * 1.2 + rapEnergy * 0.8);
        vec2 orbitalForce = (tangentA / distA + tangentB / distB) * vortexPower;
        
        float suctionPower = (uBass * 1.6 + rapEnergy * 1.2) * uVortexWeight * 0.00065;
        vec2 suction = (normalize(deltaA) / (distA * 6.5) + normalize(deltaB) / (distB * 6.5)) * suctionPower;
        
        op += orbitalForce + suction;
    }

    // Ondas de choque por transientes
    if (uShockwave > 0.01) {
        float distCenter = length(i_P);
        float waveFront = abs(distCenter - (1.0 - uShockwave * 0.9));
        float pushForce = smoothstep(0.20, 0.0, waveFront) * uShockwave * 0.035;
        op += normalize(i_P + vec2(0.0001)) * pushForce;
    }

    // Control por puntero
    const float segmentPop = 0.0005;
    if (pen == 1 && i_A < segmentPop) {
        op = 2.0 * cr(i_A / segmentPop) - vec2(1.0);
    }

    v_P = bd(op);
    v_A = fract(i_A + segmentPop);
    v_T = h;
}