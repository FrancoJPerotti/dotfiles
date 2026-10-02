-- Editable general keybindings: compositor, launchers, media and navigation.
-- Custom movement is implemented in behaviors.lua; app shortcuts in apps.lua.
return function(ctx)
	local bind = ctx.bind
	local exec = ctx.exec
	local mainMod = ctx.mainMod
	local scrPath = ctx.scrPath

	-- Window and session actions.
	bind(mainMod .. " + SHIFT + P", exec("hyprpicker -a"), { description = "Color Picker" })
	bind("F12", hl.dsp.window.close())
	bind("ALT + F4", exec(scrPath .. "/dontkillsteam.sh"))
	bind(mainMod .. " + DELETE", hl.dsp.exit())
	bind(mainMod .. " + SHIFT + F", hl.dsp.window.float({ action = "toggle" }))
	bind(mainMod .. " + SHIFT + N", hl.dsp.window.pin())
	bind(mainMod .. " + SHIFT + G", hl.dsp.group.toggle())
	bind(mainMod .. " + SHIFT + equal", exec(scrPath .. "/logoutlaunch.sh"))
	bind(mainMod .. " + plus", exec(scrPath .. "/logoutlaunch.sh"))
	bind(mainMod .. " + SHIFT + 9", exec("dunstctl close-all"))

	-- Rofi menus.
	bind(mainMod .. " + RETURN", exec("pkill -x rofi || " .. scrPath .. "/rofilaunch.sh d"))
	bind(mainMod .. " + SHIFT + RETURN", exec("pkill -x rofi || " .. scrPath .. "/rofi_websearch.sh"))
	bind(mainMod .. " + SHIFT + E", exec("pkill -x rofi || " .. scrPath .. "/custom_emoji_picker.sh"), {
		description = "$d emoji  picker ",
	})
	bind(mainMod .. " + SHIFT + A", exec("pkill -x rofi || " .. scrPath .. "/rofiselect.sh"), {
		description = "$d select rofi launcher ",
	})
	bind(mainMod .. " + SHIFT + W", exec("pkill -x rofi || " .. scrPath .. "/wallpaper.sh -SG"), {
		description = "$d select a global wallpaper ",
	})
	bind(mainMod .. " + SHIFT + L", exec("pkill -x rofi || " .. scrPath .. "/hyprlock.sh --select"), {
		description = "$d select hyprlock layout",
	})
	bind(mainMod .. " + SHIFT + T", exec("pkill -x rofi || " .. scrPath .. "/themeselect.sh"), {
		description = "$d select a theme",
	})
	bind(mainMod .. " + SHIFT + U", exec("hyde-shell system.update up"), {
		description = "$d update system",
	})

	-- Audio, media and brightness.
	bind("XF86AudioMute", exec(scrPath .. "/volumecontrol.sh -o m"), { locked = true })
	bind(mainMod .. " + J", exec(scrPath .. "/volumecontrol.sh -i m"), { locked = true })
	bind("XF86AudioLowerVolume", exec(scrPath .. "/volumecontrol.sh -o d"), { locked = true, repeating = true })
	bind("XF86AudioRaiseVolume", exec(scrPath .. "/volumecontrol.sh -o i"), { locked = true, repeating = true })
	bind("XF86AudioPlay", exec("playerctl play-pause"), { locked = true })
	bind("XF86AudioPause", exec("playerctl play-pause"), { locked = true })
	bind("XF86AudioNext", exec("playerctl next"), { locked = true })
	bind("XF86AudioPrev", exec("playerctl previous"), { locked = true })
	bind("XF86MonBrightnessUp", exec(scrPath .. "/brightnesscontrol.sh i"), { locked = true, repeating = true })
	bind("XF86MonBrightnessDown", exec(scrPath .. "/brightnesscontrol.sh d"), { locked = true, repeating = true })

	-- Screenshots and clipboard.
	bind(mainMod .. " + P", exec(scrPath .. "/screenshot.sh s"))
	bind("Print", exec(scrPath .. "/screenshot.sh p"))
	bind(mainMod .. " + C", exec("pkill -x rofi || " .. scrPath .. "/custom_cliphist.sh -c"), {
		description = "$d clipboard ",
	})
	bind(mainMod .. " + SHIFT + C", exec("pkill -x rofi || " .. scrPath .. "/cliphist.sh"), {
		description = "$d clipboard manager ",
	})

	-- Focus, groups and workspaces.
	bind(mainMod .. " + N", hl.dsp.focus({ direction = "left" }))
	bind(mainMod .. " + O", hl.dsp.focus({ direction = "right" }))
	bind(mainMod .. " + I", hl.dsp.focus({ direction = "up" }))
	bind(mainMod .. " + E", hl.dsp.focus({ direction = "down" }))
	bind(mainMod .. " + U", hl.dsp.group.prev())
	bind(mainMod .. " + Y", hl.dsp.group.next())
	bind(mainMod .. " + h", hl.dsp.focus({ workspace = "1" }))
	bind(mainMod .. " + SHIFT + slash", hl.dsp.focus({ workspace = "2" }))
	bind(mainMod .. " + question", hl.dsp.focus({ workspace = "2" }))
	bind(mainMod .. " + dead_acute", hl.dsp.focus({ workspace = "3" }))
	bind(mainMod .. " + dead_grave", hl.dsp.focus({ workspace = "4" }))
	bind(mainMod .. " + V", hl.dsp.focus({ workspace = "5" }))
	bind(mainMod .. " + ntilde", hl.dsp.focus({ workspace = "r+1" }))
	bind(mainMod .. " + L", hl.dsp.focus({ workspace = "r-1" }))
	bind(mainMod .. " + END", hl.dsp.window.move({ workspace = "r+1" }))
	bind(mainMod .. " + HOME", hl.dsp.window.move({ workspace = "r-1" }))
	bind(mainMod .. " + CTRL + Left", hl.dsp.group.move_window("b"))
	bind(mainMod .. " + CTRL + Right", hl.dsp.group.move_window("f"))

	-- Keyboard window resize.
	bind(mainMod .. " + ALT + N", hl.dsp.window.resize({ x = -20, y = 0, relative = true }), { repeating = true })
	bind(mainMod .. " + ALT + O", hl.dsp.window.resize({ x = 20, y = 0, relative = true }), { repeating = true })
	bind(mainMod .. " + ALT + I", hl.dsp.window.resize({ x = 0, y = -20, relative = true }), { repeating = true })
	bind(mainMod .. " + ALT + E", hl.dsp.window.resize({ x = 0, y = 20, relative = true }), { repeating = true })

	local moveActiveWindow = ctx.actions.moveActiveWindow

	bind(mainMod .. " + left", moveActiveWindow("l", -30, 0), {
		repeating = true,
		description = "Move active window left or into group",
	})
	bind(mainMod .. " + right", moveActiveWindow("r", 30, 0), {
		repeating = true,
		description = "Move active window right or into group",
	})
	bind(mainMod .. " + up", moveActiveWindow("u", 0, -30), {
		repeating = true,
		description = "Move active window up or into group",
	})
	bind(mainMod .. " + down", moveActiveWindow("d", 0, 30), {
		repeating = true,
		description = "Move active window down or into group",
	})

	bind("ALT + mouse:272", hl.dsp.window.drag(), { mouse = true })
	bind("ALT + mouse:273", hl.dsp.window.resize(), { mouse = true })
end
