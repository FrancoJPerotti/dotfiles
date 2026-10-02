-- Run from any directory: lua /path/to/dotfiles/tests/hypr/run.lua [config-dir]
local root = arg[0]:match("^(.*)/tests/hypr/run%.lua$") or "."
local configDir = arg[1] or root .. "/hyde/hypr/.config/hypr"
local luaDir = configDir .. "/lua/"
local fake = dofile(root .. "/tests/hypr/fake_hyprland.lua")
local passed, failed = 0, 0

local function same(actual, expected, message)
	assert(actual == expected, (message or "Unexpected value") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

local function test(name, callback)
	local ok, err = xpcall(callback, debug.traceback)
	if ok then passed = passed + 1; print("PASS " .. name)
	else failed = failed + 1; io.stderr:write("FAIL " .. name .. "\n" .. err .. "\n") end
end

local function setup(apps)
	local env = fake()
	local ctx = {
		home = "/test/home", scrPath = "/test/home/.local/lib/hyde", mainMod = "SUPER",
		machine = { kanata = false }, apps = apps or dofile(luaDir .. "apps.lua"),
		appHelpers = dofile(luaDir .. "app_helpers.lua"),
	}
	ctx.bind = function(keys, action, options) hl.unbind(keys); hl.bind(keys, action, options) end
	ctx.exec = function(command) return hl.dsp.exec_cmd(command) end
	ctx.appsById = ctx.appHelpers.index(ctx.apps)
	ctx.actions = dofile(luaDir .. "behaviors.lua")(ctx)
	ctx.startDesktopApplications = dofile(luaDir .. "autostart.lua")(ctx)
	return env, ctx
end

local function readyWindows(env)
	for _, class in ipairs({ "vivaldi-spotify.com__-Default", "vivaldi-web.whatsapp.com__-Default",
		"vivaldi-ticktick.com__-Default", "vivaldi-chatgpt.com__-Default", "nvim", "term", "yazi", "vivaldi-stable" }) do
		env.addWindow(class)
	end
end

test("startup preserves app order, handles late classes and skips duplicate starts", function()
	local env, ctx = setup()
	ctx.startDesktopApplications()
	same(env.commands[1], "/opt/vivaldi/vivaldi --app=https://spotify.com")
	ctx.startDesktopApplications()
	same(#env.commands, 1)
	local window = env.addWindow("temporary-vivaldi-class")
	same(#env.commands, 1)
	window.class = "vivaldi-spotify.com__-Default"
	env.emit("window.class", window)
	same(env.commands[2], "/opt/vivaldi/vivaldi --app=https://web.whatsapp.com")
	env.addWindow("vivaldi-web.whatsapp.com__-Default")
	same(env.commands[3], "/opt/vivaldi/vivaldi --app=https://ticktick.com")
	env.addWindow("vivaldi-ticktick.com__-Default")
	same(env.commands[4], "/opt/vivaldi/vivaldi --app=https://chatgpt.com")
	env.addWindow("vivaldi-chatgpt.com__-Default")
	same(env.commands[5], "kitty --class nvim --title nvim nvim")
	same(env.commands[6], "kitty --class term")
	same(env.commands[7], "kitty --class yazi --title yazi yazi")
	env.addWindow("nvim"); env.addWindow("term"); env.addWindow("yazi")
	same(env.commands[8], "vivaldi")
	env.addWindow("vivaldi-stable")
	env.advance(500)
	ctx.startDesktopApplications()
	same(#env.commands, 8, "Already-open apps must not launch twice")
end)

test("failed launches advance after timeouts instead of blocking startup", function()
	local env, ctx = setup()
	ctx.startDesktopApplications()
	env.advance(25000)
	same(#env.commands, 8)
	same(env.commands[8], "vivaldi")
	env.advance(500)
	same(env.dispatches[#env.dispatches].args[1].workspace, "1")
end)

test("reload resumes startup from missing apps and desktop never starts Kanata", function()
	local env, ctx = setup()
	env.addWindow("vivaldi-spotify.com__-Default")
	dofile(luaDir .. "events.lua")(ctx)
	env.emit("config.reloaded")
	same(#env.commands, 1)
	same(env.commands[1], "/opt/vivaldi/vivaldi --app=https://web.whatsapp.com")
end)

test("laptop reload syncs Kanata without enabling it again", function()
	local env, ctx = setup()
	readyWindows(env)
	ctx.machine.kanata = true
	dofile(luaDir .. "events.lua")(ctx)
	env.emit("config.reloaded")
	same(#env.commands, 1)
	same(env.commands[1], "/test/home/.local/bin/kanata_up.sh --sync-devices")
	dofile(luaDir .. "applications.lua")(ctx)
	same(env.bindings["SUPER + F11"].action.args[1], "/test/home/.local/bin/kanata_up.sh")
end)

test("Ctrl+T forwards one press/release pair for browsers and web-app search", function()
	local env, ctx = setup()
	local cases = {
		{ "vivaldi-stable", "CTRL", "code:28" },
		{ "vivaldi-chatgpt.com__-Default", "CTRL", "code:45" },
		{ "vivaldi-discord.com__-Profile2", "CTRL", "code:45" },
		{ "vivaldi-spotify.com__-Default", "CTRL", "code:45" },
		{ "vivaldi-ticktick.com__-Default", "CTRL", "code:45" },
		{ "vivaldi-web.whatsapp.com__-Default", "ALT", "code:45" },
		{ "vivaldi-web.whatsapp.com__-Profile2", "CTRL", "code:28" },
		{ "vivaldi-chatgpt.com-unrelated", "CTRL", "code:28" },
	}
	for _, case in ipairs(cases) do
		env.dispatches = {}
		env.activeWindow = { class = case[1] }
		ctx.actions.browserNewTabOrSearch()
		same(#env.dispatches, 2)
		for index, state in ipairs({ "down", "up" }) do
			local action = env.dispatches[index]
			same(action.operation, "send_key_state")
			same(action.args[1].state, state)
			same(action.args[1].mods, case[2])
			same(action.args[1].key, case[3])
		end
	end
	env.dispatches, env.activeWindow = {}, nil
	ctx.actions.browserNewTabOrSearch()
	same(#env.dispatches, 0)
end)

test("Spotify toggle and its focus event send search only once", function()
	local env, ctx = setup()
	local spotify = env.addWindow("vivaldi-spotify.com__-Default")
	env.focusOnToggle = spotify
	ctx.actions.toggleSpotify()
	same(#env.dispatches, 3, "Workspace toggle plus one key pair")
	env.focusOnToggle = nil
	ctx.actions.toggleSpotify()
	same(#env.dispatches, 4, "Closing must not send search")
	env.emit("window.active", spotify)
	same(#env.dispatches, 6, "A later focus still sends search")
end)

test("lyrics toggle closes existing windows or launches the configured command", function()
	local env, ctx = setup()
	ctx.actions.toggleLyrics()
	same(env.commands[1], "kitty --class lyrics -o font_size=15 -o background_opacity=0.7 -e sptlrx -p mpris")
	env.addWindow("lyrics"); env.addWindow("lyrics")
	ctx.actions.toggleLyrics()
	same(#env.commands, 1)
	same(#env.dispatches, 2)
	same(env.dispatches[1].operation, "window.close")
end)

test("movement keeps floating offsets and group-aware tiling", function()
	local env, ctx = setup()
	local move = ctx.actions.moveActiveWindow("l", -30, 0)
	env.activeWindow = { floating = true }
	move()
	same(env.dispatches[1].args[1].x, -30)
	same(env.dispatches[1].args[1].relative, true)
	env.activeWindow = { floating = false }
	move()
	same(env.dispatches[2].args[1].direction, "l")
	same(env.dispatches[2].args[1].group_aware, true)
end)

test("one catalog entry adds startup, shortcut and window placement together", function()
	local apps = dofile(luaDir .. "apps.lua")
	table.insert(apps, { id = "notes", class = "notes.app", command = "notes", key = "SHIFT + B", workspace = "6", startup = "parallel" })
	local env, ctx = setup(apps)
	readyWindows(env)
	dofile(luaDir .. "applications.lua")(ctx)
	dofile(luaDir .. "rules.lua")(ctx)
	same(env.bindings["SUPER + SHIFT + B"].action.args[1], "notes")
	local placement
	for _, rule in ipairs(env.windowRules) do if rule.name == "app-notes-workspace" then placement = rule end end
	same(placement.workspace, "6")
	same(placement.match.class, "^(notes\\.app)$")
	ctx.startDesktopApplications()
	same(#env.commands, 1)
	same(env.commands[1], "notes")
end)

test("optional special apps can be removed from the catalog", function()
	local apps = { { id = "terminal", class = "kitty", command = "kitty", key = "SPACE" } }
	local env, ctx = setup(apps)
	dofile(luaDir .. "applications.lua")(ctx)
	same(env.bindings["SUPER + SPACE"].action.args[1], "kitty")
	same(env.bindings["SUPER + S"], nil)
end)

test("catalog rejects duplicate ids/keys and incomplete startup entries", function()
	local helper = dofile(luaDir .. "app_helpers.lua")
	for _, apps in ipairs({
		{ { id = "a" }, { id = "a" } },
		{ { id = "a", key = "A" }, { id = "b", key = "A" } },
		{ { id = "a", startup = "unknown" } },
		{ { id = "a", startup = "parallel", command = "a" } },
	}) do same(pcall(helper.index, apps), false) end
end)

test("monitor hotplug moves workspaces 1–4 and preserves the active workspace", function()
	local env, ctx = setup()
	local builtin, external = { name = "eDP-1" }, { name = "HDMI-A-1" }
	ctx.machine.workspace_monitors = { "external", "builtin" }
	env.monitors = { builtin = builtin }
	for id = 1, 5 do env.workspaces[tostring(id)] = { id = id, monitor = builtin } end
	env.activeWorkspace = env.workspaces["2"]
	dofile(luaDir .. "workspaces.lua")(ctx)
	env.monitors.external = external
	env.emit("monitor.layout_changed"); env.emit("monitor.layout_changed")
	env.advance(100)
	for id = 1, 4 do same(env.workspaces[tostring(id)].monitor, external) end
	same(env.workspaces["5"].monitor, builtin)
	same(env.activeWorkspace, env.workspaces["2"])
	same(#env.dispatches, 5, "Four moves plus focus; duplicate events are coalesced")
	env.monitors.external = nil
	env.emit("monitor.layout_changed"); env.advance(100)
	for id = 1, 4 do same(env.workspaces[tostring(id)].monitor, builtin) end
	same(env.activeWorkspace, env.workspaces["2"])
end)

test("term opacity covers all term windows; workspace requires the original title", function()
	local env, ctx = setup()
	dofile(luaDir .. "rules.lua")(ctx)
	local appearance, placement
	for _, rule in ipairs(env.windowRules) do
		if rule.name == "app-term" then appearance = rule end
		if rule.name == "app-term-workspace" then placement = rule end
	end
	same(appearance.match.initial_title, nil)
	same(appearance.opacity, "0.95 override 0.95 override 1 override")
	same(placement.match.initial_title, "^(kitty)$")
	same(placement.workspace, "3")
	same(ctx.appsById.term.workspace_match.class, nil, "Rule generation must not mutate catalog matches")
end)

test("Waybar selects each host layout and skips redundant reloads", function()
	for _, layout in ipairs({ "francos_bar_desktop", "francos_bar_2_monitors" }) do
		local env, ctx = setup()
		ctx.machine.waybar_layout = layout
		local config = (os.getenv("XDG_CONFIG_HOME") or ctx.home .. "/.config") .. "/waybar"
		local state = (os.getenv("XDG_STATE_HOME") or ctx.home .. "/.local/state") .. "/hyde/staterc"
		local files = { [config .. "/layouts/" .. layout .. ".jsonc"] = "expected-config", [state] = "WAYBAR_LAYOUT_NAME=other" }
		local oldOpen = io.open
		io.open = function(path)
			if files[path] then return { read = function() return files[path] end, close = function() end } end
			return nil
		end
		local ok, err = pcall(function()
			dofile(luaDir .. "waybar.lua")(ctx)
			env.emit("hyprland.start")
			same(env.commands[1], "hyde-shell waybar --set " .. layout)
			files[state], files[config .. "/config.jsonc"] = "WAYBAR_LAYOUT_NAME=" .. layout, "expected-config"
			env.emit("config.reloaded")
			same(#env.commands, 1)
			files[config .. "/config.jsonc"] = "stale-config"
			env.emit("config.reloaded")
			same(#env.commands, 2)
		end)
		io.open = oldOpen
		assert(ok, err)
	end
end)

test("complete entry point loads desktop, laptop and unknown-host profiles", function()
	for _, host in ipairs({ "archlinux", "zenbook", "unknown" }) do
		local env = fake()
		local oldDofile, oldOpen, oldGetenv, oldHyde = dofile, io.open, os.getenv, _G.hyde
		local monitorSpecs = {}
		hl.monitor = function(spec) table.insert(monitorSpecs, spec) end
		_G.hyde = {}
		os.getenv = function(name)
			if name == "HOME" then return "/test/home" end
			if name == "XDG_CONFIG_HOME" or name == "XDG_STATE_HOME" then return nil end
			return oldGetenv(name)
		end
		io.open = function(path, mode)
			if path == "/proc/sys/kernel/hostname" then
				return { read = function() return host end, close = function() end }
			end
			return oldOpen(path, mode)
		end
		_G.dofile = function(path)
			local relative = path:match("^/test/home/%.config/hypr/(.+)$")
			return oldDofile(relative and (configDir .. "/" .. relative) or path)
		end
		local ok, err = pcall(oldDofile, configDir .. "/hyprland.lua")
		_G.dofile, io.open, os.getenv, _G.hyde = oldDofile, oldOpen, oldGetenv, oldHyde
		assert(ok, err)
		assert(env.bindings["SUPER + SPACE"] and env.bindings["CTRL + T"] and env.bindings.F12)
		if host == "archlinux" then
			same(#monitorSpecs, 1); same(monitorSpecs[1].output, "DP-3"); same(monitorSpecs[1].scale, 1.5)
		elseif host == "zenbook" then
			same(#monitorSpecs, 2); same(monitorSpecs[1].scale, 2.0); assert(env.bindings["SUPER + F11"])
		else same(#monitorSpecs, 0) end
		if host ~= "zenbook" then same(env.bindings["SUPER + F11"], nil) end
	end
end)

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then os.exit(1) end
