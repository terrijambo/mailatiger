--!strict
-- Keeps track of the popup windows (Pen, Shop, Orders, Store, Settings) so any button can open any of
-- them, and only one is open at a time.

local Menus = {}

type Menu = { Gui: ScreenGui, OnOpen: (() -> ())? }

local menus: { [string]: Menu } = {}

-- `onOpen` runs just before the window shows (e.g. to redraw it with fresh data)
function Menus.Register(name: string, gui: ScreenGui, onOpen: (() -> ())?)
	menus[name] = { Gui = gui, OnOpen = onOpen }
end

function Menus.Open(name: string)
	local menu = menus[name]
	if not menu then
		return
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
