-- Catalog interpretation only. No events or startup side effects.
-- Rules use RE2 regexes; runtime checks use literal equality/prefixes.
local helpers = {}

function helpers.index(apps)
	local indexed, keys = {}, {}
	for _, app in ipairs(apps) do
		assert(type(app.id) == "string" and app.id ~= "", "apps.lua: every app needs an id")
		assert(not indexed[app.id], "apps.lua: duplicate id " .. app.id)
		indexed[app.id] = app
		if app.key then
			assert(not keys[app.key], "apps.lua: duplicate key " .. app.key)
			keys[app.key] = true
		end
		if app.startup then
			assert(app.startup == "sequential" or app.startup == "parallel" or app.startup == "last",
				"apps.lua: invalid startup stage for " .. app.id)
			assert(app.command and (app.class or app.class_prefix),
				"apps.lua: startup needs command and class/class_prefix for " .. app.id)
		end
	end
	return indexed
end

function helpers.matchWindow(app, window)
	if not window then
		return false
	end
	local class = window.class or ""
	if app.class_prefix then
		local prefix = app.class_prefix .. (app.runtime_suffix or "")
		return class:sub(1, #prefix) == prefix
	end
	return app.class ~= nil and class == app.class
end

function helpers.findWindow(app)
	for _, window in ipairs(hl.get_windows()) do
		if helpers.matchWindow(app, window) then
			return window
		end
	end
end

function helpers.ruleMatch(app)
	if app.match then
		return app.match
	end
	-- Escape literal class names before passing them to Hyprland's regex engine.
	local literal = app.class_prefix or assert(app.class, "apps.lua: missing class for " .. app.id)
	local escaped = literal:gsub("[\\%.%[%]%(%)%{%}%*%+%?%^%$%|]", "\\%0")
	return { class = "^(" .. escaped .. (app.class_prefix and ".*" or "") .. ")$" }
end

return helpers
