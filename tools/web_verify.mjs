// Web 版验收：主菜单 -> 角色选择 -> 开局 -> 三把武器实弹 -> 9 种敌人同屏
// 用法：node tools/web_verify.mjs [输出目录]
import { spawn } from "node:child_process";
import fs from "node:fs";
import path from "node:path";

const OUT = process.argv[2] || "D:/DevTools/cache/temp/webv";
const BASE = "http://127.0.0.1:8765/index.html";
const CHROME = "C:/Program Files/Google/Chrome/Application/chrome.exe";
const PORT = 9335;
fs.mkdirSync(OUT, { recursive: true });

const chrome = spawn(CHROME, [
  "--headless=new", `--remote-debugging-port=${PORT}`,
  "--enable-unsafe-swiftshader", "--use-gl=angle", "--use-angle=swiftshader",
  "--no-sandbox", "--disable-gpu-sandbox", "--window-size=1280,720",
  "--hide-scrollbars", "about:blank",
], { stdio: "ignore" });

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function getWs() {
  for (let i = 0; i < 40; i++) {
    try {
      const list = await (await fetch(`http://127.0.0.1:${PORT}/json/list`)).json();
      const page = list.find((t) => t.type === "page");
      if (page) return page.webSocketDebuggerUrl;
    } catch {}
    await sleep(250);
  }
  throw new Error("devtools not ready");
}

const ws = new WebSocket(await getWs());
let id = 0;
const pending = new Map();
ws.addEventListener("message", (ev) => {
  const m = JSON.parse(ev.data);
  if (m.id && pending.has(m.id)) { pending.get(m.id)(m.result); pending.delete(m.id); }
  if (m.method === "Runtime.exceptionThrown") {
    console.log("[error]", JSON.stringify(m.params.exceptionDetails).slice(0, 260));
  }
});
await new Promise((r) => ws.addEventListener("open", r));
const send = (method, params = {}) => new Promise((res) => {
  const mid = ++id;
  pending.set(mid, res);
  ws.send(JSON.stringify({ id: mid, method, params }));
});

await send("Page.enable");
await send("Runtime.enable");
await send("Emulation.setDeviceMetricsOverride", {
  width: 1280, height: 720, deviceScaleFactor: 1, mobile: false,
});

let rect = { x: 0, y: 0, w: 1280, h: 720 };
const pt = (gx, gy) => ({ x: rect.x + (gx / 640) * rect.w, y: rect.y + (gy / 360) * rect.h });

async function click(gx, gy) {
  const p = pt(gx, gy);
  await send("Input.dispatchMouseEvent", { type: "mouseMoved", x: p.x, y: p.y });
  await sleep(100);
  await send("Input.dispatchMouseEvent", { type: "mousePressed", x: p.x, y: p.y, button: "left", clickCount: 1 });
  await sleep(80);
  await send("Input.dispatchMouseEvent", { type: "mouseReleased", x: p.x, y: p.y, button: "left", clickCount: 1 });
}

async function fireShot(gx, gy, name) {
  const p = pt(gx, gy);
  await send("Input.dispatchMouseEvent", { type: "mouseMoved", x: p.x, y: p.y });
  await sleep(150);
  await send("Input.dispatchMouseEvent", { type: "mousePressed", x: p.x, y: p.y, button: "left", clickCount: 1 });
  await sleep(180);
  await shot(name);
  await sleep(700);
  await send("Input.dispatchMouseEvent", { type: "mouseReleased", x: p.x, y: p.y, button: "left", clickCount: 1 });
}

async function shot(name) {
  const r = await send("Page.captureScreenshot", { format: "png" });
  fs.writeFileSync(path.join(OUT, `${name}.png`), Buffer.from(r.data, "base64"));
  console.log("shot", name);
}

async function boot(url) {
  await send("Page.navigate", { url });
  await sleep(13000);
  const rr = await send("Runtime.evaluate", {
    expression: `(() => { const c = document.querySelector("canvas"); const r = c.getBoundingClientRect();
      return JSON.stringify({x:r.x,y:r.y,w:r.width,h:r.height}); })()`,
    returnByValue: true,
  });
  rect = JSON.parse(rr.result.value);
}

// 1) 主菜单 + 角色选择
await boot(`${BASE}?enemies=1`);
await shot("01_menu");
await click(320, 144);
await sleep(1600);
await shot("02_select");

// 2) 三个角色各打一次
const cards = [[204, "deepseek"], [320, "gpt"], [436, "claude"]];
for (const [cx, name] of cards) {
  await click(cx, 170);
  await sleep(350);
  await click(560, 330);
  await sleep(2400);
  // 跳过开场对白
  for (let i = 0; i < 9; i++) { await click(420, 150); await sleep(280); }
  await sleep(3200);
  await shot(`03_${name}_enemies`);
  await fireShot(450, 150, `04_${name}_fire`);
  if (name === "deepseek") {
    // ESC 暂停菜单
    await send("Input.dispatchKeyEvent", { type: "keyDown", key: "Escape", code: "Escape", windowsVirtualKeyCode: 27 });
    await send("Input.dispatchKeyEvent", { type: "keyUp", key: "Escape", code: "Escape", windowsVirtualKeyCode: 27 });
    await sleep(700);
    await shot("05_pause");
    await send("Input.dispatchKeyEvent", { type: "keyDown", key: "Escape", code: "Escape", windowsVirtualKeyCode: 27 });
    await send("Input.dispatchKeyEvent", { type: "keyUp", key: "Escape", code: "Escape", windowsVirtualKeyCode: 27 });
    await sleep(400);
  }
  // 回主菜单：ESC 打开设置再退出太绕，直接重载
  await boot(`${BASE}?enemies=1`);
  await click(320, 144);
  await sleep(1500);
}

ws.close();
chrome.kill();
process.exit(0);
