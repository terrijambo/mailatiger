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
TMP="$(mktemp -d)"
cp MailATiger.rbxl "$TMP/place_copy.rbxl"
rojo build -o "$TMP/build.rbxl" > /dev/null
lune run tools/smoke/merge.luau "$TMP/build.rbxl" "$TMP/place_copy.rbxl" "$TMP/merged.rbxl" > /dev/null

# The driver: injects server.lua and client.lua, then starts a Play session
{
	# run-in-roblox's plugin also runs inside the Play session. The edit session is frozen while Play runs,
	# so the Play server prints a heartbeat to keep run-in-roblox from giving up.
	echo 'local RunService = game:GetService("RunService")'
	echo 'if RunService:IsRunning() then'
	echo '	if RunService:IsServer() then for _ = 1, 90 do task.wait(2) print("heartbeat") end end'
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
	echo 'for _, line in result.Client.Steps or {} do print("E2E " .. line) end'
	echo 'for _, line in result.Client.Errors or {} do print("E2E CLIENT " .. line) end'
	echo 'for _, line in result.Server or {} do print("E2E SERVER " .. line) end'
	echo 'print("E2E DONE")'
} > "$TMP/driver.lua"

(cd "$TMP" && run-in-roblox --place merged.rbxl --script driver.lua) | grep "^E2E" || true
rm -rf "$TMP"
