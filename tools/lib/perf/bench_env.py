"""Machine / environment line for benchmark logs (design/benchmarks/README.md).

Library only. `env_line(...)` returns one `env: key=value ...` line; unknown fields print `unknown`, never a guess.
Records compare only within the same `machine=`.
"""
from __future__ import annotations

import os
import platform
import re
import shutil
import subprocess


def _run(cmd: list[str]) -> str:
    try:
        return subprocess.run(cmd, capture_output=True, text=True, timeout=10).stdout.strip()
    except (OSError, subprocess.SubprocessError):
        return ""


def _cpu() -> str:
    if platform.system() == "Linux":
        m = re.search(r"Model name:\s*(.+)", _run(["lscpu"]))
        if m:
            return "%s x%s" % (m.group(1).strip(), os.cpu_count())
    if platform.system() == "Windows":
        out = _run(["powershell", "-NoProfile", "-Command", "(Get-CimInstance Win32_Processor).Name"])
        if out:
            return "%s x%s" % (out.splitlines()[0].strip(), os.cpu_count())
    return platform.processor() or "unknown"


def _ram_gb() -> str:
    try:
        with open("/proc/meminfo", encoding="utf-8") as f:
            kb = int(re.search(r"MemTotal:\s*(\d+)", f.read()).group(1))
        return "%.0f" % (kb / 1048576)
    except (OSError, AttributeError):
        pass
    if platform.system() == "Windows":
        out = _run(["powershell", "-NoProfile", "-Command", "(Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory"])
        if out.strip().isdigit():
            return "%.0f" % (int(out) / 1073741824)
    return "unknown"


def _gpu() -> str:
    if platform.system() == "Windows":
        out = _run(["powershell", "-NoProfile", "-Command", "(Get-CimInstance Win32_VideoController).Name"])
        return "; ".join(l.strip() for l in out.splitlines() if l.strip()) or "unknown"
    if shutil.which("glxinfo"):
        m = re.search(r"OpenGL renderer string:\s*(.+)", _run(["glxinfo", "-B"]))
        if m:
            return m.group(1).strip()
    if shutil.which("nvidia-smi"):
        out = _run(["nvidia-smi", "--query-gpu=name", "--format=csv,noheader"])
        if out:
            return out.splitlines()[0]
    return "unknown"


def machine() -> str:
    """`bot-box` on the Bot's Linux box, else `WDB_MACHINE` or the host name."""
    if os.environ.get("WDB_MACHINE"):
        return os.environ["WDB_MACHINE"]
    if os.environ.get("WDB_BOT") or os.path.isdir("/home/box"):
        return "bot-box"
    return platform.node() or "unknown"


def env_line(godot: str = "unknown", renderer: str = "unknown", browser: str = "n/a",
             vsync: str = "unknown", cap: str = "unknown", resolution: str = "unknown", headless: bool = False) -> str:
    os_name = "%s %s" % (platform.system(), platform.release())
    if platform.system() == "Linux" and os.path.exists("/etc/os-release"):
        with open("/etc/os-release", encoding="utf-8") as f:
            m = re.search(r'PRETTY_NAME="([^"]+)"', f.read())
        if m:
            os_name = "%s (%s)" % (m.group(1), platform.release())
    f = {
        "machine": machine(), "cpu": _cpu(), "gpu": _gpu(), "ram_gb": _ram_gb(), "os": os_name,
        "browser": browser, "godot": godot, "renderer": renderer, "vsync": vsync, "cap": cap,
        "res": resolution, "headless": "1" if headless else "0",
    }
    return "env: " + " ".join('%s="%s"' % (k, v or "unknown") for k, v in f.items())


def godot_version(bin_path: str) -> str:
    out = _run([bin_path, "--version"]) if bin_path else ""
    return out.splitlines()[0] if out else "unknown"

