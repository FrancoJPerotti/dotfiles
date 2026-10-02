-- Hyprland loads this file when it is started without a config, and prefers it
-- over hyprland.conf. HyDE also loads it last as the user's override layer.
if not hyde then
	local share = os.getenv("XDG_DATA_HOME") or (os.getenv("HOME") .. "/.local/share")
	local entry = share .. "/hypr/hyde.lua"
	local handle = io.open(entry, "r")
	if not handle then
		error("HyDE is not installed at " .. entry .. ". Run install.sh -r, or point Hyprland at your own config.")
	end
	handle:close()
	dofile(entry)
end

-- Personal configuration is split into isolated modules. Each module receives
-- only the shared paths and helpers it needs through this context table.
local home = assert(os.getenv("HOME"), "HOME is not set")
local configDir = home .. "/.config/hypr"

local context = {
	home = home,
	scrPath = home .. "/.local/lib/hyde",
	mainMod = "SUPER",
}

-- Replace every colliding HyDE bind, regardless of the flags used upstream.
context.bind = function(keys, action, options)
	hl.unbind(keys)
	return hl.bind(keys, action, options)
end

context.exec = function(command)
	return hl.dsp.exec_cmd(command)
end

local function loadModule(name)
	return dofile(string.format("%s/lua/%s.lua", configDir, name))
end

-- Build shared data/actions explicitly before their consumers are configured.
-- Module contracts and editing examples: hyde/HYPRLAND.md.
loadModule("machines")(context)
context.apps = loadModule("apps")
context.appHelpers = loadModule("app_helpers")
context.appsById = context.appHelpers.index(context.apps)
context.actions = loadModule("behaviors")(context)
context.startDesktopApplications = loadModule("autostart")(context)

local modules = {
	"options",
	"monitors",
	"input",
	"bindings",
	"applications",
	"workspaces",
	"rules",
	"waybar",
	"events",
}

for _, name in ipairs(modules) do
	local configure = loadModule(name)
	assert(type(configure) == "function", "Hyprland module did not return a function: " .. name)
	configure(context)
end
