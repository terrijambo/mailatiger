--!nocheck
-- Unpacks the two bought packs into vendor/ so Rojo can sync them into Studio.
--
--   lune run tools/vendor_packs.luau <UIPackPlus.rbxm> <ZeroPanel.rbxm>
--
-- vendor/ is git-ignored on purpose: both packs are proprietary (by sebattfg) and their licenses forbid
-- putting them in any repository, and this repo is public. Keep the two .rbxm files somewhere safe; on a
-- new computer, run this again with them.
--
-- What it writes (default.project.json points at each one as an optional path):
--   vendor/ShardUI.rbxm            UI pack library            -> ReplicatedStorage.ShardUI
--   vendor/ShardUIReference.rbxm   UI pack demo screens       -> ServerStorage.ShardUIReference (Studio only,
--                                   never sent to players: ~5,000 images, and its Idle guide is switched off)
--   vendor/ZeroPanel/*.rbxm        admin panel, installed the way its own installer would: Runtime and the
--                                   client script switched on, and the owner list set to the game's owner
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local uiPath, zeroPath = process.args[1], process.args[2]
assert(uiPath and zeroPath, "usage: lune run tools/vendor_packs.luau <UIPackPlus.rbxm> <ZeroPanel.rbxm>")

local function load(path: string, rootName: string)
	for _, inst in roblox.deserializeModel(fs.readFile(path)) do
		if inst.Name == rootName then
			return inst
		end
	end
	error(path .. ": no top-level '" .. rootName .. "' found (is this the right file?)")
end

local function save(path: string, inst)
	fs.writeFile(path, roblox.serializeModel({ inst }))
	print("wrote " .. path)
end

local function child(parent, name: string)
	local found = parent:FindFirstChild(name)
	assert(found, parent:GetFullName() .. " has no child '" .. name .. "'")
	return found
end

if fs.isDir("vendor") then
	fs.removeDir("vendor")
end
fs.writeDir("vendor/ZeroPanel")

-- UI pack ----------------------------------------------------------------------------------------------
local ui = load(uiPath, "UIPack Plus")
save("vendor/ShardUI.rbxm", child(ui, "ShardUI"))

local reference = child(ui, "ShardUIPack")
reference.Name = "ShardUIReference"
for _, d in reference:GetDescendants() do
	if d:IsA("ScreenGui") then
		d.Enabled = false
	end
end
save("vendor/ShardUIReference.rbxm", reference)

-- ZeroPanel --------------------------------------------------------------------------------------------
local payload = child(load(zeroPath, "ZeroPanel Installer"), "Payload")

-- The pack ships with its author's own account in the owner list (the installer window replaces it).
-- Owners get every permission, so it must never stay: the owner is whoever owns this game.
local config = child(child(child(payload, "ServerScriptService"), "ZeroPanel"), "Config")
local source, hits = string.gsub(
	config.Source,
	"owners%s*=%s*%b{}",
	"owners = (if game.CreatorType == Enum.CreatorType.User then { game.CreatorId, -1 } else { -1 })",
	1
)
assert(hits == 1, "could not find the owners list in ZeroPanel Config")
config.Source = source

child(child(child(payload, "ServerScriptService"), "ZeroPanel"), "Runtime").Disabled = false
child(child(payload, "StarterPlayerScripts"), "ZeroPanelClient").Disabled = false

save("vendor/ZeroPanel/ReplicatedStorage.rbxm", child(child(payload, "ReplicatedStorage"), "ZeroPanel"))
save("vendor/ZeroPanel/ServerScriptService.rbxm", child(child(payload, "ServerScriptService"), "ZeroPanel"))
save("vendor/ZeroPanel/StarterPlayerScripts.rbxm", child(child(payload, "StarterPlayerScripts"), "ZeroPanelClient"))
save("vendor/ZeroPanel/StarterGui.rbxm", child(child(payload, "StarterGui"), "ZeroPanel"))
