"""Used by tools/photo/run.sh: waits for the throwaway test Studio window and saves pictures of ITS OWN
content every couple of seconds while tools/photo/client.lua flies the camera around.

It never brings the window to the front or takes focus, and it never grabs the screen: it asks Windows to
draw just that window into a picture (PrintWindow), so whatever else you have open is never captured, even
if it's covering the test window. Pictures go to tools/photo/out/frame_NNN.png."""

import ctypes
import ctypes.wintypes
import os
import sys
import time

from PIL import Image

user32 = ctypes.windll.user32
gdi32 = ctypes.windll.gdi32
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "out")

SWP_NOZORDER = 0x0004
SWP_NOACTIVATE = 0x0010
PW_RENDERFULLCONTENT = 0x00000002


def find_test_window():
    found = []

    @ctypes.WINFUNCTYPE(ctypes.c_bool, ctypes.wintypes.HWND, ctypes.wintypes.LPARAM)
    def visit(hwnd, _):
        length = user32.GetWindowTextLengthW(hwnd)
        if length:
            buffer = ctypes.create_unicode_buffer(length + 1)
            user32.GetWindowTextW(hwnd, buffer, length + 1)
            if "run-in-roblox-place" in buffer.value and user32.IsWindowVisible(hwnd):
                found.append(hwnd)
        return True

    user32.EnumWindows(visit, 0)
    return found[0] if found else None


class BITMAPINFOHEADER(ctypes.Structure):
    _fields_ = [
        ("biSize", ctypes.c_uint32), ("biWidth", ctypes.c_int32), ("biHeight", ctypes.c_int32),
        ("biPlanes", ctypes.c_uint16), ("biBitCount", ctypes.c_uint16), ("biCompression", ctypes.c_uint32),
        ("biSizeImage", ctypes.c_uint32), ("biXPelsPerMeter", ctypes.c_int32), ("biYPelsPerMeter", ctypes.c_int32),
        ("biClrUsed", ctypes.c_uint32), ("biClrImportant", ctypes.c_uint32),
    ]


def capture(hwnd):
    """A picture of just this window's content (not the screen), or None."""
    rect = ctypes.wintypes.RECT()
    user32.GetWindowRect(hwnd, ctypes.byref(rect))
    width, height = rect.right - rect.left, rect.bottom - rect.top
    if width <= 0 or height <= 0:
        return None
    window_dc = user32.GetWindowDC(hwnd)
    memory_dc = gdi32.CreateCompatibleDC(window_dc)
    bitmap = gdi32.CreateCompatibleBitmap(window_dc, width, height)
    gdi32.SelectObject(memory_dc, bitmap)
    ok = user32.PrintWindow(hwnd, memory_dc, PW_RENDERFULLCONTENT)
    header = BITMAPINFOHEADER()
    header.biSize = ctypes.sizeof(BITMAPINFOHEADER)
    header.biWidth, header.biHeight = width, -height  # (top-down)
    header.biPlanes, header.biBitCount = 1, 32
    buffer = ctypes.create_string_buffer(width * height * 4)
    gdi32.GetDIBits(memory_dc, bitmap, 0, height, buffer, ctypes.byref(header), 0)
    gdi32.DeleteObject(bitmap)
    gdi32.DeleteDC(memory_dc)
    user32.ReleaseDC(hwnd, window_dc)
    if not ok:
        return None
    return Image.frombuffer("RGB", (width, height), buffer, "raw", "BGRX", 0, 1)


def main():
    seconds = float(sys.argv[1]) if len(sys.argv) > 1 else 240
    os.makedirs(OUT, exist_ok=True)
    for name in os.listdir(OUT):
        if name.endswith(".png"):
            os.remove(os.path.join(OUT, name))
    start = time.time()
    hwnd = None
    while time.time() - start < 180 and not hwnd:
        hwnd = find_test_window()
        time.sleep(1)
    if not hwnd:
        print("PHOTO no test window found")
        return
    # Size it to 1936 x 1056 where it is, without bringing it forward or taking focus
    user32.SetWindowPos(hwnd, 0, 0, 0, 1936, 1056, SWP_NOZORDER | SWP_NOACTIVATE)
    shot = 0
    begin = time.time()
    while time.time() - begin < seconds:
        if not user32.IsWindow(hwnd):
            print("PHOTO stopped: the test window closed")
            break
        image = capture(hwnd)
        if image is not None:
            shot += 1
            image.save(os.path.join(OUT, f"frame_{shot:03d}_{int(time.time() - begin):03d}s.png"))
        time.sleep(2)
    print(f"PHOTO saved {shot} frames to {OUT}")


if __name__ == "__main__":
    main()
