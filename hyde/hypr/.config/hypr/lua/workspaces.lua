-- Keep numbered workspaces on the first connected monitor in the host's list.
return function(ctx)
	local initialized = false
	local selectedMonitor = nil
	local pendingRefresh = nil

	local function refresh()
		local primary = nil
		for _, selector in ipairs(ctx.machine.workspace_monitors or {}) do
			primary = hl.get_monitor(selector)
			if primary then
				break
			end
		end

		local name = primary and primary.name or nil
		if initialized and selectedMonitor == name then
			return
		end
		initialized = true
		selectedMonitor = name

		local active = hl.get_active_workspace()
		local moved = false
		for id = 1, 4 do
			-- Rules are replaced by workspace ID, so hotplug does not accumulate rules.
			hl.workspace_rule({ workspace = tostring(id), monitor = name, persistent = true })
			local workspace = hl.get_workspace(tostring(id))
			if primary and workspace and (not workspace.monitor or workspace.monitor.name ~= name) then
				hl.dispatch(hl.dsp.workspace.move({ workspace = workspace, monitor = primary }))
				moved = true
			end
		end

		-- Preserve the user's active numbered workspace while moving its windows.
		if moved and active and active.id >= 1 and active.id <= 4 then
			hl.dispatch(hl.dsp.focus({ workspace = active }))
		end
	end

	local function scheduleRefresh()
		if pendingRefresh then
			return
		end
		-- Let Hyprland finish adding/removing outputs before moving workspaces.
		pendingRefresh = hl.timer(function()
			pendingRefresh = nil
			refresh()
		end, { timeout = 100, type = "oneshot" })
	end

	hl.on("monitor.layout_changed", scheduleRefresh)
	hl.on("hyprland.start", scheduleRefresh)
	hl.on("config.reloaded", scheduleRefresh)
	refresh()
end
