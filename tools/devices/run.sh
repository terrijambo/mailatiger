#!/usr/bin/env bash
# Device layout test: plays the game in a temporary Studio and shrinks its window step by step, from laptop
# size down to phone size, recording where all the UI lands at each size. Then lists overlaps, things off
# screen, and HUD sitting where a phone's thumbstick or jump button go, with a picture of every size in
# tools/devices/out/.
#
#   bash tools/devices/run.sh
#
# Studio must be closed (same as the playtest). Takes about 3 minutes.
set -e
cd "$(dirname "$0")/../.."
python tools/devices/resize.py 35 &
RESIZER=$!
E2E_CLIENT=tools/devices/client.lua bash tools/e2e/run.sh > tools/devices/out.txt 2>&1 || true
kill $RESIZER 2> /dev/null || true
grep -E "^E2E (PASS|FAIL|CLIENT|SERVER ERROR)" tools/devices/out.txt || true
python tools/devices/check.py tools/devices/out.txt
