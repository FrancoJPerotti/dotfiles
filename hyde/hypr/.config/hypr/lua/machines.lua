-- Per-computer options, selected by the kernel's current hostname.
local machines = {
	archlinux = {
		kanata = false,
		waybar_layout = "francos_bar_desktop",
		monitors = {
			{ output = "DP-3", mode = "3840x2160@60.0", position = "0x0", scale = 1.5 },
		},
		workspace_monitors = { "DP-3" },
	},
	zenbook = {
		kanata = true,
		waybar_layout = "francos_bar_2_monitors",
		-- Description prefixes also match when Hyprland omits the serial suffix.
		monitors = {
			{
				output = "desc:Samsung Display Corp. 0x419D",
				mode = "2880x1800@120.0",
				position = "307x1080",
				scale = 2.0,
			},
			{
				output = "desc:Samsung Electric Company SAMSUNG",
				mode = "1920x1080@60.0",
				position = "67x0",
				scale = 1.0,
			},
		},
		-- First connected output wins: external Samsung, then the built-in panel.
		workspace_monitors = {
			"desc:Samsung Electric Company SAMSUNG",
			"desc:Samsung Display Corp. 0x419D",
		},
	},
}

return function(ctx)
	local hostname = ""
	local handle = io.open("/proc/sys/kernel/hostname", "r")
	if handle then
		hostname = (handle:read("*l") or ""):match("^%s*(.-)%s*$")
		handle:close()
	end

	ctx.hostname = hostname
	-- Unknown computers never start Kanata automatically.
	ctx.machine = machines[hostname] or { kanata = false }
end
