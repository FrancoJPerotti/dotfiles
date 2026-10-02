-- Session lifecycle hooks and external service startup.
-- Requires ctx.machine and ctx.startDesktopApplications, built in hyprland.lua.
return function(ctx)
	hl.on("hyprland.start", function()
		hl.exec_cmd("wlsunset -t 4500 -l -31.4 -L -64.1")
		hl.exec_cmd("kdeconnect-cli -n Galaxy\\ S20")
		hl.exec_cmd("/usr/bin/handy --start-hidden")
		if ctx.machine.kanata then
			hl.exec_cmd(ctx.home .. "/.local/bin/kanata_up.sh --ensure")
		end
		-- hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE DISPLAY")
		-- hl.exec_cmd("systemctl --user start easyeffects.service")
	end)

	hl.on("hyprland.start", function()
		ctx.startDesktopApplications()
		hl.exec_cmd(ctx.home .. "/.config/hypr/screenshare_start.sh")
	end)

	-- HyDE reloads the config shortly after login while applying the wallpaper
	-- and theme. Reloading recreates the Lua state and cancels the startup
	-- timers, so resume the idempotent sequence from the first missing app.
	hl.on("config.reloaded", function()
		if ctx.machine.kanata then
			-- Sync device visibility without re-enabling a manually stopped remapper.
			hl.exec_cmd(ctx.home .. "/.local/bin/kanata_up.sh --sync-devices")
		end
		ctx.startDesktopApplications()
	end)
end
