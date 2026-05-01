local DDS_KIND = "@command-palette-bookmarks"
local STATE_FILE = (os.getenv("XDG_STATE_HOME") or (os.getenv("HOME") .. "/.local/state"))
	.. "/yazi/command-palette-bookmarks.tsv"

local bookmarks = {}

local config = {
	colors = {
		border = "blue",
		selected_fg = "#1a1b26",
		selected_bg = "#7aa2f7",
		highlight = "cyan",
	},
	keys = {
		rename = "<C-r>",
		add = "<C-a>",
		delete = "<C-d>",
		quit = "<Esc>",
	},
}

local _path_cache = {}

local function notify(content, level)
	ya.notify({
		title = "Bookmarks",
		content = content,
		timeout = 3,
		level = level,
	})
end

local function basename(path)
	local trimmed = path:gsub("[/\\]+$", "")
	return trimmed:match("([^/\\]+)$") or path
end

local function normalize(items)
	local normalized = {}
	if type(items) ~= "table" then
		return normalized
	end

	for _, item in ipairs(items) do
		if type(item) == "table" and type(item.path) == "string" and item.path ~= "" then
			normalized[#normalized + 1] = {
				name = type(item.name) == "string" and item.name ~= "" and item.name or basename(item.path),
				path = item.path,
			}
		end
	end

	table.sort(normalized, function(a, b)
		return a.name:lower() < b.name:lower()
	end)

	return normalized
end

local function clone(items)
	local cloned = {}
	for i, item in ipairs(items) do
		cloned[i] = {
			name = item.name,
			path = item.path,
		}
	end
	return cloned
end

local function clean_field(value)
	return tostring(value):gsub("[\t\r\n]", " ")
end

local function load_bookmarks()
	local file = io.open(STATE_FILE, "r")
	if not file then
		return {}
	end

	local items = {}
	for line in file:lines() do
		local name, path = line:match("^([^\t]*)\t(.+)$")
		if path and path ~= "" then
			items[#items + 1] = {
				name = name ~= "" and name or basename(path),
				path = path,
			}
		end
	end
	file:close()

	return normalize(items)
end

local function save_bookmarks(items)
	local file, err = io.open(STATE_FILE, "w")
	if not file then
		notify("Failed to save bookmarks: " .. tostring(err), "error")
		return
	end

	for _, item in ipairs(items) do
		file:write(clean_field(item.name), "\t", clean_field(item.path), "\n")
	end
	file:close()
end

local function path_exists(path)
	if _path_cache[path] ~= nil then
		return _path_cache[path]
	end

	local ok, err, code = os.rename(path, path)
	local exists = false
	if not ok then
		if code == 13 then
			exists = true
		end
	else
		exists = true
	end

	_path_cache[path] = exists
	return exists
end

local function invalidate_path_cache()
	_path_cache = {}
end

local function fuzzy_match(text, query)
	if query == "" then
		return { score = 0, positions = {} }
	end

	local haystack = text:lower()
	local needle = query:lower()
	local score = 0
	local pos = 1
	local last = 0
	local positions = {}

	for i = 1, #needle do
		local char = needle:sub(i, i)
		local found = haystack:find(char, pos, true)
		if not found then
			return nil
		end

		score = score + 1
		if found == 1 then
			score = score + 6
		elseif haystack:sub(found - 1, found - 1):match("[%s%-%_/%\\]") then
			score = score + 4
		end
		if found == last + 1 then
			score = score + 3
		end

		positions[#positions + 1] = found
		last = found
		pos = found + 1
	end

	return {
		score = score - (#haystack * 0.01),
		positions = positions,
	}
end

local function filtered_results(query)
	local matches = {}
	for i, bookmark in ipairs(bookmarks) do
		local name_match = fuzzy_match(bookmark.name, query)
		local path_match = fuzzy_match(bookmark.path, query)

		local score = -1
		local name_positions = {}
		local path_positions = {}

		if name_match then
			score = math.max(score, name_match.score)
			name_positions = name_match.positions
		end
		if path_match then
			score = math.max(score, path_match.score)
			path_positions = path_match.positions
		end

		if score >= 0 then
			matches[#matches + 1] = {
				index = i,
				score = score,
				name_positions = name_positions,
				path_positions = path_positions,
			}
		end
	end

	table.sort(matches, function(a, b)
		if query ~= "" and a.score ~= b.score then
			return a.score > b.score
		end
		return bookmarks[a.index].name:lower() < bookmarks[b.index].name:lower()
	end)

	return matches
end

local function recompute_filtered(self)
	self._filtered_results = filtered_results(self.query or "")
	local results = self._filtered_results
	if #results == 0 then
		self.cursor = 0
		return
	end

	-- Ensure cursor lands on an alive bookmark
	local cursor = ya.clamp(0, self.cursor or 0, #results - 1)
	for i = cursor + 1, #results do
		if path_exists(bookmarks[results[i].index].path) then
			self.cursor = i - 1
			return
		end
	end
	for i = cursor, 1, -1 do
		if path_exists(bookmarks[results[i].index].path) then
			self.cursor = i - 1
			return
		end
	end

	self.cursor = 0
end

local function highlight_text(text, positions, highlight_color)
	if not positions or #positions == 0 then
		return { ui.Span(text) }
	end

	local set = {}
	for _, pos in ipairs(positions) do
		set[pos] = true
	end

	local spans = {}
	local i = 1
	while i <= #text do
		if set[i] then
			local j = i
			while j <= #text and set[j] do
				j = j + 1
			end
			spans[#spans + 1] = ui.Span(text:sub(i, j - 1)):fg(highlight_color):bold()
			i = j
		else
			local j = i
			while j <= #text and not set[j] do
				j = j + 1
			end
			spans[#spans + 1] = ui.Span(text:sub(i, j - 1))
			i = j
		end
	end

	return spans
end

local persist = ya.sync(function(_, items)
	bookmarks = normalize(items)
	ps.pub(DDS_KIND, clone(bookmarks))
	ui.render()
end)

local current_dir = ya.sync(function()
	local path = tostring(cx.active.current.cwd)
	return {
		path = path,
		name = basename(path),
	}
end)

local sync_state = ya.sync(function(self, patch)
	for key, value in pairs(patch) do
		self[key] = value
	end
	recompute_filtered(self)
	ui.render()
end)

local move_cursor = ya.sync(function(self, delta)
	local results = self._filtered_results or {}
	if #results == 0 then
		self.cursor = 0
		ui.render()
		return
	end

	local direction = delta > 0 and 1 or -1
	local cursor = (self.cursor or 0) + delta

	-- Skip dead bookmarks
	local tries = 0
	while tries < #results do
		cursor = ya.clamp(0, cursor, #results - 1)
		local result = results[cursor + 1]
		if result and path_exists(bookmarks[result.index].path) then
			self.cursor = cursor
			ui.render()
			return
		end
		cursor = cursor + direction
		tries = tries + 1
	end

	-- No alive bookmark found
	self.cursor = 0
	ui.render()
end)

local selected_bookmark = ya.sync(function(self)
	local results = self._filtered_results or {}
	local cursor = self.cursor or 0

	-- Search forward from cursor
	for i = cursor + 1, #results do
		local result = results[i]
		if result and path_exists(bookmarks[result.index].path) then
			return bookmarks[result.index]
		end
	end
	-- Search backward from cursor
	for i = cursor, 1, -1 do
		local result = results[i]
		if result and path_exists(bookmarks[result.index].path) then
			return bookmarks[result.index]
		end
	end

	return nil
end)

local remove_selected = ya.sync(function(self)
	local results = self._filtered_results or {}
	local selected_result = results[(self.cursor or 0) + 1]
	if not selected_result then
		return nil
	end
	local selected = selected_result.index

	local removed = bookmarks[selected]
	local next_bookmarks = {}
	for i, bookmark in ipairs(bookmarks) do
		if i ~= selected then
			next_bookmarks[#next_bookmarks + 1] = bookmark
		end
	end

	bookmarks = normalize(next_bookmarks)
	ps.pub(DDS_KIND, clone(bookmarks))
	invalidate_path_cache()

	recompute_filtered(self)
	ui.render()
	return {
		removed = removed,
		items = clone(bookmarks),
	}
end)

local toggle_ui = ya.sync(function(self)
	if self.children then
		Modal:children_remove(self.children)
		self.children = nil
	else
		self.children = Modal:children_add(self, 10)
	end
	ui.render()
end)

local update_query = ya.sync(function(self, action, value)
	local query = self.query or ""
	if action == "push" then
		self.query = query .. value
	elseif action == "pop" then
		self.query = query:sub(1, -2)
	elseif action == "clear" then
		self.query = ""
	end

	recompute_filtered(self)
	ui.render()
end)

local function keys()
	local items = {
		{ on = config.keys.quit, run = "quit" },
		{ on = "<C-c>", run = "quit" },
		{ on = "<Down>", run = "down" },
		{ on = "<Up>", run = "up" },
		{ on = "<Enter>", run = "enter" },
		{ on = config.keys.add, run = "add" },
		{ on = config.keys.rename, run = "rename" },
		{ on = config.keys.delete, run = "delete" },
		{ on = "<Backspace>", run = "backspace" },
		{ on = "<C-h>", run = "backspace" },
		{ on = "<C-u>", run = "clear-filter" },
		{ on = "<Space>", run = "type", text = " " },
	}

	local chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.-_~/"
	for i = 1, #chars do
		local char = chars:sub(i, i)
		items[#items + 1] = { on = char, run = "type", text = char }
	end

	return items
end

local M = {
	keys = keys(),
}

function M:new(area)
	self:layout(area)
	return self
end

function M:layout(area)
	local rows = ui.Layout()
		:constraints({
			ui.Constraint.Percentage(15),
			ui.Constraint.Percentage(70),
			ui.Constraint.Percentage(15),
		})
		:split(area)

	local cols = ui.Layout()
		:direction(ui.Layout.HORIZONTAL)
		:constraints({
			ui.Constraint.Percentage(20),
			ui.Constraint.Percentage(60),
			ui.Constraint.Percentage(20),
		})
		:split(rows[2])

	self._area = cols[2]
end

function M:entry()
	bookmarks = load_bookmarks()
	persist(bookmarks)
	invalidate_path_cache()
	sync_state({ cursor = 0, query = "" })
	toggle_ui()

	while true do
		local idx = ya.which({
			cands = self.keys,
			silent = true,
		})
		local cand = idx and self.keys[idx] or nil
		local run = cand and cand.run or nil

		if run == "quit" then
			toggle_ui()
			return
		elseif run == "up" then
			move_cursor(-1)
		elseif run == "down" then
			move_cursor(1)
		elseif run == "enter" then
			local bookmark = selected_bookmark()
			if bookmark then
				if not path_exists(bookmark.path) then
					notify("Path does not exist: " .. bookmark.path, "error")
				else
					toggle_ui()
					ya.emit("cd", { bookmark.path })
					return
				end
			end
		elseif run == "add" then
			self:add()
		elseif run == "rename" then
			self:rename()
		elseif run == "delete" then
			self:delete()
		elseif run == "type" then
			update_query("push", cand.text)
		elseif run == "backspace" then
			update_query("pop")
		elseif run == "clear-filter" then
			update_query("clear")
		end
	end
end

function M:add()
	bookmarks = load_bookmarks()
	persist(bookmarks)

	local target = current_dir()
	local path = target.path
	local name, event = ya.input({
		pos = { "center", w = 44 },
		title = string.format("Bookmark directory: %s", path),
		value = target.name,
	})

	if event ~= 1 or not name or name == "" then
		return
	end

	local next_bookmarks = {}
	for _, bookmark in ipairs(bookmarks) do
		if bookmark.path ~= path then
			next_bookmarks[#next_bookmarks + 1] = bookmark
		end
	end

	next_bookmarks[#next_bookmarks + 1] = { name = name, path = path }
	save_bookmarks(normalize(next_bookmarks))
	persist(next_bookmarks)
	notify(string.format("Saved %s", path))
end

function M:rename()
	local bookmark = selected_bookmark()
	if not bookmark then
		notify("No bookmark selected", "warn")
		return
	end

	local name, event = ya.input({
		pos = { "center", w = 44 },
		title = string.format("Rename bookmark: %s", bookmark.path),
		value = bookmark.name,
	})

	if event ~= 1 or not name or name == "" then
		return
	end

	local next_bookmarks = {}
	for _, b in ipairs(bookmarks) do
		if b.path == bookmark.path then
			next_bookmarks[#next_bookmarks + 1] = { name = name, path = b.path }
		else
			next_bookmarks[#next_bookmarks + 1] = b
		end
	end

	save_bookmarks(normalize(next_bookmarks))
	persist(next_bookmarks)
	notify(string.format("Renamed to %s", name))
end

function M:delete()
	local bookmark = selected_bookmark()
	if not bookmark then
		notify("No bookmark selected", "warn")
		return
	end

	local ok = ya.confirm({
		pos = { "center", w = 50, h = 6 },
		title = "Delete bookmark",
		body = string.format("%s\n%s", bookmark.name, bookmark.path),
	})

	if not ok then
		return
	end

	local result = remove_selected()
	if result and result.removed then
		save_bookmarks(result.items)
		notify(string.format("Deleted %s", result.removed.name))
	end
end

function M:reflow()
	return { self }
end

function M:redraw()
	local area = self._area
	local inner = area:pad(ui.Pad(1, 2, 1, 2))
	local chunks = ui.Layout()
		:constraints({
			ui.Constraint.Length(3),
			ui.Constraint.Length(1),
			ui.Constraint.Fill(1),
			ui.Constraint.Length(1),
		})
		:split(inner)
	local search_area = chunks[1]
	local table_area = chunks[3]
	local footer_area = chunks[4]
	local rows = {}
	local query = self.query or ""
	local results = self._filtered_results or {}

	if #bookmarks == 0 then
		rows[#rows + 1] = ui.Row({ "No bookmarks yet", "Press Ctrl-a to add the current directory" })
	elseif #results == 0 then
		rows[#rows + 1] = ui.Row({ "No matches", query })
	else
		local highlight_color = config.colors.highlight
		for _, result in ipairs(results) do
			local bookmark = bookmarks[result.index]
			local exists = path_exists(bookmark.path)

			local name_spans
			if exists then
				name_spans = highlight_text(bookmark.name, result.name_positions, highlight_color)
			else
				name_spans = {
					ui.Span("!"):fg("red"):bold(),
					ui.Span(" "),
					ui.Span(bookmark.name):dim(),
				}
			end

			local path_spans
			if exists then
				path_spans = highlight_text(bookmark.path, result.path_positions, highlight_color)
			else
				path_spans = { ui.Span(bookmark.path):dim() }
			end

			rows[#rows + 1] = ui.Row({
				ui.Line(name_spans),
				ui.Line(path_spans),
			})
		end
	end

	local title = "Bookmarks"
	local selected_style = ui.Style():fg(config.colors.selected_fg):bg(config.colors.selected_bg):bold()
	local table_widget = ui.Table(rows)
		:area(table_area)
		:row_style(selected_style)
		:widths({
			ui.Constraint.Percentage(32),
			ui.Constraint.Percentage(68),
		})

	if #results > 0 then
		table_widget:row(self.cursor)
	end

	return {
		ui.Clear(area),
		ui.Border(ui.Edge.ALL)
			:area(area)
			:type(ui.Border.ROUNDED)
			:style(ui.Style():fg(config.colors.border))
			:title(ui.Line(title):align(ui.Align.CENTER)),
		ui.Border(ui.Edge.ALL)
			:area(search_area)
			:type(ui.Border.ROUNDED)
			:style(ui.Style():fg(config.colors.border)),
		ui.Line({
			ui.Span(" "):fg(config.colors.border),
			query ~= "" and ui.Span(query):fg("white"):bold() or ui.Span("Search bookmarks"):dim(),
		}):area(search_area:pad(ui.Pad(1, 2, 1, 2))),
		table_widget,
		self:footer(footer_area),
	}
end

function M:footer(area)
	local hints = {
		{ "↑↓", "mv" },
		{ "Ent", "open" },
		{ "C-a", "add" },
		{ "C-r", "ren" },
		{ "C-d", "del" },
		{ "Esc", "quit" },
	}

	local total_width = 0
	for _, hint in ipairs(hints) do
		local key, desc = hint[1], hint[2]
		local key_width = key == "↑↓" and 2 or #key
		total_width = total_width + key_width + 1 + #desc
	end

	local remaining = math.max(0, area.w - total_width)
	local gaps = {}
	if #hints > 1 then
		local base_gap = math.floor(remaining / (#hints - 1))
		local extra = remaining % (#hints - 1)
		for i = 1, #hints - 1 do
			gaps[i] = base_gap + (i <= extra and 1 or 0)
		end
	end

	local spans = {}
	for i, hint in ipairs(hints) do
		local key, desc = hint[1], hint[2]
		spans[#spans + 1] = ui.Span(key):fg("blue"):bold()
		spans[#spans + 1] = " " .. desc
		if i < #hints then
			spans[#spans + 1] = string.rep(" ", gaps[i] or 0)
		end
	end

	return ui.Line(spans):area(area)
end

function M:click() end

function M:scroll() end

function M:touch() end

function M:setup(opts)
	if opts then
		if opts.colors then
			for key, value in pairs(opts.colors) do
				if config.colors[key] ~= nil then
					config.colors[key] = value
				end
			end
		end
		if opts.keys then
			for key, value in pairs(opts.keys) do
				if config.keys[key] ~= nil then
					config.keys[key] = value
				end
			end
		end
		-- Rebuild keys with new config
		M.keys = keys()
	end

	bookmarks = load_bookmarks()
	ps.sub(DDS_KIND, function(value)
		bookmarks = normalize(value)
	end)
end

return M
