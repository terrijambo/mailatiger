#!/usr/bin/env bash
# Automated playtest in a real (temporary) Roblox Studio: a test player picks a Hamster, catches it, boxes
# it, mails it, shops, redeems a code and changes a setting, using the game's real code and your models.
# Prints PASS/FAIL for each step plus any errors. Never touches MailATiger.rbxl (it reads a copy).
#
#   bash tools/e2e/run.sh
#   E2E_CLIENT=tools/devices/client.lua bash tools/e2e/run.sh    (a different client test; see tools/devices)
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
	# The plugin can load in the Play copies before RunService says they're running, so the edit copy marks
	# Workspace with E2EPlaying just before Play: the copies inherit it and never start a second Play.
	# Safety: only ever run inside the throwaway test place (marked by merge.luau), never in your own game
	echo 'if game:GetService("Workspace"):GetAttribute("MailATigerTestPlace") ~= true then return end'
	echo 'local RunService = game:GetService("RunService")'
	echo 'if game:GetService("Workspace"):GetAttribute("E2EPlaying") or RunService:IsRunning() then'
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
	cat "${E2E_CLIENT:-tools/e2e/client.lua}"
	echo ']==]'
	echo 'client.Parent = game:GetService("StarterPlayer").StarterPlayerScripts'
	echo 'game:GetService("Workspace"):SetAttribute("E2EPlaying", true)'
	# Play started while Studio is still loading its built-in plugins can end at once with no result: wait, retry
	echo 'local ok, result'
	echo 'for _ = 1, 3 do'
	echo '	task.wait(4)'
	echo '	ok, result = pcall(function() return game:GetService("StudioTestService"):ExecutePlayModeAsync({}) end)'
	echo '	if ok and type(result) == "table" then break end'
	echo 'end'
	echo 'if not ok or type(result) ~= "table" then print("E2E FAIL could not start Play: " .. tostring(result)) print("E2E DONE") return end'
	echo 'for _, line in result.Client.Steps or {} do if string.sub(line, 1, 6) == "UIDUMP" then print(string.sub(line, 8)) else print("E2E " .. line) end end'
	echo 'for _, line in result.Client.Errors or {} do print("E2E CLIENT " .. line) end'
	echo 'for _, line in result.Server or {} do print("E2E SERVER " .. line) end'
	echo 'print("E2E DONE")'
} > "$TMP/driver.lua"

# run-in-roblox can get stuck relaying a message it can't encode, so it gets a time limit, and if its output
# is missing the results are read back from Studio's own log file instead
touch "$TMP/started"
(cd "$TMP" && timeout 420 run-in-roblox --place merged.rbxl --script driver.lua) > "$TMP/out.txt" 2>&1 || true
if grep -q "^E2E DONE" "$TMP/out.txt"; then
	grep -E "^(E2E|UI) " "$TMP/out.txt"
else
	LOG="$(ls -t "$LOCALAPPDATA"/Roblox/logs/*Studio*_last.log | head -1)"
	if [ -n "$LOG" ] && [ "$LOG" -nt "$TMP/started" ]; then
		grep -a "CreatorOutput\] \(E2E\|UI\) " "$LOG" | sed 's/.*CreatorOutput\] //'
	else
		# (never report an older run's results as this one's)
		echo "E2E FAIL the test Studio didn't start. run-in-roblox said:"
		tail -5 "$TMP/out.txt"
	fi
fi
# Close the test Studio if it's still open (only the throwaway test place, never your own game)
for pid in $(tasklist //V //FO CSV 2>/dev/null | grep "run-in-roblox-place" | cut -d, -f2 | tr -d '"'); do
	taskkill //PID "$pid" //F > /dev/null 2>&1 || true
done
rm -rf "$TMP"
