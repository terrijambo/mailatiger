#!/usr/bin/env bash
# Smoke test: builds the map in a real (temporary) Roblox Studio with your imported models, using the
# game's own MapBuilder, and prints what got built plus any errors. Never touches MailATiger.rbxl
# (it reads a copy of it for the models).
#
#   bash tools/smoke/run.sh
#
# Needs: rojo, lune and run-in-roblox (rokit add --global lune-org/lune rojo-rbx/run-in-roblox).
# A second Studio window opens for a few seconds and closes by itself. Save in Studio first (Ctrl+S).
set -e
cd "$(dirname "$0")/../.."
TMP="$(mktemp -d)"
cp MailATiger.rbxl "$TMP/place_copy.rbxl"
rojo build -o "$TMP/build.rbxl"
lune run tools/smoke/merge.luau "$TMP/build.rbxl" "$TMP/place_copy.rbxl" "$TMP/merged.rbxl"
run-in-roblox --place "$TMP/merged.rbxl" --script tools/smoke/smoke.lua | grep -v "^$"
rm -rf "$TMP"
