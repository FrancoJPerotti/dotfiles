-- A deterministic event loop for testing personal Lua behavior without a
-- compositor. Dispatches are recorded; no real apps or windows are touched.
return function()
	local env = {
		windows = {}, commands = {}, dispatches = {}, bindings = {}, unbound = {},
		windowRules = {}, layerRules = {}, workspaceRules = {}, events = {}, timers = {},
		monitors = {}, workspaces = {}, now = 0,
	}

	local function dispatcher(path)
		return setmetatable({}, {
			__index = function(_, name) return dispatcher(path == "" and name or path .. "." .. name) end,
			__call = function(_, ...) return { operation = path, args = { ... } } end,
		})
	end

	function env.emit(event, payload)
		for _, callback in ipairs(env.events[event] or {}) do callback(payload) end
	end

	function env.advance(milliseconds)
		local target = env.now + milliseconds
		while true do
			local nextTimer
			for _, timer in ipairs(env.timers) do
				if timer.enabled and timer.deadline <= target
					and (not nextTimer or timer.deadline < nextTimer.deadline) then nextTimer = timer end
			end
			if not nextTimer then break end
			env.now, nextTimer.enabled = nextTimer.deadline, false
			nextTimer.callback()
		end
		env.now = target
	end

	function env.addWindow(class)
		local window = { class = class }
		table.insert(env.windows, window)
		env.emit("window.open", window)
		return window
	end

	local api = { dsp = dispatcher("") }
	function api.on(event, callback)
		env.events[event] = env.events[event] or {}
		table.insert(env.events[event], callback)
	end
	function api.timer(callback, options)
		local timer = { callback = callback, deadline = env.now + options.timeout, enabled = true }
		function timer:set_enabled(enabled) self.enabled = enabled end
		table.insert(env.timers, timer)
		return timer
	end
	function api.get_windows(filter)
		if not filter then return env.windows end
		local windows = {}
		for _, window in ipairs(env.windows) do
			if window.class == filter.class then table.insert(windows, window) end
		end
		return windows
	end
	function api.get_active_window() return env.activeWindow end
	function api.get_active_workspace() return env.activeWorkspace end
	function api.get_active_special_workspace() return env.activeSpecial end
	function api.get_workspace(id) return env.workspaces[id] end
	function api.get_monitor(selector) return env.monitors[selector] end
	function api.exec_cmd(command) table.insert(env.commands, command) end
	function api.bind(keys, action, options) env.bindings[keys] = { action = action, options = options } end
	function api.unbind(keys) env.bindings[keys] = nil; table.insert(env.unbound, keys) end
	function api.window_rule(rule) table.insert(env.windowRules, rule) end
	function api.layer_rule(rule) table.insert(env.layerRules, rule) end
	function api.workspace_rule(rule) env.workspaceRules[rule.workspace] = rule end
	function api.dispatch(action)
		table.insert(env.dispatches, action)
		local argument = action.args[1]
		if action.operation == "workspace.move" then
			argument.workspace.monitor = argument.monitor
		elseif action.operation == "focus" then
			env.activeWorkspace = argument.workspace
		elseif action.operation == "workspace.toggle_special" then
			env.activeSpecial = { name = "special:" .. argument }
			if env.focusOnToggle then env.emit("window.active", env.focusOnToggle) end
		end
	end
	-- These configuration calls are validated by a real reload, not simulated.
	function api.config(_) end
	function api.env(_, _) end
	function api.animation(_) end
	function api.device(_) end
	function api.gesture(_) end
	function api.monitor(_) end

	_G.hl = api
	return env
end
