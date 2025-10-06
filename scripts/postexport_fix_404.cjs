// Copy out/index.html to out/404.html for SPA fallback on GitHub Pages
import { copyFileSync, existsSync } from "fs";
if (existsSync("out/index.html")) {
  copyFileSync("out/index.html", "out/404.html");
  console.log("Created out/404.html for SPA routing fallback.");
} else {
  console.error("out/index.html not found. Did you run next export?");
  process.exit(1);
}
