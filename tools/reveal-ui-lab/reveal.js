const rarityColors = {
  Common: "#eef2f8",
  Rare: "#48afff",
  Epic: "#be5aff",
  Legendary: "#ffbd2c",
  Mythic: "#ff4c94",
  Secret: "#48ffb0",
  Huge: "#ffe052",
};

const reveal = document.querySelector("#reveal");
const playButton = document.querySelector("#playButton");
const npcName = document.querySelector("#npcName");
const rarity = document.querySelector("#rarity");
const isNew = document.querySelector("#isNew");
const sparkleLayer = reveal.querySelector(".sparkles");

function buildSparkles() {
  sparkleLayer.replaceChildren();
  for (let i = 0; i < 18; i += 1) {
    const sparkle = document.createElement("span");
    sparkle.className = "sparkle";
    const angle = (Math.PI * 2 * i) / 18;
    const distance = 116 + (i % 4) * 22;
    const x = Math.cos(angle) * distance;
    const y = Math.sin(angle) * distance * 0.76;
    sparkle.style.setProperty("--x", `${x}px`);
    sparkle.style.setProperty("--y", `${y}px`);
    sparkle.style.setProperty("--delay", `${1.98 + i * 0.025}s`);
    sparkleLayer.appendChild(sparkle);
  }
}

function closeReveal() {
  reveal.classList.remove("is-playing");
  reveal.classList.add("is-closing");
  window.setTimeout(() => {
    reveal.classList.remove("is-closing");
  }, 260);
}

function playReveal() {
  const selectedRarity = rarity.value;
  const color = rarityColors[selectedRarity] || rarityColors.Common;
  reveal.style.setProperty("--rarity", color);
  reveal.dataset.rarity = selectedRarity;
  reveal.querySelector(".rarity-label").textContent = selectedRarity;
  reveal.querySelector(".npc-name").textContent = npcName.value || "Mystery NPC";
  reveal.classList.toggle("has-new", isNew.checked);
  reveal.classList.remove("is-playing", "is-closing");
  void reveal.offsetWidth;
  buildSparkles();
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
