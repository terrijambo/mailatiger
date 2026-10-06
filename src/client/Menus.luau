--!strict
-- Keeps track of the popup windows (Pen, Shop, Orders, Store, Settings) so any button can open any of
-- them, and only one is open at a time.
-- With a gamepad: opening a window selects its first button (move with the stick or d-pad, A to press),
-- and B closes it.

local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")

local Menus = {}

type Menu = { Gui: ScreenGui, OnOpen: (() -> ())? }

local menus: { [string]: Menu } = {}

local function usingGamepad(): boolean
	return string.sub(UserInputService:GetLastInputType().Name, 1, 7) == "Gamepad"
end

-- B closes the open window (bound only while one is open, so B is free for the game otherwise)
local backBound = false
local function refreshGamepad()
	local open = false
	for _, entry in menus do
		if entry.Gui.Enabled then
			open = true
		end
	end
	if open and not backBound then
		backBound = true
		ContextActionService:BindActionAtPriority("MenuBack", function(_name: string, state: Enum.UserInputState)
			if state == Enum.UserInputState.Begin then
				Menus.CloseAll()
			end
			return Enum.ContextActionResult.Sink
		end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.ButtonB)
	elseif not open and backBound then
		backBound = false
		ContextActionService:UnbindAction("MenuBack")
		GuiService.SelectedObject = nil
	end
end

-- `onOpen` runs just before the window shows (e.g. to redraw it with fresh data)
function Menus.Register(name: string, gui: ScreenGui, onOpen: (() -> ())?)
	menus[name] = { Gui = gui, OnOpen = onOpen }
	gui:GetPropertyChangedSignal("Enabled"):Connect(refreshGamepad)
end

-- Set by SideButtons: runs whenever a window opens (folds the pop-out MENU away)
Menus.OnOpen = nil :: (() -> ())?

function Menus.Open(name: string)
	local menu = menus[name]
	if not menu then
		return
	end
	local hook = Menus.OnOpen
	if hook then
		hook()
	end
	for other, entry in menus do
		if other ~= name then
			entry.Gui.Enabled = false
		end
	end
	local onOpen = menu.OnOpen
	if onOpen then
		onOpen()
	end
	menu.Gui.Enabled = true
	if usingGamepad() then
		-- (next frame, once the window's buttons exist)
		task.defer(function()
			if menu.Gui.Enabled then
				GuiService:Select(menu.Gui)
			end
		end)
	end
end

function Menus.Toggle(name: string)
	local menu = menus[name]
	if menu and menu.Gui.Enabled then
		menu.Gui.Enabled = false
	else
		Menus.Open(name)
	end
end

-- Is any of the windows open right now?
function Menus.AnyOpen(): boolean
	for _, entry in menus do
		if entry.Gui.Enabled then
			return true
		end
	end
	return false
end

function Menus.CloseAll()
	for _, entry in menus do
		entry.Gui.Enabled = false
	end
end

return Menus
