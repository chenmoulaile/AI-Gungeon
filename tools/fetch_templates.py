"""从 GitHub Release 资源中按 Range 只抓取需要的导出模板文件。

背景：完整 export_templates.tpz 有 1.2GB，但 Web 导出只需要里面的 templates/web_release.zip。
本脚本先取 zip 尾部中央目录，再按偏移量精确抓取目标条目并解压。

用法：
  python tools/fetch_templates.py web
  python tools/fetch_templates.py windows linux
"""

import io
import json
import os
import struct
import subprocess
import sys
import urllib.request
import zipfile
import zlib

ASSET_ID = 519686380
ASSET_NAME = "Godot_v4.7.2-stable_export_templates.tpz"
VERSION_DIR = "4.7.2.stable"
API = f"https://api.github.com/repos/godotengine/godot/releases/assets/{ASSET_ID}"

TARGETS = {
    "web": ["templates/web_nothreads_release.zip", "templates/web_nothreads_debug.zip"],
    "webthreads": ["templates/web_release.zip"],
    "windows": ["templates/windows_release_x86_64.exe"],
    "linux": ["templates/linux_release.x86_64"],
}


def signed_url() -> str:
    out = subprocess.run(
        ["curl", "-sI", "-H", "Accept: application/octet-stream", API],
        capture_output=True, text=True, timeout=60,
    ).stdout
    for line in out.splitlines():
        if line.lower().startswith("location:"):
            return line.split(":", 1)[1].strip()
    raise RuntimeError("no location header")


def fetch(url: str, start: int, end: int) -> bytes:
    req = urllib.request.Request(url, headers={"Range": f"bytes={start}-{end}"})
    with urllib.request.urlopen(req, timeout=120) as r:
        return r.read()


def template_dir() -> str:
    base = os.environ.get("APPDATA") or os.path.expanduser("~/.local/share")
    if os.name == "nt":
        path = os.path.join(base, "Godot", "export_templates", VERSION_DIR)
    else:
        path = os.path.join(base, "godot", "export_templates", VERSION_DIR)
    os.makedirs(path, exist_ok=True)
    return path


def main() -> None:
    kinds = sys.argv[1:] or ["web"]
    url = signed_url()
    total = 1281349702

    tail_start = total - 262144
    tail = fetch(url, tail_start, total - 1)
    eocd = tail.rfind(b"PK\x05\x06")
    if eocd < 0:
        raise RuntimeError("EOCD not found")
    cd_size, cd_off = struct.unpack("<II", tail[eocd + 12:eocd + 20])
    cd = fetch(url, cd_off, cd_off + cd_size - 1)

    entries = {}
    i = 0
    while i < len(cd) - 4 and cd[i:i + 4] == b"PK\x01\x02":
        (name_len, extra_len, comment_len) = struct.unpack("<HHH", cd[i + 28:i + 34])
        comp_size, uncomp_size = struct.unpack("<II", cd[i + 20:i + 28])
        method = struct.unpack("<H", cd[i + 10:i + 12])[0]
        local_off = struct.unpack("<I", cd[i + 42:i + 46])[0]
        name = cd[i + 46:i + 46 + name_len].decode("utf-8", "ignore")
        entries[name] = (local_off, comp_size, uncomp_size, method)
        i += 46 + name_len + extra_len + comment_len

    out_dir = template_dir()
    print("templates ->", out_dir)
    wanted = []
    for k in kinds:
        wanted += TARGETS.get(k, [])
    for name in wanted:
        if name not in entries:
            print("missing in archive:", name)
            continue
        off, csize, usize, method = entries[name]
        head = fetch(url, off, off + 29)
        nlen, elen = struct.unpack("<HH", head[26:30])
        data_start = off + 30 + nlen + elen
        print(f"fetching {name}: {csize/1048576:.1f} MB ...")
        raw = fetch(url, data_start, data_start + csize - 1)
        if method == 8:
            raw = zlib.decompress(raw, -15)
        dst = os.path.join(out_dir, os.path.basename(name))
        with open(dst, "wb") as f:
            f.write(raw)
        print("wrote", dst, len(raw))


if __name__ == "__main__":
    main()
