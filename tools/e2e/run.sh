#!/usr/bin/env bash
# Automated playtest in a real (temporary) Roblox Studio: a test player picks a Hamster, catches it, boxes
# it, mails it, shops, redeems a code and changes a setting, using the game's real code and your models.
# Prints PASS/FAIL for each step plus any errors. Never touches MailATiger.rbxl (it reads a copy).
#
#   bash tools/e2e/run.sh
#
# Needs: rojo, lune and run-in-roblox (rokit add --global lune-org/lune rojo-rbx/run-in-roblox).
# A second Studio window opens for about a minute and closes by itself. Save in Studio first (Ctrl+S).
set -e
cd "$(dirname "$0")/../.."
# The test opens its own temporary Studio. If your Studio is open too, it can pick up the test's plugin and
# the run gets unreliable, so this refuses to start until Studio is closed (save your work first).
if tasklist 2>/dev/null | grep -qi "RobloxStudioBeta.exe"; then
	echo "Roblox Studio is open. Save and close it, then run this again (the test opens its own copy)."
	exit 1
fi
TMP="$(mktemp -d)"
# Always remove the test plugin run-in-roblox installs, even if this run is interrupted
PLUGINS="$LOCALAPPDATA/Roblox/Plugins"
trap 'rm -f "$PLUGINS"/run_in_roblox-*.rbxmx; rm -rf "$TMP"' EXIT
cp MailATiger.rbxl "$TMP/place_copy.rbxl"
rojo build -o "$TMP/build.rbxl" > /dev/null
lune run tools/smoke/merge.luau "$TMP/build.rbxl" "$TMP/place_copy.rbxl" "$TMP/merged.rbxl" > /dev/null

# The driver: injects server.lua and client.lua, then starts a Play session
{
	# run-in-roblox's plugin also runs inside the Play session. The edit session is frozen while Play runs,
	# so the Play server prints a heartbeat to keep run-in-roblox from giving up.
	# Safety: only ever run inside the throwaway test place (marked by merge.luau), never in your own game
	echo 'if game:GetService("Workspace"):GetAttribute("MailATigerTestPlace") ~= true then return end'
	echo 'local RunService = game:GetService("RunService")'
	echo 'if RunService:IsRunning() then'
	echo '	if RunService:IsServer() then for _ = 1, 150 do task.wait(2) print("heartbeat") end end'
	echo '	return'
	echo 'end'
	echo 'local HttpService = game:GetService("HttpService")'
	echo 'local server = Instance.new("Script")'
	echo 'server.Name = "E2EServer"'
	echo 'server.Source = [==['
	cat tools/e2e/server.lua
	echo ']==]'
	echo 'server.Parent = game:GetService("ServerScriptService")'
	echo 'local client = Instance.new("LocalScript")'
	echo 'client.Name = "E2EClient"'
	echo 'client.Source = [==['
	cat tools/e2e/client.lua
	echo ']==]'
	echo 'client.Parent = game:GetService("StarterPlayer").StarterPlayerScripts'
	echo 'local ok, result = pcall(function() return game:GetService("StudioTestService"):ExecutePlayModeAsync({}) end)'
	echo 'if not ok then print("E2E could not start Play: " .. tostring(result)) return end'
	echo 'for _, line in result.Client.Steps or {} do if string.sub(line, 1, 6) == "UIDUMP" then print(string.sub(line, 8)) else print("E2E " .. line) end end'
	echo 'for _, line in result.Client.Errors or {} do print("E2E CLIENT " .. line) end'
	echo 'for _, line in result.Server or {} do print("E2E SERVER " .. line) end'
	echo 'print("E2E DONE")'
} > "$TMP/driver.lua"

(cd "$TMP" && run-in-roblox --place merged.rbxl --script driver.lua) | grep -E "^(E2E|UI) " || true
rm -rf "$TMP"
