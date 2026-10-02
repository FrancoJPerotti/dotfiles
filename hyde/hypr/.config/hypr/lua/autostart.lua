-- Event-driven startup engine. Edit startup entries/order in apps.lua.
-- Requires ctx.apps and ctx.appHelpers; returns startDesktopApplications().
-- Startup progresses through sequential, parallel and last stages, skipping
-- existing windows. Events or a five-second timeout advance the sequence.
return function(ctx)
	local stages = { sequential = {}, parallel = {}, last = {} }
	for _, app in ipairs(ctx.apps) do
		if app.startup then
			table.insert(stages[app.startup], app)
		end
	end

	local state = {
		running = false,
		sequentialIndex = 0,
		waitingFor = nil,
		waitTimer = nil,
		regularPending = nil,
		finishing = false,
	}

	local findWindow = ctx.appHelpers.findWindow
	local matchWindow = ctx.appHelpers.matchWindow

	local function cancelWaitTimer()
		if state.waitTimer then
			state.waitTimer:set_enabled(false)
			state.waitTimer = nil
		end
	end

	local finishStartup
	local launchRegularApps
	local launchNextSequential

	finishStartup = function()
		if state.finishing then
			return
		end

		state.finishing = true
		cancelWaitTimer()
		state.waitingFor = nil
		state.regularPending = nil

		for _, app in ipairs(stages.last) do
			if not findWindow(app) then
				hl.exec_cmd(app.command)
			end
		end

		hl.timer(function()
			hl.dispatch(hl.dsp.focus({ workspace = "1" }))
			state.running = false
			state.finishing = false
		end, { timeout = 500, type = "oneshot" })
	end

	local function regularAppReady(window)
		if not state.regularPending then
			return false
		end

		for id, app in pairs(state.regularPending) do
			if matchWindow(app, window) then
				state.regularPending[id] = nil
			end
		end

		if next(state.regularPending) == nil then
			finishStartup()
		end
		return true
	end

	launchRegularApps = function()
		state.waitingFor = nil
		state.regularPending = {}

		for _, app in ipairs(stages.parallel) do
			if not findWindow(app) then
				state.regularPending[app.id] = app
				hl.exec_cmd(app.command)
			end
		end

		if next(state.regularPending) == nil then
			finishStartup()
			return
		end

		state.waitTimer = hl.timer(function()
			state.waitTimer = nil
			finishStartup()
		end, { timeout = 5000, type = "oneshot" })
	end

	launchNextSequential = function()
		cancelWaitTimer()
		state.waitingFor = nil
		state.sequentialIndex = state.sequentialIndex + 1

		while state.sequentialIndex <= #stages.sequential and findWindow(stages.sequential[state.sequentialIndex]) do
			state.sequentialIndex = state.sequentialIndex + 1
		end

		if state.sequentialIndex > #stages.sequential then
			launchRegularApps()
			return
		end

		local app = stages.sequential[state.sequentialIndex]
		state.waitingFor = app
		hl.exec_cmd(app.command)
		state.waitTimer = hl.timer(function()
			state.waitTimer = nil
			launchNextSequential()
		end, { timeout = 5000, type = "oneshot" })
	end

	local function onWindowAvailable(window)
		if not state.running then
			return
		end

		if state.waitingFor and matchWindow(state.waitingFor, window) then
			launchNextSequential()
			return
		end

		regularAppReady(window)
	end

	-- Chromium PWAs can acquire their final class just after mapping, so handle
	-- both the initial window and subsequent class-change events.
	hl.on("window.open", onWindowAvailable)
	hl.on("window.class", onWindowAvailable)

	return function()
		if state.running then
			return
		end

		state.running = true
		state.finishing = false
		state.sequentialIndex = 0
		state.regularPending = nil
		launchNextSequential()
	end
end
