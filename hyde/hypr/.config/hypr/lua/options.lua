-- Core compositor behavior and visual preferences.
return function(_)
	-- Keep Hyprcursor, XCursor and GTK clients on the same theme without a
	-- round-trip through hyprctl or gsettings.
	hl.env("HYPRCURSOR_THEME", "Bibata-Modern-Ice")
	hl.env("HYPRCURSOR_SIZE", "20")
	hl.env("XCURSOR_THEME", "Bibata-Modern-Ice")
	hl.env("XCURSOR_SIZE", "20")

	hl.config({
		general = {
			no_focus_fallback = true,
			layout = "master",
		},
		master = {
			mfact = 0.70,
			new_status = "slave",
		},
		binds = {
			hide_special_on_workspace_change = true,
		},
		cursor = {
			sync_gsettings_theme = true,
		},
	})

	hl.config({
		animations = {
			enabled = false,
		},
	})

	local disabledAnimations = {
		"global",
		"windows",
		"windowsIn",
		"windowsOut",
		"windowsMove",
		"layers",
		"layersIn",
		"layersOut",
		"fade",
		"fadeIn",
		"fadeOut",
		"fadeSwitch",
		"fadeShadow",
		"fadeGlow",
		"fadeDim",
		"fadeLayers",
		"fadeLayersIn",
		"fadeLayersOut",
		"fadePopups",
		"fadePopupsIn",
		"fadePopupsOut",
		"fadeDpms",
		"border",
		"borderangle",
		"shadowangle",
		"glowangle",
		"workspaces",
		"workspacesIn",
		"workspacesOut",
		"specialWorkspace",
		"specialWorkspaceIn",
		"specialWorkspaceOut",
		"zoomFactor",
		"monitorAdded",
	}

	for _, leaf in ipairs(disabledAnimations) do
		hl.animation({ leaf = leaf, enabled = false })
	end

	hl.config({
		decoration = {
			dim_inactive = true,
			dim_strength = 0.23,
			active_opacity = 1,
			inactive_opacity = 1,
			fullscreen_opacity = 1,
			shadow = {
				enabled = false,
			},
		},
		group = {
			groupbar = {
				enabled = true,
				col = {
					active = "rgba(ca9ee6ff)",
					inactive = "rgba(666666ff)",
					locked_active = "rgba(ca9ee6ff)",
					locked_inactive = "rgba(666666ff)",
				},
				font_size = 17,
				text_color = "rgba(000000ff)",
				gradients = true,
				gradient_rounding = 10,
				render_titles = true,
				indicator_height = 0,
				height = 20,
			},
			col = {
				border_locked_active = "rgba(8040bfff)",
				border_locked_inactive = "rgba(090000ff)",
			},
			auto_group = true,
		},
	})

end
