local M = {}

local excluded_filetypes = {
	TelescopePrompt = true,
	TelescopeResults = true,
	TelescopePreview = true,
	fff_input = true,
	fff_list = true,
	fff_preview = true,
	fff_file_info = true,
	fyler = true,
}

local function apply_highlights()
	vim.api.nvim_set_hl(0, "SnacksPickerPickWin", { fg = "#ffffff", bg = "#ff3333", bold = true })
	vim.api.nvim_set_hl(0, "SnacksPickerPickWinCurrent", { fg = "#ffffff", bg = "#ff3333", bold = true })
end

apply_highlights()

vim.api.nvim_create_autocmd("ColorScheme", {
	group = vim.api.nvim_create_augroup("WinpickHighlights", { clear = true }),
	callback = apply_highlights,
})

local function default_filter(_, buf)
	if excluded_filetypes[vim.bo[buf].filetype] then
		return false
	end
	if vim.bo[buf].buftype ~= "" then
		return false
	end
	if not vim.bo[buf].modifiable then
		return false
	end
	return true
end

function M.pick_window(opts)
	local ok, picker = pcall(require, "snacks.picker.util")
	if not ok then
		return nil
	end

	local user_filter = opts and opts.filter or nil
	local filter = default_filter
	if user_filter then
		filter = function(win, buf)
			if not default_filter(win, buf) then
				return false
			end
			return user_filter(win, buf)
		end
	end

	local winid = picker.pick_win({
		main = opts and opts.main or nil,
		float = opts and opts.float or nil,
		filter = filter,
	})

	if type(winid) ~= "number" then
		return nil
	end

	return winid
end

function M.with_pick(opts)
	local state = opts.hide and opts.hide() or nil
	local winid = M.pick_window(opts)
	if not winid or not vim.api.nvim_win_is_valid(winid) then
		if opts.restore then
			opts.restore(state)
		end
		return nil
	end

	if opts.open then
		opts.open(winid, state)
	end

	return winid
end

function M.open_path(winid, action, path)
	if not path or path == "" then
		return
	end

	if action ~= "tab" and winid and vim.api.nvim_win_is_valid(winid) then
		vim.api.nvim_set_current_win(winid)
	end

	if action == "split" then
		vim.cmd.split({ args = { path }, mods = { keepalt = false } })
	elseif action == "vsplit" then
		vim.cmd.vsplit({ args = { path }, mods = { keepalt = false } })
	elseif action == "tab" then
		vim.cmd.tabedit({ args = { path }, mods = { keepalt = false } })
	else
		vim.cmd.edit({ args = { path }, mods = { keepalt = false } })
	end
end

local function resolve_fff_path(item, base_path)
	if not item then
		return nil
	end

	local path = item.path or item.filename or item.relative_path
	if not path or path == "" then
		return nil
	end

	if vim.startswith(path, "\\\\?\\") then
		path = path:sub(5)
	end

	if vim.fn.fnamemodify(path, ":p") == path then
		return path
	end

	if base_path and base_path ~= "" then
		return vim.fs.normalize(base_path .. "/" .. path)
	end

	return path
end

local function fff_item_tracking_path(item)
	if not item then
		return nil
	end

	return item.relative_path or item.path or item.filename
end

local function fff_location_from_item(snapshot)
	local location = snapshot.location
	local item = snapshot.item or {}
	local is_grep_item = snapshot.mode == "grep" or snapshot.suggestion_source == "grep"

	if is_grep_item and item.line_number and item.line_number > 0 then
		location = { line = item.line_number }
		if item.col and item.col > 0 then
			location.col = item.col + 1
		end
	end

	if not location and snapshot.query and snapshot.query ~= "" then
		local line, col = snapshot.query:match(":(%d+):(%d+)$")
		if line then
			location = { line = tonumber(line), col = tonumber(col) }
		else
			line = snapshot.query:match(":(%d+)$")
			if line then
				location = { line = tonumber(line) }
			end
		end
	end

	return location
end

local function snapshot_fff(picker_ui)
	local state = picker_ui.state or {}
	local items = state.filtered_items or {}
	local config = state.config or {}
	return {
		query = state.query or "",
		cursor = state.cursor or 1,
		item = vim.deepcopy(items[state.cursor]),
		location = state.location,
		mode = state.mode,
		suggestion_source = state.suggestion_source,
		config = config,
		base_path = config.base_path or require("fff.file_picker").state.base_path or require("fff.conf").get().base_path,
	}
end

local function restore_fff(picker_ui, snapshot)
	local opts = vim.tbl_deep_extend("force", {}, snapshot.config or {}, { cwd = snapshot.base_path })
	local ok, err = pcall(picker_ui.open, opts)
	if not ok then
		vim.notify("FFF restore failed: " .. tostring(err), vim.log.levels.ERROR)
		return
	end

	vim.schedule(function()
		if not picker_ui.state or not picker_ui.state.active then
			return
		end
		local input_buf = picker_ui.state.input_buf
		local prompt = (picker_ui.state.config and picker_ui.state.config.prompt) or ""
		local query = snapshot.query or ""

		if input_buf and vim.api.nvim_buf_is_valid(input_buf) then
			vim.api.nvim_buf_set_lines(input_buf, 0, -1, false, { prompt .. query })
		end
		picker_ui.state.query = query

		if picker_ui.on_input_change then
			picker_ui.on_input_change()
		elseif picker_ui.update_results then
			picker_ui.update_results()
		end

		if snapshot.cursor and snapshot.cursor > 1 then
			vim.schedule(function()
				if not picker_ui.state or not picker_ui.state.active then
					return
				end
				local max_cursor = #picker_ui.state.filtered_items
				picker_ui.state.cursor = math.min(snapshot.cursor, max_cursor)
				if picker_ui.render_list then
					picker_ui.render_list()
				end
				if picker_ui.update_preview then
					picker_ui.update_preview()
				end
			end)
		end
	end)
end

local function open_fff_item(snapshot, action, winid)
	local abs_path = resolve_fff_path(snapshot.item, snapshot.base_path)
	if not abs_path then
		return
	end

	local path = vim.fn.fnamemodify(abs_path, ":.")
	local open_action = action or "edit"
	M.open_path(action == "tab" and nil or winid, open_action, path)

	local location = fff_location_from_item(snapshot)
	if location then
		vim.schedule(function()
			require("fff.location_utils").jump_to_location(location)
		end)
	end

	if snapshot.query and snapshot.query ~= "" then
		local config = require("fff.conf").get()
		if config.history and config.history.enabled then
			local fff = require("fff.core").ensure_initialized()
			if snapshot.mode == "grep" then
				pcall(fff.track_grep_query, snapshot.query)
			else
				pcall(fff.track_query_completion, snapshot.query, fff_item_tracking_path(snapshot.item))
			end
		end
	end
end

function M.setup_fff()
	local ok, picker_ui = pcall(require, "fff.picker_ui")
	if not ok or picker_ui._winpick_wrapped then
		return
	end

	picker_ui.select = function(action)
		if not picker_ui.state.active then
			return
		end

		local snapshot = snapshot_fff(picker_ui)
		if not snapshot.item then
			return
		end

		picker_ui.close()

		if action == "tab" then
			open_fff_item(snapshot, action, nil)
			return
		end

		local winid = M.pick_window({})
		if not winid then
			vim.schedule(function()
				restore_fff(picker_ui, snapshot)
			end)
			return
		end

		open_fff_item(snapshot, action, winid)
	end

	picker_ui._winpick_wrapped = true
end

local function open_telescope_entry(entry, action, picker)
	if not entry then
		return
	end

	local filename, row, col, bufnr
	if entry.path or entry.filename then
		filename = entry.path or entry.filename
		row = entry.row or entry.lnum
		col = entry.col
	elseif entry.bufnr then
		bufnr = entry.bufnr
	else
		local value = entry.value
		if type(value) == "table" then
			value = entry.display
		end
		local sections = vim.split(value or "", ":")
		filename = sections[1]
		row = tonumber(sections[2])
		col = tonumber(sections[3])
	end

	if picker and picker.push_cursor_on_edit then
		vim.cmd("normal! m'")
	end
	if picker and picker.push_tagstack_on_edit then
		local from = { vim.fn.bufnr("%"), vim.fn.line("."), vim.fn.col("."), 0 }
		local items = { { tagname = vim.fn.expand("<cword>"), from = from } }
		vim.fn.settagstack(vim.fn.win_getid(), { items = items }, "t")
	end

	if bufnr then
		if action == "tab" then
			vim.cmd(string.format("tab sb %d", bufnr))
		elseif action == "vsplit" then
			vim.cmd(string.format("vert sbuffer %d", bufnr))
		elseif action == "split" then
			vim.cmd(string.format("sbuffer %d", bufnr))
		else
			vim.cmd(string.format("buffer %d", bufnr))
		end
	elseif filename and filename ~= "" then
		local Path = require("plenary.path")
		local path = Path:new(filename):normalize(vim.loop.cwd())
		M.open_path(nil, action or "edit", path)
	else
		return
	end

	if row and col then
		pcall(vim.api.nvim_win_set_cursor, 0, { row, col })
	end
end

local function should_winpick_telescope(entry, picker)
	if not entry then
		return false
	end
	if entry.is_header or entry.__project_finder_header then
		return false
	end
	if entry.bufnr or entry.path or entry.filename then
		return true
	end
	if type(entry.value) == "string" then
		local value = entry.value
		if picker and picker.cwd and value:sub(1, 1) ~= "/" then
			value = picker.cwd .. "/" .. value
		end
		if vim.fn.filereadable(value) == 1 then
			return true
		end
		if vim.fn.isdirectory(value) == 1 then
			return false
		end
	end
	return false
end

function M.telescope_select(action)
	return function(prompt_bufnr)
		local actions = require("telescope.actions")
		local action_state = require("telescope.actions.state")
		local picker = action_state.get_current_picker(prompt_bufnr)
		local entry = action_state.get_selected_entry()
		if not entry then
			return
		end

		if not should_winpick_telescope(entry, picker) then
			actions.select_default(prompt_bufnr)
			return
		end

		actions.close(prompt_bufnr)

		if action == "tab" then
			open_telescope_entry(entry, action, picker)
			return
		end

		local winid = M.pick_window({ main = picker.original_win_id })
		if not winid then
			vim.schedule(function()
				require("telescope.builtin").resume()
			end)
			return
		end

		if vim.api.nvim_win_is_valid(winid) then
			vim.api.nvim_set_current_win(winid)
		end

		open_telescope_entry(entry, action, picker)
	end
end

function M.fyler_select(self, action)
	local config = require("fyler.config")
	local util = require("fyler.lib.util")

	local ref_id = util.parse_ref_id(vim.api.nvim_get_current_line())
	if not ref_id then
		return
	end

	local entry = self.files:node_entry(ref_id)
	if not entry then
		return
	end

	local is_directory = entry.is_directory and entry:is_directory() or entry.isdir and entry:isdir()
	if is_directory then
		if entry.open then
			self.files:collapse_node(ref_id)
		else
			self.files:expand_node(ref_id)
		end
		self:dispatch_refresh()
		return
	end

	if action == "tab" then
		self:exec_action("n_close")
		M.open_path(nil, "tab", entry.path)
		return
	end

	local snapshot = {
		dir = self.dir,
		kind = self.win.kind,
	}

	local function restore(state)
		require("fyler").open({ dir = state.dir, kind = state.kind })
	end

	M.with_pick({
		hide = function()
			self:exec_action("n_close")
			return snapshot
		end,
		restore = restore,
		open = function(winid)
			if not winid then
				return
			end

			if config.values.views.finder.close_on_select then
				self:exec_action("n_close")
			end

			M.open_path(winid, action, entry.path)
		end,
	})
end

return M
