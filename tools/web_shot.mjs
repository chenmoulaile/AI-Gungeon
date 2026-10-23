// Web 版自检截图：用本机 Chrome 无头模式打开本地服务器页面并截图
// 用法：node tools/web_shot.mjs [outPrefix]
import pw from "file:///C:/Users/Chenkx/.workbuddy-ai/binaries/node/workspace/node_modules/playwright-core/index.js";
const { chromium } = pw;

const OUT = process.argv[2] || "tests/_web";
const URL = "http://127.0.0.1:8765/index.html";

const CHROME = "C:/Program Files/Google/Chrome/Application/chrome.exe";
const EDGE = "C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe";

const browser = await chromium.launch({
  executablePath: CHROME,
  headless: true,
  args: [
    "--use-gl=angle",
    "--use-angle=swiftshader",
    "--enable-unsafe-swiftshader",
    "--disable-gpu-sandbox",
    "--no-sandbox",
  ],
});

const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
page.on("console", (m) => {
  const t = m.text();
  if (!t.includes("Deprecation")) console.log("[console]", m.type(), t.slice(0, 300));
});
page.on("pageerror", (e) => console.log("[pageerror]", e.message));

await page.goto(URL, { waitUntil: "load", timeout: 90000 });
// 等 Godot 启动（wasm 42MB，首次加载会久一点）
for (let i = 0; i < 40; i++) {
  const ready = await page.evaluate(() => {
    const c = document.querySelector("canvas");
    return !!c && c.width > 100;
  });
  if (ready) break;
  await page.waitForTimeout(1000);
}
await page.waitForTimeout(6000);
await page.screenshot({ path: `${OUT}_select.png` });
console.log("shot select");

// 图鉴
await page.mouse.click(20, 20);
await page.keyboard.press("c");
await page.waitForTimeout(1200);
await page.screenshot({ path: `${OUT}_collection.png` });
console.log("shot collection");
await page.keyboard.press("c");
await page.waitForTimeout(800);

// 先点画布拿焦点，再按 1 选 DeepSeek（比点卡片稳）
await page.mouse.click(20, 20);
await page.waitForTimeout(300);
await page.keyboard.press("1");
await page.waitForTimeout(2500);
await page.screenshot({ path: `${OUT}_dialog.png` });
console.log("shot dialog");

// 跳过对话：按空格（每句两下：补全 -> 下一句）
for (let i = 0; i < 8; i++) {
  await page.keyboard.press("Space");
  await page.waitForTimeout(240);
}
await page.waitForTimeout(1500);
// 往右走一点，让相机居中
await page.keyboard.down("KeyD");
await page.waitForTimeout(900);
await page.keyboard.up("KeyD");
await page.waitForTimeout(600);
await page.screenshot({ path: `${OUT}_battle.png` });
console.log("shot battle");

// 开火 1.2s
await page.mouse.move(900, 360);
await page.mouse.down();
await page.waitForTimeout(1400);
await page.screenshot({ path: `${OUT}_shoot.png` });
await page.mouse.up();
console.log("shot shoot");

const fps = await page.evaluate(() => {
  return new Promise((res) => {
    let n = 0;
    const t0 = performance.now();
    const tick = () => {
      n++;
      if (performance.now() - t0 < 2000) requestAnimationFrame(tick);
      else res((n / (performance.now() - t0)) * 1000);
    };
    requestAnimationFrame(tick);
  });
});
console.log("approx_fps", fps.toFixed(1));

await browser.close();
