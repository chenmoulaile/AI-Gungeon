// Web 版自检：无头 Chrome 打开本地服务器页面，等真实时间后截图
// 用法：node tools/web_shot.mjs [输出前缀] [等待秒数]
import { spawn } from "node:child_process";
import fs from "node:fs";
import path from "node:path";

const OUT = process.argv[2] || "D:/DevTools/cache/temp/web";
const WAIT = Number(process.argv[3] || 12);
const URL_PAGE = "http://127.0.0.1:8765/index.html";
const CHROME = "C:/Program Files/Google/Chrome/Application/chrome.exe";
const PORT = 9333;

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
      const res = await fetch(`http://127.0.0.1:${PORT}/json/list`);
      const list = await res.json();
      const page = list.find((t) => t.type === "page");
      if (page) return page.webSocketDebuggerUrl;
    } catch {}
    await sleep(250);
  }
  throw new Error("chrome devtools not ready");
}

const wsUrl = await getWs();
const ws = new WebSocket(wsUrl);
let id = 0;
const pending = new Map();

ws.addEventListener("message", (ev) => {
  const msg = JSON.parse(ev.data);
  if (msg.id && pending.has(msg.id)) {
    pending.get(msg.id)(msg.result);
    pending.delete(msg.id);
  }
  if (msg.method === "Runtime.consoleAPICalled") {
    const args = (msg.params.args || []).map((a) => a.value ?? a.description ?? "").join(" ");
    if (args && !args.includes("Deprecation")) console.log("[console]", args.slice(0, 240));
  }
  if (msg.method === "Runtime.exceptionThrown") {
    console.log("[error]", JSON.stringify(msg.params.exceptionDetails).slice(0, 400));
  }
});

await new Promise((r) => ws.addEventListener("open", r));

function send(method, params = {}) {
  return new Promise((resolve) => {
    const mid = ++id;
    pending.set(mid, resolve);
    ws.send(JSON.stringify({ id: mid, method, params }));
  });
}

await send("Page.enable");
await send("Runtime.enable");
await send("Emulation.setDeviceMetricsOverride", {
  width: 1280, height: 720, deviceScaleFactor: 1, mobile: false,
});
await send("Page.navigate", { url: URL_PAGE });
await sleep(WAIT * 1000);

const shot = await send("Page.captureScreenshot", { format: "png" });
fs.mkdirSync(path.dirname(OUT), { recursive: true });
fs.writeFileSync(`${OUT}.png`, Buffer.from(shot.data, "base64"));
console.log("saved", `${OUT}.png`);

ws.close();
chrome.kill();
process.exit(0);
