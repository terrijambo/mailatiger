"""Used by tools/photo/run.sh: waits for the throwaway test Studio window, brings it to the front, maximizes it,
and screenshots it every couple of seconds while tools/photo/client.lua flies the camera around.
Pictures go to tools/photo/out/frame_NNN.png. Only ever touches that test window."""

import ctypes
import ctypes.wintypes
import os
import sys
import time

from PIL import ImageGrab

user32 = ctypes.windll.user32
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "out")


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
    user32.ShowWindow(hwnd, 3)  # maximize
    shot = 0
    begin = time.time()
    while time.time() - begin < seconds:
        try:
            user32.SetForegroundWindow(hwnd)
            rect = ctypes.wintypes.RECT()
            user32.GetWindowRect(hwnd, ctypes.byref(rect))
            image = ImageGrab.grab(bbox=(rect.left, rect.top, rect.right, rect.bottom), all_screens=True)
            shot += 1
            image.save(os.path.join(OUT, f"frame_{shot:03d}_{int(time.time() - begin):03d}s.png"))
        except Exception as error:  # the window closed: we're done
            print("PHOTO stopped:", error)
            break
        time.sleep(2)
    print(f"PHOTO saved {shot} frames to {OUT}")


if __name__ == "__main__":
    main()
