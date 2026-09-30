--!strict
-- Describes your current main quest (Config/Quests.luau) for the HUD tracker and the Orders window:
-- what to do, how far along you are (e.g. "1/3"), and how full the progress bar should be.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Profile = require(script.Parent.Profile)

local QuestText = {}

export type Info = {
	Number: number,
	Text: string,
	Progress: string, -- "1/3", "Lv 3/4"...
	Fraction: number, -- 0..1
	XP: number,
	Done: boolean, -- every quest finished
}

function QuestText.Current(): Info
	local data = Profile.Get()
	local index = data.Quest or 1
	local quest = Config.Quests[index]
	if not quest then
		return {
			Number = index,
			Text = "All of Gruff's quests done! Rebirth for a permanent coin bonus.",
			Progress = "",
			Fraction = 1,
			XP = 0,
			Done = true,
		}
	end
	local have, need = 0, 1
	if quest.Type == "Mail" or quest.Type == "Orders" then
		have, need = data.QuestProgress or 0, quest.Count or 1
	elseif quest.Type == "Own" then
		have = if data.Owned[quest.Animal or ""] then 1 else 0
	elseif quest.Type == "Level" then
		have, need = data.Level or 1, quest.Level or 1
	elseif quest.Type == "Tool" then
		have, need = data.Tools[quest.Tool or ""] or 0, quest.Level or 1
	elseif quest.Type == "Chute" then
		have = if (Config.Mail.ChuteIndex[data.ChuteTier] or 1)
				>= (Config.Mail.ChuteIndex[quest.Chute or ""] or 99)
			then 1
			else 0
	elseif quest.Type == "Troll" then
		have = if data.Trolls and data.Trolls[quest.Troll or ""] then 1 else 0
	end
	local progress = if quest.Type == "Level" then `Lv {have}/{need}` elseif need > 1 then `{have}/{need}` else ""
	return {
		Number = index,
		Text = quest.Text,
		Progress = progress,
		Fraction = math.clamp(have / need, 0, 1),
		XP = quest.XP,
		Done = false,
	}
end

return QuestText
