"""Runs Python inside the Blender that's open on this computer, through the Blender MCP add-on's local socket
(the add-on listens on 127.0.0.1:9876 once its server is started in Blender's sidebar).

    python tools/blender/bmcp.py run  path/to/script.py   # runs the file inside Blender, prints its output
    python tools/blender/bmcp.py code "print(bpy.app.version_string)"
    python tools/blender/bmcp.py ping

The build scripts (art/blender_scripts/hero_*.py) are ordinary files in the repo: this only sends them over, so the
owner can watch the model appear in their Blender. They also run headless (blender --background --python ...).
"""

import json
import os
import socket
import sys

HOST, PORT = "127.0.0.1", 9876


def send(command: dict, timeout: float = 600.0) -> dict:
    with socket.create_connection((HOST, PORT), timeout=10) as s:
        s.settimeout(timeout)
        s.sendall(json.dumps(command).encode("utf-8"))
        buffer = b""
        while True:
            chunk = s.recv(65536)
            if not chunk:
                break
            buffer += chunk
            try:
                return json.loads(buffer.decode("utf-8"))
            except (json.JSONDecodeError, UnicodeDecodeError):
                continue
    raise RuntimeError("Blender closed the connection without answering")


def run_code(code: str) -> int:
    reply = send({"type": "execute_code", "params": {"code": code}})
    if reply.get("status") == "error":
        message = reply.get("message", "")
        try:
            detail = json.loads(message)
            print(detail.get("traceback") or detail.get("message"))
        except (json.JSONDecodeError, TypeError):
            print(message)
        return 1
    result = reply.get("result", reply)
    print(result.get("result", "") if isinstance(result, dict) else result)
    return 0


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__)
        return 2
    action = sys.argv[1]
    if action == "ping":
        print(send({"type": "ping"}))
        return 0
    if action == "code":
        return run_code(sys.argv[2])
    if action == "run":
        path = os.path.abspath(sys.argv[2])
        with open(path, encoding="utf-8") as f:
            source = f.read()
        # Scripts find their helpers (kk.py) and the repo by these two names
        prelude = f"__file__ = {path!r}\n__name__ = '__main__'\n"
        return run_code(prelude + source)
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main())
