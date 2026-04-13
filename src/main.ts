import { createApp } from "vue";
import { createPinia } from "pinia";
import ElementPlus from "element-plus";
import "element-plus/dist/index.css";
import { i18n } from "./i18n";
import App from "./App.vue";
import "./assets/styles/tailwind.css";
import "./assets/styles/monitor.css";
import "./assets/styles/fonts.css";
import "./assets/styles/pane.css";

// Set platform class before mount for CSS layout
const platform = navigator.platform.toUpperCase();
if (platform.includes("MAC")) document.documentElement.classList.add("platform-macos");
else if (platform.includes("WIN")) document.documentElement.classList.add("platform-windows");
else document.documentElement.classList.add("platform-linux");

// Global error handler — surfaces unhandled errors that would otherwise silently
// break reactivity/event handling (especially helpful on Windows where devtools
// are harder to access in production builds).
window.addEventListener("error", (e) => {
  console.error("[Termex] Unhandled error:", e.error);
});
window.addEventListener("unhandledrejection", (e) => {
  console.error("[Termex] Unhandled promise rejection:", e.reason);
});

const app = createApp(App);

app.config.errorHandler = (err, _instance, info) => {
  console.error(`[Termex] Vue error (${info}):`, err);
};

app.use(createPinia());
app.use(ElementPlus);
app.use(i18n);
app.mount("#app");
