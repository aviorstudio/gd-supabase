import { spawn } from "node:child_process";
import { mkdir } from "node:fs/promises";
import { chromium } from "playwright";

const webRoot = new URL("../dist/web/", import.meta.url);
const port = "8795";
const server = spawn("python3", ["-m", "http.server", port, "--bind", "127.0.0.1", "--directory", webRoot.pathname], {
  stdio: ["ignore", "pipe", "pipe"],
});

const sleep = (milliseconds) => new Promise((resolve) => setTimeout(resolve, milliseconds));
let browser;
try {
  await sleep(500);
  browser = await chromium.launch({ headless: true });
  const page = await browser.newPage({ viewport: { width: 800, height: 450 } });
  page.on("console", (message) => console.log(`BROWSER_${message.type().toUpperCase()}:${message.text()}`));
  const reached = page.waitForEvent("console", {
    predicate: (message) => message.text() === "PACKAGE_SMOKE_REACHED:PASS",
    timeout: 30_000,
  });
  await page.goto(`http://127.0.0.1:${port}/index.html`, { waitUntil: "domcontentloaded" });
  await reached;
  await mkdir(new URL("../dist/", import.meta.url), { recursive: true });
  await page.screenshot({ path: new URL("../dist/web-evidence.png", import.meta.url).pathname });
  console.log("WEB_TEST_REACHED:packaged-addon-smoke");
} finally {
  await browser?.close();
  server.kill("SIGTERM");
}
