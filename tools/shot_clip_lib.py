"""Shot output helpers: Windows clipboard paste (web mode) and open-in-viewer (user mode).

Library for run_shots.py; no CLI. Both return 'ok', 'fail' or 'skip'.
"""
from __future__ import annotations

import os
import subprocess
import time
from pathlib import Path


def clipboard_png(png: Path) -> str:
    if os.name != 'nt' or not png.is_file():
        return 'skip'
    import ctypes
    from ctypes import wintypes
    gdiplus = ctypes.windll.gdiplus
    user32 = ctypes.windll.user32
    gdi32 = ctypes.windll.gdi32
    kernel32 = ctypes.windll.kernel32
    kernel32.GlobalAlloc.restype = ctypes.c_void_p
    kernel32.GlobalLock.restype = ctypes.c_void_p
    kernel32.GlobalLock.argtypes = [ctypes.c_void_p]
    kernel32.GlobalUnlock.argtypes = [ctypes.c_void_p]
    user32.SetClipboardData.argtypes = [ctypes.c_uint, ctypes.c_void_p]
    user32.SetClipboardData.restype = ctypes.c_void_p
    user32.OpenClipboard.argtypes = [ctypes.c_void_p]
    class _Startup(ctypes.Structure):
        _fields_ = [
            ('GdiplusVersion', ctypes.c_uint32),
            ('DebugEventCallback', ctypes.c_void_p),
            ('SuppressBackgroundThread', ctypes.c_int),
            ('SuppressExternalCodecs', ctypes.c_int),
        ]
    class _Hdr(ctypes.Structure):
        _fields_ = [
            ('biSize', wintypes.DWORD),
            ('biWidth', wintypes.LONG),
            ('biHeight', wintypes.LONG),
            ('biPlanes', wintypes.WORD),
            ('biBitCount', wintypes.WORD),
            ('biCompression', wintypes.DWORD),
            ('biSizeImage', wintypes.DWORD),
            ('biXPelsPerMeter', wintypes.LONG),
            ('biYPelsPerMeter', wintypes.LONG),
            ('biClrUsed', wintypes.DWORD),
            ('biClrImportant', wintypes.DWORD),
        ]
    token = ctypes.c_ulong()
    if gdiplus.GdiplusStartup(ctypes.byref(token), ctypes.byref(_Startup(1, None, 0, 0)), None) != 0:
        return 'fail'
    image = ctypes.c_void_p()
    if gdiplus.GdipCreateBitmapFromFile(ctypes.c_wchar_p(str(png)), ctypes.byref(image)) != 0:
        return 'fail'
    width = ctypes.c_uint()
    height = ctypes.c_uint()
    gdiplus.GdipGetImageWidth(image, ctypes.byref(width))
    gdiplus.GdipGetImageHeight(image, ctypes.byref(height))
    w = int(width.value)
    h = int(height.value)
    scale = 1.0
    while (w * scale) * (h * scale) * 3 > 3500000:
        scale *= 0.9
    tw = max(1, int(w * scale))
    th = max(1, int(h * scale))
    small = ctypes.c_void_p()
    if gdiplus.GdipGetImageThumbnail(image, tw, th, ctypes.byref(small), None, None) != 0:
        gdiplus.GdipDisposeImage(image)
        return 'fail'
    hbmp = ctypes.c_void_p()
    if gdiplus.GdipCreateHBITMAPFromBitmap(small, ctypes.byref(hbmp), 0x00FFFFFF) != 0:
        return 'fail'
    stride = ((tw * 3 + 3) // 4) * 4
    hdr = _Hdr()
    hdr.biSize = ctypes.sizeof(_Hdr)
    hdr.biWidth = tw
    hdr.biHeight = th
    hdr.biPlanes = 1
    hdr.biBitCount = 24
    hdr.biCompression = 0
    hdr.biSizeImage = stride * th
    total = ctypes.sizeof(_Hdr) + int(hdr.biSizeImage)
    hglob = kernel32.GlobalAlloc(0x0002, total)
    ptr = kernel32.GlobalLock(hglob)
    if not hglob or not ptr:
        return 'fail'
    ctypes.memmove(ptr, ctypes.byref(hdr), ctypes.sizeof(hdr))
    hdc = user32.GetDC(None)
    rows = gdi32.GetDIBits(hdc, hbmp, 0, th, ctypes.c_void_p(ptr + ctypes.sizeof(hdr)), ctypes.byref(hdr), 0)
    user32.ReleaseDC(None, hdc)
    kernel32.GlobalUnlock(hglob)
    if rows == 0:
        return 'fail'
    if not user32.OpenClipboard(None):
        return 'fail'
    user32.EmptyClipboard()
    placed = user32.SetClipboardData(8, hglob)
    user32.CloseClipboard()
    gdi32.DeleteObject(hbmp)
    gdiplus.GdipDisposeImage(small)
    gdiplus.GdipDisposeImage(image)
    gdiplus.GdiplusShutdown(token)
    print('clip_px=%dx%d dib_bytes=%d' % (tw, th, total))
    time.sleep(0.5)
    return 'ok' if placed else 'fail'


def open_png(png: Path) -> str:
    if not png.is_file():
        return "skip"
    try:
        os.startfile(str(png))  # type: ignore[attr-defined]
        return "ok"
    except AttributeError:
        opened = subprocess.run(["xdg-open", str(png)], capture_output=True)
        return "ok" if opened.returncode == 0 else "fail"
    except OSError:
        return "fail"
