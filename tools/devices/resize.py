"""Used by tools/devices/run.sh: waits for the test Studio window (the throwaway run-in-roblox place) and
steps it through smaller and smaller sizes, so the game view goes from laptop size down to phone size while
tools/devices/client.lua records the UI at each one. Only ever touches that test window."""

import ctypes
import ctypes.wintypes
import sys
import time

user32 = ctypes.windll.user32
SIZES = [(1920, 1040), (1600, 900), (1400, 780), (1250, 680), (1120, 600), (1000, 540), (900, 480)] * 2  # twice, in case Play starts late


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
    start = time.time()
    hwnd = None
    while time.time() - start < 180 and not hwnd:
        hwnd = find_test_window()
        time.sleep(1)
    if not hwnd:
        print("RESIZE no test window found")
        return
    time.sleep(float(sys.argv[1]) if len(sys.argv) > 1 else 30)  # let Play start
    user32.ShowWindow(hwnd, 9)  # restore from maximized
    for width, height in SIZES:
        user32.SetWindowPos(hwnd, 0, 0, 0, width, height, 0x0004)  # SWP_NOZORDER
        print(f"RESIZE window {width}x{height}", flush=True)
        time.sleep(6)


if __name__ == "__main__":
    main()
