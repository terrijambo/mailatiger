--!strict
-- The DIVE (Fall Guys style): press Q (keyboard), L1 (controller) or the DIVE button (phone) and you launch
-- yourself flat out, arms first, in the direction you're moving. While you're diving:
--   * animal attacks and the boss's stomp can't hit you (that's how you dodge them)
--   * diving into an animal grabs it instantly, no holding E (that's how you catch the fast ones)
--
-- And animal attacks are punishing: a roar, a freeze, a skunk spray or a charge all VINE BOOM you away as a
-- ragdoll. Wild animals with an attack wind up first (a red "!!" over them) — dive, or get out of range.

return {
	Speed = 58, -- studs/second forward
	Up = 32, -- a little hop so you fly a bit
	Cooldown = 1.1, -- seconds between dives
	DodgeSeconds = 0.85, -- attacks can't hit you for this long after you dive
	MaxAirSeconds = 1.4, -- you're back up by then at the latest
	SlideSeconds = 0.3, -- belly-slide after landing before you get up
	GrabReach = 4.5, -- studs (plus the animal's size): dive into an animal this close and you grab it

	-- Animal attacks (the "twists" in Boxing.luau: Roar, Freeze, Spray, Charge)
	Attack = {
		Out = 55, -- how hard it throws you (sideways)...
		Up = 80, -- ...and up
		RagdollSeconds = 2,
		WindUp = 0.7, -- wild animals: the red "!!" warning before they strike
		Cooldown = 5, -- wild animals: seconds between attacks
		Range = { Roar = 11, Freeze = 10, Spray = 9, Charge = 16 },
	},
}
