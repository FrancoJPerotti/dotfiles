-- Select the host's layout through HyDE, which owns Waybar's generated files.
return function(ctx)
	local layout = ctx.machine.waybar_layout
	if not layout then
		return
	end

	local configDir = (os.getenv("XDG_CONFIG_HOME") or (ctx.home .. "/.config")) .. "/waybar"
	local stateFile = (os.getenv("XDG_STATE_HOME") or (ctx.home .. "/.local/state")) .. "/hyde/staterc"

	local function readFile(path)
		local handle = io.open(path, "r")
		if not handle then
			return nil
		end
		local content = handle:read("*a")
		handle:close()
		return content
	end

	local function applyProfile()
		local source = readFile(configDir .. "/layouts/" .. layout .. ".jsonc")
		if not source then
			return
		end

		local selected = nil
		for line in (readFile(stateFile) or ""):gmatch("[^\r\n]+") do
			selected = line:match("^WAYBAR_LAYOUT_NAME=(.*)$") or selected
		end
		if selected == layout and readFile(configDir .. "/config.jsonc") == source then
			return
		end

		hl.exec_cmd("hyde-shell waybar --set " .. layout)
	end

	hl.on("hyprland.start", applyProfile)
	hl.on("config.reloaded", applyProfile)
end
