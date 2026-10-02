-- Apply only the monitor specifications belonging to this computer.
return function(ctx)
	for _, monitor in ipairs(ctx.machine.monitors or {}) do
		hl.monitor(monitor)
	end
end
