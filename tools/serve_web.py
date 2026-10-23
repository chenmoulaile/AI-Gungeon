#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""本地预览 Godot Web 导出（不开游戏窗口，只在浏览器里跑）。

用法：
    python tools/serve_web.py            # 默认 http://127.0.0.1:8765
    python tools/serve_web.py 9000       # 指定端口

说明：即使关闭了线程（thread_support=false），仍然带上 COOP/COEP 头，
方便以后开启线程时不用改服务器。
"""

import functools
import http.server
import os
import socketserver
import sys

ROOT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "build", "web")


class Handler(http.server.SimpleHTTPRequestHandler):
    extensions_map = {
        **http.server.SimpleHTTPRequestHandler.extensions_map,
        ".wasm": "application/wasm",
        ".pck": "application/octet-stream",
        ".js": "text/javascript",
        ".mjs": "text/javascript",
    }

    def end_headers(self):
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.send_header("Cache-Control", "no-store")
        super().end_headers()

    def log_message(self, fmt, *args):
        sys.stderr.write("%s - %s\n" % (self.address_string(), fmt % args))


def main():
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8765
    if not os.path.isdir(ROOT):
        print("找不到 %s，请先导出 Web 版本：" % ROOT)
        print('  godot --headless --path . --export-release "Web" build/web/index.html')
        return 1
    socketserver.TCPServer.allow_reuse_address = True
    with socketserver.TCPServer(("127.0.0.1", port),
                                functools.partial(Handler, directory=ROOT)) as httpd:
        print("serving %s at http://127.0.0.1:%d/index.html" % (ROOT, port))
        httpd.serve_forever()
    return 0


if __name__ == "__main__":
    sys.exit(main())
