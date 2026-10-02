-- Register application shortcuts from apps.lua and the session controls below.
-- Requires ctx.apps, ctx.actions and ctx.machine; does not implement actions.
return function(ctx)
	local bind, exec, mainMod = ctx.bind, ctx.exec, ctx.mainMod

	for _, app in ipairs(ctx.apps) do
		if app.key then
			local action
			if app.action then
				action = assert(ctx.actions[app.action], "Unknown action for app " .. app.id .. ": " .. app.action)
			elseif app.workspace and app.workspace:match("^special:") then
				action = hl.dsp.workspace.toggle_special(app.workspace:match("^special:(.+)$"))
			else
				action = exec(assert(app.command, "Shortcut needs a command for app " .. app.id))
			end
			bind(mainMod .. " + " .. app.key, action, app.bind_options)
		end
	end

	-- Machine-specific keyboard remapping.
	if ctx.machine.kanata then
		bind(mainMod .. " + F11", exec(ctx.home .. "/.local/bin/kanata_up.sh"), {
			description = "toggle kanata layout",
		})
	else
		hl.unbind(mainMod .. " + F11")
	end

	bind("CTRL + T", ctx.actions.browserNewTabOrSearch)

	-- Toggle the active Handy pipeline, even when a different binding started it.
	bind(mainMod .. " + SHIFT + H", exec(ctx.home .. "/.local/bin/handy-smart-toggle.sh transcribe"))
	bind("F10", exec(ctx.home .. "/.local/bin/handy-smart-toggle.sh transcribe"))
	bind(mainMod .. " + SHIFT + K", exec(ctx.home .. "/.local/bin/handy-smart-toggle.sh transcribe_with_post_process"))
end
