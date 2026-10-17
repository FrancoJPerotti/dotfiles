-- Stow supplies the user service and scripts; loading Lua activates it.
return function(ctx)
	if not ctx.machine.kanata then return end
	local policy = io.open(ctx.home .. "/.config/kanata/firmware-keyboards.conf", "r")
	if not policy then return end
	local configured = false
	for line in policy:lines() do
		local host, vendor, product = line:match("^%s*(%S+)%s+(%x%x%x%x):(%x%x%x%x)")
		if host == ctx.hostname and vendor and product then configured = true; break end
	end
	policy:close()
	if not configured then return end

	local watcher = string.format("%q", ctx.home .. "/.local/bin/kanata-watch.sh")
	-- This also runs on reload. The helper imports the session environment,
	-- reloads user units and starts the singleton service.
	hl.exec_cmd(watcher .. " --start")
	hl.on("hyprland.shutdown", function() hl.exec_cmd(watcher .. " --stop") end)
end
