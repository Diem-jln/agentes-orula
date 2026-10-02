// src/main.js
import { orulaPreset } from "./presets/orula.js";
import { POINTS } from "./presets/points.js";
import { Simulation } from "./simulation.js";
import { AudioAnalyzer } from "./audio/audioAnalyzer.js";

async function loadShaderSource(url) {
    const res = await fetch(url);
    if (!res.ok) throw new Error(`Error cargando shader: ${url}`);
    return await res.text();
}

// Topologías maestras de 36 Points
const TOPOLOGIES = [
    { name: "Turing Laberíntico", params: POINTS.point09.params, vortex: 0.0 },
    { name: "Ondas Longitudinales", params: POINTS.point08.params, vortex: 0.15 },
    { name: "Bifurcación Táctil", params: POINTS.point05.params, vortex: 0.25 },
    { name: "Singularidades Tensas", params: POINTS.point07.params, vortex: 0.60 },
    { name: "Metaxilografía Pesada", params: POINTS.point13.params, vortex: 0.20 },
    { name: "Espacio Negativo", params: POINTS.point24.params, vortex: 0.10 },
    { name: "Consolidación Circular", params: POINTS.point25.params, vortex: 0.85 },
    { name: "Vórtice Orula", params: orulaPreset.params, vortex: 0.70 }
];

let currentTopoIndex = 7;
let currentPaletteIndex = 0;

function getNextTopology(isRapping, instantEnergy) {
    let candidates = [];
    if (isRapping) {
        // En pleno rap: formas de alta velocidad, corrientes tensas y bifurcaciones rápidas
        candidates = [0, 2, 3, 6, 7]; // Turing, Tactile, Singularities, Circular, Orula
    } else if (instantEnergy > 0.60) {
        candidates = [3, 6, 7]; // Singularidades y vórtices
    } else {
        candidates = [1, 4, 5]; // Ondas y espacio negativo pausado
    }

    candidates = candidates.filter(i => i !== currentTopoIndex);
    const chosenIndex = candidates[Math.floor(Math.random() * candidates.length)];
    currentTopoIndex = chosenIndex;
    
    const baseTopo = TOPOLOGIES[chosenIndex];
    const mutated = new Float32Array(baseTopo.params);
    const jitter = (Math.random() - 0.5) * 0.16;
    mutated[3] = Math.max(0.2, mutated[3] + jitter);
    mutated[15] = Math.max(0.932, Math.min(0.978, mutated[15]));
    mutated[16] = Math.round(mutated[16]);

    return { params: mutated, vortex: baseTopo.vortex };
}

async function init() {
    const canvas = document.getElementById("canvas");
    const gl = canvas.getContext("webgl2", { 
        preserveDrawingBuffer: false, 
        powerPreference: "high-performance",
        antialias: false,
        depth: false,
        stencil: false
    });

    if (!gl) {
        alert("Tu navegador no soporta WebGL2.");
        return;
    }

    function resize() {
        canvas.width = window.innerWidth;
        canvas.height = window.innerHeight;
    }
    window.addEventListener("resize", resize);
    resize();

    const [
        particleUpdateVert,
        particleRenderVert,
        particleRenderFrag,
        blurFrag,
        clearScreenFrag,
        drawScreenFrag
    ] = await Promise.all([
        loadShaderSource("./src/shaders/particleUpdate.vert.glsl"),
        loadShaderSource("./src/shaders/particleRender.vert.glsl"),
        loadShaderSource("./src/shaders/particleRender.frag.glsl"),
        loadShaderSource("./src/shaders/blur.frag.glsl"),
        loadShaderSource("./src/shaders/clearScreen.frag.glsl"),
        loadShaderSource("./src/shaders/drawScreen.frag.glsl")
    ]);

    const params = {
        ...orulaPreset,
        simSize: 512,
        renderSize: 1024,
        mouse: { x: 0.5, y: 0.5 },
        pen: false
    };

    const sim = new Simulation(gl, params, {
        particleUpdateVert,
        particleRenderVert,
        particleRenderFrag,
        blurFrag,
        clearScreenFrag,
        drawScreenFrag
    });

    const audioElement = document.getElementById("audioTrack");
    audioElement.src = "./src/audio/orula.mp4";

    const playBtn = document.getElementById("playBtn");
    const hudOverlay = document.getElementById("hud-overlay");
    const analyzer = new AudioAnalyzer(audioElement);
    let isPlaying = false;

    playBtn.addEventListener("click", async () => {
        try {
            await analyzer.play();
            isPlaying = true;
            hudOverlay.classList.remove("hud-visible");
            hudOverlay.classList.add("hud-hidden");
        } catch (err) {
            console.error("Error reproduciendo audio:", err);
            playBtn.textContent = "⚠ Archivo no encontrado";
        }
    });

    window.addEventListener("keydown", async (e) => {
        const key = e.key.toLowerCase();

        if (key === "p") {
            if (!document.fullscreenElement) {
                document.documentElement.requestFullscreen().then(() => resize()).catch(() => {});
            } else {
                if (document.exitFullscreen) {
                    document.exitFullscreen().then(() => resize()).catch(() => {});
                }
            }
        }

        if (key === "o") {
            isPlaying = await analyzer.toggle();
            if (!isPlaying) {
                document.body.classList.remove("hide-cursor");
            }
        }
    });

    let cursorTimeout;
    function showCursor() {
        document.body.classList.remove("hide-cursor");
        clearTimeout(cursorTimeout);
        cursorTimeout = setTimeout(() => {
            if (isPlaying) document.body.classList.add("hide-cursor");
        }, 1600);
    }

    window.addEventListener("pointermove", (e) => {
        params.mouse.x = e.clientX / window.innerWidth;
        params.mouse.y = e.clientY / window.innerHeight;
        showCursor();
    });

    window.addEventListener("pointerdown", (e) => {
        if (e.target === canvas) {
            params.pen = true;
            sim.triggerShockwave(0.9);
            sim.triggerGlitch(0.6);
        }
        showCursor();
    });

    window.addEventListener("pointerup", () => { params.pen = false; });

    let lastMorphTime = 0;
    let lastInvertTime = 0;
    let lastGlitchTime = 0;
    let lastShockwaveTime = 0;
    let lastPaletteChange = 0;
    let wasRappingPrev = false;

    function animate(now) {
        const bands = analyzer.getBands();
        const instantEnergy = bands.bass * 0.60 + bands.mid * 0.40;
        const isRapping = bands.mid > 0.42; // Detección activa de voz/rap

        if (isPlaying) {
            // 1. CUANDO EL CANTANTE COMIENZA A RAPEAR:
            // Si pasa de calma a rap, dispara inmediatamente un quiebre de forma y un micro-glitch
            if (isRapping && !wasRappingPrev && (now - lastMorphTime) > 1800) {
                const nextTopo = getNextTopology(true, instantEnergy);
                sim.morphTo(nextTopo.params, nextTopo.vortex);
                sim.triggerGlitch(0.75);
                lastMorphTime = now;
            }
            wasRappingPrev = isRapping;

            // 2. ONDAS DE CHOQUE EN EL GOLPE DEL TOLOLOCHE (>0.76)
            if (bands.bass > 0.76 && (now - lastShockwaveTime) > 1600) {
                sim.triggerShockwave(1.0);
                lastShockwaveTime = now;
            }

            // 3. INVERSIONES NEGATIVAS EN PICOS DE MÁXIMA INTENSIDAD
            if (bands.bass > 0.84 && (now - lastInvertTime) > 2200) {
                sim.triggerInvert(1.0);
                lastInvertTime = now;
            }

            // 4. GLITCH METRÓNOMO EN LAS RIMAS RÁPIDAS
            if ((bands.high > 0.68 || (isRapping && bands.mid > 0.72)) && (now - lastGlitchTime) > 1400) {
                sim.triggerGlitch(0.80);
                lastGlitchTime = now;
            }

            // 5. ROTACIÓN CROMÁTICA CADA 12 SEGUNDOS
            if ((now - lastPaletteChange) > 12000) {
                currentPaletteIndex = (currentPaletteIndex + 1) % 3;
                sim.setPalette(currentPaletteIndex);
                sim.triggerGlitch(0.4);
                lastPaletteChange = now;
            }

            // 6. METAMORFOSIS NORMAL SEGÚN LA EVOLUCIÓN MUSICAL
            const morphCooldown = isRapping ? 3000 : 4500; // En rap las formas cambian más rápido
            if ((now - lastMorphTime) > morphCooldown) {
                const isDropOrBreak = (bands.bass > 0.68) || (instantEnergy < 0.12 && (now - lastMorphTime) > 5500);
                if (isDropOrBreak || (now - lastMorphTime) > 7500) {
                    const nextTopo = getNextTopology(isRapping, instantEnergy);
                    sim.morphTo(nextTopo.params, nextTopo.vortex);
                    lastMorphTime = now;
                }
            }
        }

        sim.draw(bands);
        requestAnimationFrame(animate);
    }

    requestAnimationFrame(animate);
}

init().catch(console.error);