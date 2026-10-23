// 在浏览器里跑一段战斗并统计帧率（不需要打开游戏窗口）
// 用法：node tools/web_perf.mjs
import pw from "file:///C:/Users/Chenkx/.workbuddy-ai/binaries/node/workspace/node_modules/playwright-core/index.js";
const { chromium } = pw;

const CHROME = "C:/Program Files/Google/Chrome/Application/chrome.exe";

const browser = await chromium.launch({
  executablePath: CHROME,
  headless: true,
  args: ["--enable-gpu", "--use-angle=d3d11", "--ignore-gpu-blocklist", "--no-sandbox"],
});
const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
page.on("console", (m) => {
  const t = m.text();
  if (t.includes("[pick]") || t.includes("FPS")) console.log("[console]", t);
});

await page.goto("http://127.0.0.1:8765/index.html", { waitUntil: "load", timeout: 90000 });
for (let i = 0; i < 40; i++) {
  const ok = await page.evaluate(() => {
    const c = document.querySelector("canvas");
    return !!c && c.width > 100;
  });
  if (ok) break;
  await page.waitForTimeout(1000);
}
await page.waitForTimeout(4000);

await page.mouse.click(20, 20);
await page.keyboard.press("1");
await page.waitForTimeout(1500);
for (let i = 0; i < 8; i++) {
  await page.keyboard.press("Space");
  await page.waitForTimeout(200);
}
await page.waitForTimeout(1200);

// 战斗中持续开火 + 移动
await page.mouse.move(900, 360);
await page.mouse.down();
await page.keyboard.down("KeyD");
await page.waitForTimeout(1200);
await page.keyboard.up("KeyD");

const stats = await page.evaluate(() => {
  return new Promise((res) => {
    const deltas = [];
    let last = performance.now();
    const t0 = last;
    const tick = (now) => {
      deltas.push(now - last);
      last = now;
      if (now - t0 < 4000) requestAnimationFrame(tick);
      else {
        deltas.sort((a, b) => a - b);
        const avg = deltas.reduce((s, d) => s + d, 0) / deltas.length;
        const p99 = deltas[Math.floor(deltas.length * 0.99)] || deltas[deltas.length - 1];
        res({
          frames: deltas.length,
          avg_fps: 1000 / avg,
          worst_p99_ms: p99,
          max_ms: deltas[deltas.length - 1],
        });
      }
    };
    requestAnimationFrame(tick);
  });
});
await page.mouse.up();
console.log("PERF", JSON.stringify(stats));
await browser.close();
