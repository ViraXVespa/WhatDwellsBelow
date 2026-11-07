"""Concrete staged helper/hook lifecycle tests; no model or Godot access."""
from __future__ import annotations

import json
import os
import shlex
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path


def selftest() -> list[str]:
    from PIL import Image, ImageDraw, ImageFont
    import review_bundle as bundle
    from ocr_evidence import marker_path, tried
    errors = []
    with tempfile.TemporaryDirectory(prefix="wdb-bundle-test-") as tmp:
        top = Path(tmp)
        inputs, scratch = top / "inputs", top / "review"
        inputs.mkdir()
        scratch.mkdir()
        (inputs / "full").mkdir()
        src = inputs / "label.png"
        im = Image.new("RGB", (900, 120), (20, 20, 30))
        try:
            font = ImageFont.truetype("DejaVuSans.ttf", 40)
        except OSError:
            font = ImageFont.load_default(size=40)
        ImageDraw.Draw(im).text((20, 30), "Report bug to the guild", fill="white", font=font)
        im.save(inputs / "full/label.png")
        im.resize((450, 60)).save(src)
        shutil.copy2(src, scratch / "01-label.png")
        notes = bundle.stage(scratch, [(src, "01-label.png")], text_review=True)
        if "900x120" not in notes[0] or Image.open(scratch / "full/01-label.png").size != (900, 120):
            errors.append("full originals not staged")
        cfg = json.loads((scratch / ".grok/hooks/wdb-review.json").read_text())
        hook = shlex.split(cfg["hooks"]["PreToolUse"][0]["hooks"][0]["command"])

        def event(name, data):
            return {"toolName": name, "toolInput": data, "cwd": str(scratch), "workspaceRoot": str(scratch)}

        def check(ev, want, label):
            r = subprocess.run(hook, cwd=scratch, input=json.dumps(ev), text=True, capture_output=True)
            try:
                got = json.loads(r.stdout)["decision"]
            except (ValueError, KeyError):
                got = r.stdout + r.stderr
            if got != want or (r.returncode == 0) != (want == "allow"):
                errors.append(label + ": " + got)

        read = event("read_file", {"target_file": "01-label.png"})
        check(read, "deny", "isolated text read before attempt")
        check(event("run_terminal_command", {"command": bundle.helper_command("ocr", "01-label.png")}), "allow", "local OCR command")
        for command in ("python -c 'print(1)'", bundle.helper_command("ocr", "../inputs/label.png"),
                        bundle.helper_command("ocr", "01-label.png") + "; touch nope"):
            check(event("run_terminal_command", {"command": command}), "deny", "unscoped shell rejected")
        crop_command = bundle.helper_command("crop", "01-label.png", "--box", "10,10,20,10", "--out", "out/check.png")
        check(event("run_terminal_command", {"command": crop_command}), "allow", "scoped crop command")
        for replacement in ("out/$(id).png", "out/`id`.png", "out/check.png>outside.png", "out/check.png\nid"):
            command = crop_command.replace("out/check.png", replacement)
            check(event("run_terminal_command", {"command": command}), "deny", "shell syntax in helper arguments")
        output = bundle.prepass(scratch, ["01-label.png"])
        if "READ " not in output or not tried(scratch, [scratch / "01-label.png"]):
            errors.append("real helper produced no OCR attempt evidence")
        check(read, "allow", "isolated text read after attempt")
        check(event("read_file", {"target_file": "full/01-label.png"}), "allow", "full source evidence")
        # Test the outer repository hook too: staged decision must precede blanket isolated allow.
        outer = Path(__file__).resolve().parents[3] / ".grok/hooks/bin/wdb-pretool.py"
        receipt = marker_path([scratch / "01-label.png"], scratch)
        saved = receipt.read_text()
        row = json.loads(saved)
        row["time"] = time.time() - 1801
        receipt.write_text(json.dumps(row))
        check(read, "deny", "expired evidence")
        r = subprocess.run([sys.executable, str(outer)], cwd=scratch, input=json.dumps(read), text=True, capture_output=True)
        if r.returncode != 2 or json.loads(r.stdout)["decision"] != "deny":
            errors.append("outer hook bypassed isolated policy")
        receipt.write_text(saved)
        old = (scratch / "01-label.png").read_bytes()
        Image.new("RGB", (450, 60), "red").save(scratch / "01-label.png")
        check(read, "deny", "changed image invalidates evidence")
        (scratch / "01-label.png").write_bytes(old)
        for op in ("crop", "zoom"):
            r = subprocess.run([sys.executable, "local/review_local.py", op, "01-label.png", "--box", "10,10,20,10",
                                "--out", f"out/{op}.png"], cwd=scratch, capture_output=True, text=True)
            expected = (40, 20) if op == "crop" else (160, 80)
            if r.returncode or Image.open(scratch / f"out/{op}.png").size != expected:
                errors.append(op + " did not use full-size coordinates")
        r = subprocess.run([sys.executable, "local/review_local.py", "diff", "01-label.png", "full/01-label.png",
                            "--out", "out/diff.png"], cwd=scratch, capture_output=True, text=True)
        if r.returncode or '"score": 1.0' not in r.stdout or not (scratch / "out/diff.png").is_file():
            errors.append("bundled imglib diff failed")
        # Missing binary is an honest, recorded attempt, not an empty unbound marker.
        env = dict(os.environ, PATH="", WDB_TESSERACT="")
        r = subprocess.run([sys.executable, "local/review_local.py", "ocr", "01-label.png"], cwd=scratch,
                           capture_output=True, text=True, env=env)
        if r.returncode or ("RESULT INFO" not in r.stdout or "ocr=SKIP" not in r.stdout):
            errors.append("missing Tesseract fallback")
        check(read, "allow", "SKIP permits text fallback")
        data = json.loads((scratch / bundle.MANIFEST).read_text())
        data["text_review"] = False
        (scratch / bundle.MANIFEST).write_text(json.dumps(data))
        receipt.unlink()
        check(read, "allow", "ordinary visual read needs no OCR")
        # Media staging reuses helpers/originals without changing generation permissions.
        media = top / "media"
        media.mkdir()
        shutil.copy2(src, media / src.name)
        bundle.stage(media, [(src, src.name)], hook=False)
        if not (media / "local/review_local.py").is_file() or (media / ".grok/hooks/wdb-review.json").exists():
            errors.append("media helper bundle scope")
    return errors
