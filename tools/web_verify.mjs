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
  if (m.method === "Runtime.consoleAPICalled") {
    const txt = (m.params.args || []).map((a) => a.value ?? a.description ?? "").join(" ");
    if (txt.trim()) console.log("[godot]", txt.slice(0, 200));
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

// 1) 主菜单 + 角色选择（无参数导航才会停在菜单：?enemies=1 会自动开局跳过菜单）
await boot(`${BASE}`);
await shot("01_menu");
await click(120, 115);   // 「开始游戏」按钮本体（菜单列 x32~208）
await sleep(1600);
await shot("02_select");
await boot(`${BASE}?enemies=1`);
await click(320, 144);
await sleep(1500);

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

// 2.5) M4：HUD 全要素（左上状态/技能/地图/挑战条，战斗页即得）
await shot("13_hud");

// 3) M2+M3：末波保底精英页（?enemies=1&lastwave=1，main.gd 通道直接开局）
//    先拍精英定格，再读钩子暴露的 window.__elite_pos 瞄准精英连拍击杀帧——
//    精英死亡走 M3 升级路径（hit_stop 0.12 + 方向震屏）。
//    注意 pt() 的鼠标落点 = world(gx, gy+100)：相机被房间下限钳住产生 +100 偏移。
await boot(`${BASE}?enemies=1&lastwave=1`);
await shot("06_final_wave_elite");
{
  const ep = await send("Runtime.evaluate", { expression: "window.__elite_pos || ''", returnByValue: true });
  const parts = String((ep.result && ep.result.value) || "").split(",");
  if (parts.length === 2 && Number(parts[0]) > 0) {
    await click(450, 150);   // 空地先点一下：canvas 抓焦点，后续按住开火才生效
    await sleep(250);
    const p = pt(Number(parts[0]), Number(parts[1]) - 100);
    await send("Input.dispatchMouseEvent", { type: "mouseMoved", x: p.x, y: p.y });
    await sleep(150);
    await send("Input.dispatchMouseEvent", { type: "mousePressed", x: p.x, y: p.y, button: "left", clickCount: 1 });
    await sleep(600);
    await shot("11_kill_before");
    for (let i = 0; i < 10; i++) {
      await sleep(150);
      await shot(`12_kill_frame_${i + 1}`);
    }
    await send("Input.dispatchMouseEvent", { type: "mouseReleased", x: p.x, y: p.y, button: "left", clickCount: 1 });
    await sleep(300);
  } else {
    console.log("[warn] no __elite_pos, skip kill frames");
  }
}

// 3b) M2：清场金币雨 / "+1" 拾取飘字（?enemies=1&coinrain=1，钩子演示走位）

// 3b) 金币雨：清场金币雨散落一地；置 window.__coinrain_go=1 后由钩子自动走位
//     穿过币堆（磁吸飞入），停步点旁补近距金币触发 "+1" 飘字，三张连拍
await boot(`${BASE}?enemies=1&coinrain=1`);
await shot("07_coin_rain");
await send("Runtime.evaluate", { expression: "window.__coinrain_go = 1" });
await sleep(1300);
await shot("08_coin_pickup_1");
await sleep(900);
await shot("09_coin_pickup_2");
await sleep(1000);
await shot("10_coin_pickup_3");

// 5) M4：数据学园商店（?enemies=1&shop=1 直达：白卡 + 展台 + 共鸣脉冲辉光）
await boot(`${BASE}?enemies=1&shop=1`);
await shot("14_shop");

ws.close();
chrome.kill();
process.exit(0);
