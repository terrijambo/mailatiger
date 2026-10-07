--!strict
-- The Post Office machines and the chute's income (rules and numbers: Config/Machines.luau).
--   * Buy a machine (Supply Shop > Machines, or at the machine itself) once your chute level reaches it.
--   * Hold E at a machine you own to drop in the parcels in your bag it hasn't stamped yet. It works for a few
--     seconds (they're saved inside it, so nothing is lost if you leave), then hold E again to collect them,
--     stamped. Each stamp multiplies that parcel's XP when it's mailed (ProgressionService).
--   * Every few seconds the chute pays you your coins-per-minute share (Economy.ChuteRate).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Analytics = require(script.Parent.Analytics)
local DataService = require(script.Parent.DataService)
local Economy = require(script.Parent.Economy)
local MailService = require(script.Parent.MailService)
local MapBuilder = require(script.Parent.MapBuilder)
local Remotes = require(script.Parent.Remotes)

local Machines = Config.Machines

local MachineService = {}

local function say(player: Player, text: string)
	Remotes.Notify:FireClient(player, "Message", { Speaker = "Postmaster Gruff", Text = text })
end

-- Buys a machine. Returns whether it worked (and tells the player why not).
function MachineService.Buy(player: Player, machineId: string): boolean
	local profile = DataService.Get(player)
	local machine = Machines.ById[machineId]
	if not profile or not machine or profile.Machines[machineId] then
		return false
	end
	if profile.Level < machine.Level then
		say(player, `The {machine.DisplayName} needs a Level {machine.Level} chute. Keep mailing!`)
		return false
	end
	local price = Machines.Price(machine)
	if not Economy.TrySpend(player, price, `Machine_{machineId}`) then
		say(player, `The {machine.DisplayName} costs {Format.Short(price)} coins.`)
		return false
	end
	profile.Machines[machineId] = true
	Analytics.Custom(player, `Machine_{machineId}`, profile.Level)
	Remotes.Notify:FireClient(player, "MachineBought", {
		Id = machineId,
	})
	say(
		player,
		`{machine.Emoji} {machine.DisplayName} installed! Drop your parcels in it for x{string.format(
			"%g",
			machine.XPMult
		)} XP each.`
	)
	Economy.Sync(player)
	return true
end

-- Hold E at a machine: buy it, drop parcels in, or collect the finished ones
function MachineService.Use(player: Player, machineId: string)
	local profile = DataService.Get(player)
	local machine = Machines.ById[machineId]
	if not profile or not machine then
		return
	end
	-- Parcels already inside: collect them when they're done (even if a rebirth took the machine away)
	local batch = profile.Processing[machineId]
	if batch then
		local left = batch.ReadyAt - os.time()
		if left > 0 then
			say(player, `The {machine.DisplayName} is still working on your parcels: {left}s to go.`)
			return
		end
		local collected = 0
		local kept: { DataService.Parcel } = {}
		for _, parcel in batch.Parcels do
			if MailService.HasRoom(player) then
				parcel.Machines = parcel.Machines or {}
				(parcel.Machines :: { [string]: boolean })[machineId] = true
				table.insert(profile.Parcels, parcel)
				collected += 1
			else
				table.insert(kept, parcel)
			end
		end
		if #kept > 0 then
			batch.Parcels = kept
			say(
				player,
				`Your bag is full! {#kept} parcel{if #kept == 1 then "" else "s"} still waiting in the {machine.DisplayName}.`
			)
		else
			profile.Processing[machineId] = nil
		end
		Remotes.Notify:FireClient(player, "MachineCollected", {
			Id = machineId,
			Count = collected,
			XPMult = machine.XPMult,
		})
		MailService.RefreshCarried(player)
		Economy.Sync(player)
		return
	end
	if not profile.Machines[machineId] then
		MachineService.Buy(player, machineId)
		return
	end
	-- Drop in every parcel in the bag this machine hasn't stamped yet
	local dropped: { DataService.Parcel } = {}
	local stay: { DataService.Parcel } = {}
	for _, parcel in profile.Parcels do
		if parcel.Machines and parcel.Machines[machineId] then
			table.insert(stay, parcel)
		else
			table.insert(dropped, parcel)
		end
	end
	if #dropped == 0 then
		say(
			player,
			if #profile.Parcels == 0
				then "Your bag is empty. Go box an animal, then bring the parcel here!"
				else `Everything in your bag already has the {machine.DisplayName}'s stamp. Try another machine, or mail it!`
		)
		return
	end
	profile.Parcels = stay
	profile.Processing[machineId] = { Parcels = dropped, ReadyAt = os.time() + machine.Seconds }
	Remotes.Notify:FireClient(player, "MachineStarted", { Id = machineId, Count = #dropped, Seconds = machine.Seconds })
	MailService.RefreshCarried(player)
	Economy.Sync(player)
end

function MachineService.Start(map: MapBuilder.Map)
	-- Hold E at a machine to buy it, drop parcels in, or collect them (the client words the prompt for you)
	for machineId, station in map.Machines do
		local use = station:FindFirstChild("UsePrompt") :: ProximityPrompt?
		if use then
			use.Triggered:Connect(function(player: Player)
				MachineService.Use(player, machineId)
			end)
		end
	end
	-- Tell players when a machine has finished their parcels
	task.spawn(function()
		local told: { [Player]: { [string]: number } } = {}
		while true do
			task.wait(1)
			local now = os.time()
			for player, profile in DataService.GetAll() do
				local mine = told[player] or {}
				told[player] = mine
				for machineId, batch in profile.Processing do
					if batch.ReadyAt <= now and mine[machineId] ~= batch.ReadyAt then
						mine[machineId] = batch.ReadyAt
						local machine = Machines.ById[machineId]
						Remotes.Notify:FireClient(player, "MachineReady", {
							Id = machineId,
							Name = if machine then machine.DisplayName else machineId,
							Count = #batch.Parcels,
						})
					end
				end
			end
			for player in told do
				if player.Parent == nil then
					told[player] = nil
				end
			end
		end
	end)

	-- The chute pays out in small chunks every few seconds (so the coins keep ticking up)
	task.spawn(function()
		local every = Machines.PayEverySeconds
		while true do
			task.wait(every)
			for player in DataService.GetAll() do
				local coins = math.floor(Economy.ChuteRate(player) * every / 60)
				if coins > 0 then
					Economy.AddCoins(player, coins, "Chute")
				end
			end
		end
	end)
end

return MachineService
