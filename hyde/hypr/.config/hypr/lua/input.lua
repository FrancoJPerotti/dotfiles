-- Keyboard, pointer, per-device and gesture configuration.
return function(_)
	hl.config({
		input = {
			kb_layout = "us",
			kb_variant = "intl",
			follow_mouse = 1,
			touchpad = {
				natural_scroll = true,
			},
			virtualkeyboard = {
				-- Kanata owns modifiers and lock state; avoid stale raw state.
				share_states = 0,
			},
			sensitivity = 0,
			force_no_accel = true,
		},
	})

	hl.device({
		name = "epic-mouse-v1",
		sensitivity = 0.5,
	})

	-- Match the raw hardware fallback to Kanata's Caps-to-Super mapping.
	hl.device({
		name = "at-translated-set-2-keyboard",
		kb_options = "caps:super,shift:breaks_caps",
	})

	hl.device({
		name = "asup1415:00-093a:300c-keyboard",
		kb_options = "caps:super,shift:breaks_caps",
	})

	hl.gesture({
		fingers = 3,
		direction = "horizontal",
		action = "workspace",
	})
end
