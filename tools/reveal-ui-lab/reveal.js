const reveal = document.querySelector("#reveal");
const playButton = document.querySelector("#playButton");
const mutation = document.querySelector("#mutation");
const npcName = document.querySelector("#npcName");
const npcImage = document.querySelector("#npcImage");
const sparkleLayer = reveal.querySelector(".sparkles");
const effectLayer = reveal.querySelector(".mutation-effects");

const mutationColors = {
  Diamond: "#70d9ff",
  Radioactive: "#9bff45",
  Gold: "#ffd24a",
  Rainbow: "#ff7af2",
  Shadow: "#9b8cff",
  Normal: "#dfe6f3",
};

const mutationSpeeds = {
  Normal: 0.55,
  Gold: 0.72,
  Diamond: 0.82,
  Radioactive: 0.92,
  Rainbow: 1.02,
  Shadow: 1.12,
};

const baseTiming = {
  stageIn: 260,
  glowDuration: 1200,
  glowDelay: 220,
  crackDuration: 360,
  crackDelay: 1650,
  shellDuration: 520,
  shellDelay: 2920,
  flashDuration: 360,
  flashDelay: 2900,
  eggIntro: 280,
  eggSideDuration: 820,
  eggSideDelay: 300,
  eggFinalDuration: 520,
  eggFinalDelay: 2450,
  eggFadeDuration: 180,
  eggFadeDelay: 3320,
  sparkleDuration: 500,
  npcDuration: 360,
  npcDelay: 3320,
  textDuration: 260,
  textDelay: 3480,
};

function setTiming(speed) {
  for (const [name, value] of Object.entries(baseTiming)) {
    const cssName = name.replace(/[A-Z]/g, (letter) => `-${letter.toLowerCase()}`);
    reveal.style.setProperty(`--${cssName}`, `${Math.round(value * speed)}ms`);
  }
}

function buildSparkles() {
  sparkleLayer.replaceChildren();
  const speed = Number(reveal.style.getPropertyValue("--reveal-speed")) || 1;
  for (let i = 0; i < 10; i += 1) {
    const sparkle = document.createElement("span");
    sparkle.className = "sparkle";
    const angle = (Math.PI * 2 * i) / 10;
    const distance = 86 + (i % 3) * 18;
    const x = Math.cos(angle) * distance;
    const y = Math.sin(angle) * distance * 0.72;
    const size = 20 + (i % 3) * 6;
    sparkle.style.setProperty("--x", `${x}px`);
    sparkle.style.setProperty("--y", `${y}px`);
    sparkle.style.setProperty("--size", `${size}px`);
    sparkle.style.setProperty("--scale", `${0.82 + (i % 3) * 0.1}`);
    sparkle.style.setProperty("--delay", `${(2.95 + i * 0.024) * speed}s`);
    sparkleLayer.appendChild(sparkle);
  }
}

function addEffect(className, angle, distance, size, delay, extra = {}) {
  const effect = document.createElement("span");
  effect.className = `mutation-effect ${className}`;
  const x = Math.cos(angle) * distance;
  const y = Math.sin(angle) * distance * 0.74;
  effect.style.setProperty("--x", `${x}px`);
  effect.style.setProperty("--y", `${y}px`);
  effect.style.setProperty("--size", `${size}px`);
  effect.style.setProperty("--delay", `${delay}s`);
  for (const [key, value] of Object.entries(extra)) {
    effect.style.setProperty(key, value);
  }
  effectLayer.appendChild(effect);
}

function addCenterEffect(className, size, delay, extra = {}) {
  addEffect(className, 0, 0, size, delay, extra);
}

function buildMutationEffects(selectedMutation) {
  effectLayer.replaceChildren();
  const speed = Number(reveal.style.getPropertyValue("--reveal-speed")) || 1;
  const earlyStart = 0.18 * speed;
  const midStart = 0.48 * speed;
  const revealStart = 2.95 * speed;

  if (selectedMutation === "Normal") {
    addCenterEffect("normal-pop", 108, revealStart - 0.08);
    for (let i = 0; i < 6; i += 1) {
      addEffect("normal-dot", (Math.PI * 2 * i) / 6, 88, 12, revealStart + i * 0.03);
    }
    return;
  }

  if (selectedMutation === "Diamond") {
    addCenterEffect("diamond-core", 128, earlyStart);
    addCenterEffect("impact-ring diamond-impact", 178, midStart + 0.18);
    for (let i = 0; i < 16; i += 1) {
      addEffect("diamond-shard", (Math.PI * 2 * i) / 16, 90 + (i % 4) * 20, 20 + (i % 2) * 10, midStart + i * 0.025, {
        "--spin": `${35 + i * 18}deg`,
      });
    }
    return;
  }

  if (selectedMutation === "Radioactive") {
    addCenterEffect("radio-core", 118, earlyStart);
    addCenterEffect("impact-ring radio-impact", 184, earlyStart + 0.14);
    for (let i = 0; i < 5; i += 1) {
      addEffect("radio-ring", 0, 0, 132 + i * 42, earlyStart + i * 0.16);
    }
    for (let i = 0; i < 16; i += 1) {
      addEffect("radio-dot", (Math.PI * 2 * i) / 16, 104 + (i % 3) * 22, 18, earlyStart + 0.05 + i * 0.025);
    }
    return;
  }

  if (selectedMutation === "Gold") {
    addCenterEffect("gold-sun", 130, earlyStart);
    addCenterEffect("impact-ring gold-impact", 186, midStart + 0.12);
    for (let i = 0; i < 12; i += 1) {
      addEffect("gold-coin", (Math.PI * 2 * i) / 12, 92 + (i % 4) * 16, 18, midStart + i * 0.026);
    }
    for (let i = 0; i < 5; i += 1) {
      addEffect("gold-streak", Math.PI * (0.2 + i * 0.16), 78 + i * 12, 52, midStart + 0.05 + i * 0.04);
    }
    return;
  }

  if (selectedMutation === "Rainbow") {
    addCenterEffect("rainbow-halo", 174, earlyStart);
    addCenterEffect("impact-ring rainbow-impact", 218, earlyStart + 0.12);
    for (let i = 0; i < 28; i += 1) {
      addEffect("rainbow-orb", (Math.PI * 2 * i) / 28, 96 + (i % 6) * 14, 19, earlyStart + i * 0.016, {
        "--hue": `${i * 22}deg`,
      });
    }
    for (let i = 0; i < 4; i += 1) {
      addEffect("rainbow-ring", 0, 0, 170 + i * 42, earlyStart + i * 0.14);
    }
    return;
  }

  if (selectedMutation === "Shadow") {
    addEffect("shadow-moon", -Math.PI / 3, 118, 86, earlyStart);
    addCenterEffect("shadow-eclipse", 148, earlyStart + 0.08);
    addCenterEffect("impact-ring shadow-impact", 204, earlyStart + 0.16);
    for (let i = 0; i < 24; i += 1) {
      addEffect("shadow-wisp", (Math.PI * 2 * i) / 24, 82 + (i % 5) * 18, 44 + (i % 4) * 12, earlyStart + i * 0.026, {
        "--spin": `${-25 + i * 11}deg`,
      });
    }
    for (let i = 0; i < 3; i += 1) {
      addEffect("shadow-ring", 0, 0, 148 + i * 52, earlyStart + i * 0.22);
    }
  }
}

function closeReveal() {
  reveal.classList.remove("is-playing");
  reveal.classList.add("is-closing");
  window.setTimeout(() => {
    reveal.classList.remove("is-closing");
  }, 240);
}

function playReveal() {
  const selectedMutation = mutation.value;
  const mutationColor = mutationColors[selectedMutation] || mutationColors.Normal;
  const speed = mutationSpeeds[selectedMutation] || 1;
  reveal.style.setProperty("--mutation", mutationColor);
  reveal.style.setProperty("--reveal-speed", speed);
  reveal.dataset.mutation = selectedMutation.toLowerCase();
  setTiming(speed);
  reveal.querySelector(".reward-label").textContent = `${selectedMutation} ${npcName.value || "Mystery NPC"}`;

  const picture = reveal.querySelector(".npc-picture");
  const image = reveal.querySelector(".npc-image");
  if (npcImage.value.trim()) {
    image.src = npcImage.value.trim();
    picture.classList.add("has-image");
  } else {
    image.removeAttribute("src");
    picture.classList.remove("has-image");
  }

  reveal.classList.remove("is-playing", "is-closing");
  void reveal.offsetWidth;
  buildSparkles();
  buildMutationEffects(selectedMutation);
  reveal.classList.add("is-playing");
}

playButton.addEventListener("click", playReveal);
reveal.addEventListener("click", () => {
  if (reveal.classList.contains("is-playing")) {
    closeReveal();
  }
});

buildSparkles();
playReveal();
