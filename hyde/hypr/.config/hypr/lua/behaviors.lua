-- Custom actions used by bindings.lua and applications.lua.
-- Requires ctx.apps, ctx.appsById and ctx.appHelpers; returns the action table.
-- Ordinary commands/workspace toggles belong in apps.lua, not here.
return function(ctx)
	local actions = {}
	local spotifyApp = ctx.appsById.spotify
	local lyricsApp = ctx.appsById.lyrics
	local suppressNextSpotifyFocus = false
	local spotifyFocusSuppressionTimer = nil

	local function sendShortcut(window, mods, key)
		-- Press callbacks must release the forwarded key themselves. Using
		-- send_shortcut here previously left Ctrl+T/Ctrl+K held in Vivaldi.
		for _, state in ipairs({ "down", "up" }) do
			hl.dispatch(hl.dsp.send_key_state({ mods = mods, key = key, state = state, window = window }))
		end
	end

	local function openSpotifyQuickCommand(window)
		if not spotifyApp or not window or window.class ~= spotifyApp.focus_class then
			return false
		end
		sendShortcut(window, spotifyApp.search.mods, spotifyApp.search.key)
		return true
	end

	local function clearSpotifyFocusSuppression()
		suppressNextSpotifyFocus = false
		if spotifyFocusSuppressionTimer then
			spotifyFocusSuppressionTimer:set_enabled(false)
			spotifyFocusSuppressionTimer = nil
		end
	end

	local function handleSpotifyFocus(window)
		if not spotifyApp or not window or window.class ~= spotifyApp.focus_class then
			return false
		end
		if suppressNextSpotifyFocus then
			clearSpotifyFocusSuppression()
			return true
		end
		return openSpotifyQuickCommand(window)
	end

	if spotifyApp then
		hl.on("window.active", handleSpotifyFocus)
	end

	function actions.toggleSpotify()
		assert(spotifyApp, "toggleSpotify needs the spotify catalog entry")
		local special = hl.get_active_special_workspace()
		local isClosing = special and special.name == spotifyApp.workspace
		local spotify = nil
		if not isClosing then
			spotify = hl.get_windows({ class = spotifyApp.focus_class })[1]
			if spotify then
				-- The bind sends Ctrl+K; suppress its matching focus callback.
				suppressNextSpotifyFocus = true
				spotifyFocusSuppressionTimer = hl.timer(function()
					suppressNextSpotifyFocus = false
					spotifyFocusSuppressionTimer = nil
				end, { timeout = 1000, type = "oneshot" })
			end
		end

		hl.dispatch(hl.dsp.workspace.toggle_special(spotifyApp.workspace:match("^special:(.+)$")))
		if spotify then
			openSpotifyQuickCommand(spotify)
		end
	end

	function actions.toggleLyrics()
		assert(lyricsApp, "toggleLyrics needs the lyrics catalog entry")
		-- Query filters use literal classes, unlike window-rule regexes.
		local windows = hl.get_windows({ class = lyricsApp.class })
		if #windows > 0 then
			for _, window in ipairs(windows) do
				hl.dispatch(hl.dsp.window.close({ window = window }))
			end
			return
		end
		hl.exec_cmd(lyricsApp.command)
	end

	function actions.browserNewTabOrSearch()
		local active = hl.get_active_window()
		if not active then
			return
		end
		-- Physical T under us/intl; catalog entries may override it with search.
		local mods, key = "CTRL", "code:28"
		for _, app in ipairs(ctx.apps) do
			local search = app.search
			if search and ((search.class and active.class == search.class)
				or (not search.class and ctx.appHelpers.matchWindow(app, active))) then
				mods, key = search.mods, search.key
				break
			end
		end
		sendShortcut(active, mods, key)
	end

	function actions.moveActiveWindow(direction, x, y)
		return function()
			local active = hl.get_active_window()
			if active and active.floating then
				hl.dispatch(hl.dsp.window.move({ x = x, y = y, relative = true }))
			else
				-- Keep movewindoworgroup semantics for neighboring groups.
				hl.dispatch(hl.dsp.window.move({ direction = direction, group_aware = true }))
			end
		end
	end

	return actions
end
