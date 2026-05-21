const reveal = document.querySelector("#reveal");
const playButton = document.querySelector("#playButton");
const mutation = document.querySelector("#mutation");
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
    sparkle.style.setProperty("--delay", `${2.95 + i * 0.024}s`);
    sparkleLayer.appendChild(sparkle);
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
  reveal.style.setProperty("--mutation", mutationColor);
  reveal.querySelector(".mutation-label").textContent =
    selectedMutation === "Normal" ? "Normal" : `${selectedMutation} Mutation`;
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
