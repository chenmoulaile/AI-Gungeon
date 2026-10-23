// Web 版流程自检：无头 Chrome 依次点击 主菜单 -> 角色选择 -> 开局，并逐张截图
// 用法：node tools/web_flow.mjs [输出目录]
import { spawn } from "node:child_process";
import fs from "node:fs";
import path from "node:path";

const OUT = process.argv[2] || "D:/DevTools/cache/temp/flow";
const URL_PAGE = "http://127.0.0.1:8765/index.html";
const CHROME = "C:/Program Files/Google/Chrome/Application/chrome.exe";
const PORT = 9334;

fs.mkdirSync(OUT, { recursive: true });

const chrome = spawn(CHROME, [
  "--headless=new",
  `--remote-debugging-port=${PORT}`,
  "--enable-unsafe-swiftshader",
  "--use-gl=angle",
  "--use-angle=swiftshader",
  "--no-sandbox",
  "--disable-gpu-sandbox",
  "--window-size=1280,720",
  "--hide-scrollbars",
  "about:blank",
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
    console.log("[error]", JSON.stringify(m.params.exceptionDetails).slice(0, 300));
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
await send("Page.navigate", { url: URL_PAGE });
await sleep(14000);

const rectRes = await send("Runtime.evaluate", {
  expression: `(() => { const c = document.querySelector("canvas");
    const r = c.getBoundingClientRect();
    return JSON.stringify({x:r.x, y:r.y, w:r.width, h:r.height}); })()`,
  returnByValue: true,
});
const rect = JSON.parse(rectRes.result.value);
console.log("canvas", rect);

// 游戏内坐标 -> 页面坐标
const pt = (gx, gy) => ({
  x: rect.x + (gx / 640) * rect.w,
  y: rect.y + (gy / 360) * rect.h,
});

async function click(gx, gy) {
  const p = pt(gx, gy);
  await send("Input.dispatchMouseEvent", { type: "mouseMoved", x: p.x, y: p.y });
  await sleep(120);
  await send("Input.dispatchMouseEvent", {
    type: "mousePressed", x: p.x, y: p.y, button: "left", clickCount: 1,
  });
  await sleep(90);
  await send("Input.dispatchMouseEvent", {
    type: "mouseReleased", x: p.x, y: p.y, button: "left", clickCount: 1,
  });
}

async function shot(name) {
  const r = await send("Page.captureScreenshot", { format: "png" });
  fs.writeFileSync(path.join(OUT, `${name}.png`), Buffer.from(r.data, "base64"));
  console.log("shot", name);
}

await shot("01_menu");
await click(320, 211);        // 开始游戏
await sleep(1600);
await shot("02_select");
await click(160, 170);        // 第一张卡片
await sleep(400);
await click(320, 305);        // 开始游戏（卡片下方大按钮）
await sleep(2200);
await shot("03_battle");

// 跳过 4 句开场对白
for (let i = 0; i < 8; i++) {
  await click(420, 150);
  await sleep(320);
}
await sleep(600);
await shot("04_battle_idle");

// 移动 + 射击：键盘事件走 Input.dispatchKeyEvent
async function key(code, keyCode, down) {
  await send("Input.dispatchKeyEvent", {
    type: down ? "keyDown" : "keyUp",
    code,
    windowsVirtualKeyCode: keyCode,
    nativeVirtualKeyCode: keyCode,
    key: code,
  });
}
await key("KeyD", 68, true);
await sleep(700);
await key("KeyD", 68, false);
await key("KeyW", 87, true);
await sleep(300);
await key("KeyW", 87, false);
await sleep(400);
await shot("05_battle_moved");

await send("Input.dispatchMouseEvent", { type: "mouseMoved", x: 900, y: 300 });
await send("Input.dispatchMouseEvent", {
  type: "mousePressed", x: 900, y: 300, button: "left", clickCount: 1,
});
await sleep(900);
await shot("06_battle_shoot");
await send("Input.dispatchMouseEvent", {
  type: "mouseReleased", x: 900, y: 300, button: "left", clickCount: 1,
});
await sleep(300);
await shot("07_after_shoot");

ws.close();
chrome.kill();
process.exit(0);
