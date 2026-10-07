#!/usr/bin/env bash
# Photo tour: plays the game in a temporary Studio with the UI hidden, flies the camera over the whole map
# and each island (tools/photo/client.lua), and screenshots the window every 2 seconds into tools/photo/out/.
#
#   bash tools/photo/run.sh
#
# Studio must be closed (same as the playtest). Takes about 5 minutes.
set -e
cd "$(dirname "$0")/../.."
python tools/photo/shoot.py 260 &
SHOOTER=$!
E2E_CLIENT=tools/photo/client.lua bash tools/e2e/run.sh > tools/photo/out.txt 2>&1 || true
wait $SHOOTER 2> /dev/null || true
grep -aE "^E2E (PASS|FAIL|CLIENT|SERVER ERROR)" tools/photo/out.txt | grep -v "could not fetch\|status code" | head -60 || true
ls tools/photo/out | head -200
