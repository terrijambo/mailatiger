-- Device layout test, client side (used instead of tools/e2e/client.lua by tools/devices/run.sh).
-- While tools/devices/resize.py shrinks the Studio window to phone, tablet and laptop sizes, this records
-- where every piece of UI lands at each size: the HUD on its own, then with the Shop window open.
-- For each top-level piece (stats, side buttons, banner...) it also reports one box around everything
-- visible in it, which tools/devices/check.py tests for overlaps.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ScriptContext = game:GetService("ScriptContext")

local player = Players.LocalPlayer
local steps, clientErrors = {}, {}
ScriptContext.Error:Connect(function(message, trace)
	if #clientErrors < 30 then
		table.insert(clientErrors, message .. " @ " .. string.sub(trace, 1, 160))
	end
end)

local function clean(text)
	local cut = utf8.offset(text, 41)
	return (string.gsub(if cut then string.sub(text, 1, cut - 1) else text, "[%c|]", " "))
end

local function shows(d)
	if not d.Visible or d.AbsoluteSize.X < 2 then
		return false
	end
	local p = d.Parent
	while p and p:IsA("GuiObject") do
		if not p.Visible then
			return false
		end
		p = p.Parent
	end
	return true
end

-- Does this element actually draw something (not just an invisible container)?
local function draws(d)
	if d.BackgroundTransparency < 0.95 then
		return true
	end
	if (d:IsA("TextLabel") or d:IsA("TextButton")) and d.Text ~= "" and d.TextTransparency < 0.95 then
		return true
	end
	return d:IsA("ImageLabel") or d:IsA("ImageButton") or d:IsA("ViewportFrame")
end

local function dump(tag)
	local gui = player:WaitForChild("PlayerGui")
	local camera = workspace.CurrentCamera
	local lines = { string.format("UI %s SCREEN %d %d", tag, math.floor(camera.ViewportSize.X), math.floor(camera.ViewportSize.Y)) }
	for _, screen in gui:GetChildren() do
		if screen:IsA("ScreenGui") and screen.Enabled and screen.Name ~= "Freecam" then
			for _, top in screen:GetChildren() do
				if top:IsA("GuiObject") and shows(top) then
					local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
					for _, d in { top, table.unpack(top:GetDescendants()) } do
						if d:IsA("GuiObject") and shows(d) and draws(d) then
							local p, s = d.AbsolutePosition, d.AbsoluteSize
							-- Only the part you can see: clip to every clipping frame it sits in (a scrolling
							-- list's rows below the window are scrolled away, not off screen)
							local a0, b0, a1, b1 = p.X, p.Y, p.X + s.X, p.Y + s.Y
							local node = d.Parent
							while node and node ~= screen do
								if node:IsA("GuiObject") and node.ClipsDescendants then
									local q, t = node.AbsolutePosition, node.AbsoluteSize
									a0, b0 = math.max(a0, q.X), math.max(b0, q.Y)
									a1, b1 = math.min(a1, q.X + t.X), math.min(b1, q.Y + t.Y)
								end
								node = node.Parent
							end
							if a1 - a0 < 1 or b1 - b0 < 1 then
								continue
							end
							p, s = Vector2.new(a0, b0), Vector2.new(a1 - a0, b1 - b0)
							x0, y0 = math.min(x0, p.X), math.min(y0, p.Y)
							x1, y1 = math.max(x1, p.X + s.X), math.max(y1, p.Y + s.Y)
							local c = d.BackgroundColor3
							local text = if d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox") then clean(d.Text) else ""
							table.insert(lines, string.format("UI %s %s|%s|%d|%d|%d|%d|%d|%d|%d|%.2f|%s", tag, screen.Name, d.ClassName,
								math.floor(p.X), math.floor(p.Y), math.floor(s.X), math.floor(s.Y),
								math.floor(c.R * 255), math.floor(c.G * 255), math.floor(c.B * 255), d.BackgroundTransparency, text))
						end
					end
					if x1 > x0 then
						table.insert(lines, string.format("UI %s WIDGET %s/%s|%d|%d|%d|%d", tag, screen.Name, top.Name, math.floor(x0), math.floor(y0), math.floor(x1 - x0), math.floor(y1 - y0)))
					end
				end
			end
		end
	end
	table.insert(steps, "UIDUMP " .. table.concat(lines, string.char(10)))
end

local function run()
	local gui = player:WaitForChild("PlayerGui")
	gui:WaitForChild("MailATigerHud", 15)
	gui:WaitForChild("SideButtons", 15)
	local Menus = require(player:WaitForChild("PlayerScripts"):WaitForChild("Client"):WaitForChild("Menus"))
	-- Skip the tutorial panel so the plain HUD shows (it's checked separately below, at each size)
	task.wait(3)
	local camera = workspace.CurrentCamera
	local seen = {}
	local started = os.clock()
	while os.clock() - started < 120 do
		local size = camera.ViewportSize
		local key = string.format("%dx%d", math.floor(size.X), math.floor(size.Y))
		if not seen[key] then
			task.wait(1.5) -- let the layout settle after a resize
			if camera.ViewportSize == size then
				seen[key] = true
				dump("hud_" .. key)
				Menus.Open("Shop")
				task.wait(0.6)
				dump("shop_" .. key)
				Menus.CloseAll()
				task.wait(0.3)
				table.insert(steps, "PASS measured " .. key)
			end
		end
		task.wait(0.25)
	end
end

local ok, err = pcall(run)
if not ok then
	table.insert(steps, "FAIL device test crashed: " .. tostring(err))
end
ReplicatedStorage:WaitForChild("E2EReport"):FireServer({ Steps = steps, Errors = clientErrors })
