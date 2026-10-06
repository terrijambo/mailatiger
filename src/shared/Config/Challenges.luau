--!strict
-- Daily and weekly challenges (shown on Gruff's Orders board). Every day you get 3 dailies, every week one
-- bigger weekly. They pay diamonds plus coins, and finishing all 3 dailies on days in a row grows a
-- streak bonus. Challenges are picked from the pools below, only from ones you can actually do at your level.
--
--   Kind      what counts: "Box" (a finished box), "Mail" (an animal mailed), "Order" (a side order done),
--             "Streak" (your delivery streak reaching Count), "Troll" (a troll item used)
--   Count     how many (for "Streak": how high)
--   MinStars / MaxSeconds / Chaos / Variant   extra conditions on the box or mail
--   MinLevel  only offered from this level up
--   Diamonds, Jobs   the reward (Jobs = coins worth that many jobs of your best animal)

export type Challenge = {
	Id: string,
	Text: string, -- {n} becomes Count
	Kind: string,
	Count: number,
	MinStars: number?,
	MaxSeconds: number?,
	Chaos: boolean?,
	Variant: boolean?, -- any Shiny or Golden
	MinLevel: number?,
	NeedsTroll: boolean?,
	Diamonds: number,
	Jobs: number,
}

local daily: { Challenge } = {
	{ Id = "Mail8", Text = "Mail {n} animals", Kind = "Mail", Count = 8, Diamonds = 3, Jobs = 4 },
	{
		Id = "Stars4",
		Text = "Box {n} animals with 4+ stamps",
		Kind = "Box",
		Count = 5,
		MinStars = 4,
		Diamonds = 4,
		Jobs = 4,
	},
	{
		Id = "Stars5",
		Text = "Get {n} perfect 5-stamp jobs",
		Kind = "Box",
		Count = 2,
		MinStars = 5,
		Diamonds = 5,
		Jobs = 5,
	},
	{
		Id = "Fast",
		Text = "Finish {n} jobs in under 45 seconds",
		Kind = "Box",
		Count = 3,
		MaxSeconds = 45,
		Diamonds = 4,
		Jobs = 4,
	},
	{ Id = "Orders3", Text = "Complete {n} of Gruff's side orders", Kind = "Order", Count = 3, Diamonds = 4, Jobs = 5 },
	{ Id = "Streak4", Text = "Reach a delivery streak of {n}", Kind = "Streak", Count = 4, Diamonds = 4, Jobs = 4 },
	{
		Id = "Chaos2",
		Text = "Finish {n} jobs in Chaos Mode",
		Kind = "Box",
		Count = 2,
		Chaos = true,
		MinLevel = 3,
		Diamonds = 5,
		Jobs = 5,
	},
	{
		Id = "Troll5",
		Text = "Use troll items {n} times",
		Kind = "Troll",
		Count = 5,
		NeedsTroll = true,
		Diamonds = 4,
		Jobs = 3,
	},
}

local weekly: { Challenge } = {
	{ Id = "WMail60", Text = "Mail {n} animals", Kind = "Mail", Count = 60, Diamonds = 20, Jobs = 30 },
	{
		Id = "WStars5",
		Text = "Get {n} perfect 5-stamp jobs",
		Kind = "Box",
		Count = 15,
		MinStars = 5,
		Diamonds = 25,
		Jobs = 30,
	},
	{ Id = "WOrders", Text = "Complete {n} side orders", Kind = "Order", Count = 20, Diamonds = 20, Jobs = 30 },
	{ Id = "WStreak", Text = "Reach a delivery streak of {n}", Kind = "Streak", Count = 10, Diamonds = 25, Jobs = 30 },
	{
		Id = "WShiny",
		Text = "Mail {n} Shiny or Golden animals",
		Kind = "Mail",
		Count = 2,
		Variant = true,
		Diamonds = 25,
		Jobs = 30,
	},
}

local byId: { [string]: Challenge } = {}
for _, list in { daily, weekly } do
	for _, challenge in list do
		byId[challenge.Id] = challenge
	end
end

local Challenges = {
	Daily = daily,
	Weekly = weekly,
	ById = byId,
	DailyCount = 3,
	-- Finishing all 3 dailies: this many diamonds, plus StreakDiamonds for each day in a row (up to MaxStreak)
	AllDailiesDiamonds = 3,
	StreakDiamonds = 1,
	MaxStreak = 7,
}

function Challenges.Text(challenge: Challenge): string
	return (string.gsub(challenge.Text, "{n}", tostring(challenge.Count)))
end

-- Days and weeks (UTC). Weeks start on Monday.
function Challenges.Day(now: number): number
	return now // 86400
end

function Challenges.Week(now: number): number
	return (now + 3 * 86400) // 604800
end

return Challenges
