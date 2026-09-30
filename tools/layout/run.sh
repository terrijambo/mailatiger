#!/usr/bin/env bash
# Layout check: builds the map in a real (temporary) Roblox Studio with your models, then lists anything
# standing on a road or poking into a building, and draws a top-down picture (tools/layout/map.png).
#
#   bash tools/layout/run.sh
#
# Needs: rojo, lune, run-in-roblox and Python with Pillow. Refuses to run while Studio is open (like the
# smoke test). Never touches MailATiger.rbxl (it reads a copy for the models).
set -e
cd "$(dirname "$0")/../.."
if tasklist 2>/dev/null | grep -qi "RobloxStudioBeta.exe"; then
	echo "Roblox Studio is open. Save and close it, then run this again (the test opens its own copy)."
	exit 1
fi
TMP="$(mktemp -d)"
PLUGINS="$LOCALAPPDATA/Roblox/Plugins"
trap 'rm -f "$PLUGINS"/run_in_roblox-*.rbxmx; rm -rf "$TMP"' EXIT
cp MailATiger.rbxl "$TMP/place_copy.rbxl"
rojo build -o "$TMP/build.rbxl" > /dev/null
lune run tools/smoke/merge.luau "$TMP/build.rbxl" "$TMP/place_copy.rbxl" "$TMP/merged.rbxl" > /dev/null
run-in-roblox --place "$TMP/merged.rbxl" --script tools/layout/dump.lua > "$TMP/dump.txt"
grep "LAYOUT build" "$TMP/dump.txt" || true
python tools/layout/check.py "$TMP/dump.txt" tools/layout/map.png
