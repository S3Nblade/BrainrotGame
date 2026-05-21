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
const npcImage = document.querySelector("#npcImage");
const rarity = document.querySelector("#rarity");
const mutation = document.querySelector("#mutation");
const isNew = document.querySelector("#isNew");
const sparkleLayer = reveal.querySelector(".sparkles");

const mutationColors = {
  Diamond: "#70d9ff",
  Radioactive: "#9bff45",
  Gold: "#ffd24a",
  Rainbow: "#ff7af2",
  Shadow: "#9b8cff",
  Normal: "#dfe6f3",
};

function buildSparkles() {
  sparkleLayer.replaceChildren();
  for (let i = 0; i < 12; i += 1) {
    const sparkle = document.createElement("span");
    sparkle.className = "sparkle";
    const angle = (Math.PI * 2 * i) / 12;
    const distance = 94 + (i % 4) * 18;
    const x = Math.cos(angle) * distance;
    const y = Math.sin(angle) * distance * 0.76;
    const size = 22 + (i % 4) * 6;
    sparkle.style.setProperty("--x", `${x}px`);
    sparkle.style.setProperty("--y", `${y}px`);
    sparkle.style.setProperty("--size", `${size}px`);
    sparkle.style.setProperty("--scale", `${0.86 + (i % 3) * 0.1}`);
    sparkle.style.setProperty("--delay", `${1.9 + i * 0.022}s`);
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
  const selectedMutation = mutation.value;
  const color = rarityColors[selectedRarity] || rarityColors.Common;
  const mutationColor = mutationColors[selectedMutation] || mutationColors.Normal;
  reveal.style.setProperty("--rarity", color);
  reveal.style.setProperty("--mutation", mutationColor);
  reveal.dataset.rarity = selectedRarity;
  reveal.querySelector(".npc-name").textContent = npcName.value || "Mystery NPC";
  reveal.querySelector(".mutation-label").textContent =
    selectedMutation === "Normal" ? "Normal" : `${selectedMutation} Mutation`;
  const preview = reveal.querySelector(".npc-preview");
  const image = reveal.querySelector(".npc-image");
  if (npcImage.value.trim()) {
    image.src = npcImage.value.trim();
    preview.classList.add("has-image");
  } else {
    image.removeAttribute("src");
    preview.classList.remove("has-image");
  }
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
