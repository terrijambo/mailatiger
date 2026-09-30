--!strict
-- Everything Postmaster Gruff says. Add lines freely; one is picked at random.

return {
	BagFull = "Your mail bag is stuffed! Mail those parcels at the chute first.",
	AlreadyBoxing = "Finish the one you've got. Use the Pen again within 5 seconds to give up on it.",
	GaveUp = "Quitter. Fine. It's going back in the pen.",
	NotYours = "That's not YOUR animal. Hands off.",
	TooPoor = "You can't afford that. Box more hamsters.",
	NeedsCoop = "That one takes a whole crew to box. Not yet.",
	TooFar = "Come back to the Pen counter if you want an animal.",

	Ratings = {
		[1] = {
			"Is that a box or a pancake?",
			"The customer is going to write a letter. To ME.",
			"I've seen raccoons pack better.",
		},
		[2] = {
			"Dented. Scuffed. Smells weird. Typical.",
			"Two stamps. Be grateful it's not one.",
		},
		[3] = {
			"Mediocre. Like my lunch.",
			"It's in a box. That's all I'll say.",
		},
		[4] = {
			"Hmph. Not terrible.",
			"Almost acceptable. Almost.",
		},
		[5] = {
			"...Acceptable.",
			"Hmph. Fine. Don't let it go to your head.",
		},
	},

	Escape = {
		"You LOST it?! Go catch it again!",
		"It got out! Company tape isn't free, you know!",
		"I KNEW I shouldn't have hired you.",
	},

	Breakout = {
		"MY HAT! RETURN TO SENDER! RETURN TO SENDER!",
		"Not in MY post office! GET. IT. OUT.",
	},

	WelcomeBack = {
		"Oh. You're back. The animals won't mail themselves.",
		"Clock in, new hire. There's a hamster with your name on it.",
		"Back again? Good. That pile of animals isn't getting smaller.",
	},

	-- The first-time walkthrough (src/client/Tutorial.luau). One line per step.
	Tutorial = {
		Pen = "You. New hire. We MAIL ANIMALS here. Tap the PEN button (or follow the arrow to the Animal Pen) and pick one.",
		Catch = "There it is! Chase it down, get close, and HOLD E to grab it.",
		Box = "Now BOX it. Rub the ♥ spots to keep it calm, DON'T touch the ✖ spots, and drag tape along every seam.",
		Escaped = "You LOST it?! Catch it again. And rub the ♥ spots faster this time.",
		Mail = "It's taped up and in your bag. Get back to town and HOLD E at the MAIL CHUTE by my counter. Follow the arrow.",
		Shop = "Coins! Spend them at the SUPPLY SHOP on better tools, or unlock bigger animals at the Pen. Now get back to work.",
		Reward = "Here, a little signing bonus. Don't spend it all on tape.",
	},
}
