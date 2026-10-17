-- Remove the laptop panel from the layout while docked with the lid closed.
-- logind handles suspension separately (HandleLidSwitchDocked=ignore by default).
return function(ctx)
	local lid = ctx.machine.lid
	if not lid then return end
	local panel
	for _, spec in ipairs(ctx.machine.monitors or {}) do
		if spec.output == lid.output then panel = spec; break end
	end
	if not panel then return end

	local function readClosed()
		local state = io.open(lid.state_file, "r")
		if not state then return nil end
		local contents = state:read("*a") or ""
		state:close()
		if contents:match("closed") then return true end
		if contents:match("open") then return false end
		return nil
	end

	local closed = readClosed()
	local applied, pending
	local function refresh()
		if closed == nil then return end
		local external = false
		for _, spec in ipairs(ctx.machine.monitors or {}) do
			if spec.output ~= lid.output and hl.get_monitor(spec.output) then external = true; break end
		end
		-- Keep a usable panel if the external monitor is disconnected.
		local disabled = closed and external
		if applied == disabled then return end
		local rule = {}
		for key, value in pairs(panel) do rule[key] = value end
		rule.disabled = disabled
		hl.monitor(rule)
		applied = disabled
	end
	local function scheduleRefresh()
		if pending then return end
		pending = hl.timer(function() pending = nil; refresh() end, { timeout = 100, type = "oneshot" })
	end
	local function syncState()
		local value = readClosed()
		if value ~= nil then closed = value end
		scheduleRefresh()
	end

	ctx.bind("switch:on:Lid Switch", function() closed = true; scheduleRefresh() end, { locked = true })
	ctx.bind("switch:off:Lid Switch", function() closed = false; scheduleRefresh() end, { locked = true })
	hl.on("monitor.layout_changed", scheduleRefresh)
	hl.on("hyprland.start", syncState)
	hl.on("config.reloaded", syncState)
	refresh()
end
