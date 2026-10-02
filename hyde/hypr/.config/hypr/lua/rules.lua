-- Generate window rules from apps.lua; edit layer-surface effects below.
-- Requires ctx.apps and ctx.appHelpers. Catalog tables are never mutated.
return function(ctx)
	for _, app in ipairs(ctx.apps) do
		if app.properties or app.workspace then
			local match = ctx.appHelpers.ruleMatch(app)
			if app.properties then
				local rule = { name = "app-" .. app.id, match = match }
				for property, value in pairs(app.properties) do
					rule[property] = value
				end
				hl.window_rule(rule)
			end
			if app.workspace then
				local placementMatch = {}
				for property, value in pairs(match) do
					placementMatch[property] = value
				end
				for property, value in pairs(app.workspace_match or {}) do
					placementMatch[property] = value
				end
				hl.window_rule({
					name = "app-" .. app.id .. "-workspace",
					match = placementMatch,
					workspace = app.workspace,
				})
			end
		end
	end

	local layerRuleNumber = 0
	local function layerRule(namespace, properties)
		layerRuleNumber = layerRuleNumber + 1
		properties.name = properties.name or string.format("user-layer-rule-%02d", layerRuleNumber)
		properties.match = { namespace = namespace }
		hl.layer_rule(properties)
	end

	layerRule("rofi", { blur = true })
	layerRule("rofi", { ignore_alpha = 0 })
	layerRule("notifications", { blur = true })
	layerRule("notifications", { ignore_alpha = 0 })
	layerRule("swaync-notification-window", { blur = true })
	layerRule("swaync-notification-window", { ignore_alpha = 0 })
	layerRule("swaync-control-center", { blur = true })
	layerRule("swaync-control-center", { ignore_alpha = 0 })
	layerRule("logout_dialog", { blur = true })
	layerRule("waybar", { name = "waybar-no-blur", blur = false })
end
