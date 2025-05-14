-- ~/.config/nvim/lua/custom/todo_panel.lua

local api = vim.api
local fn = vim.fn

-- State table to manage the panel's status
local PanelState = {
	winid = nil, -- Window ID of the TODO panel
	bufnr = nil, -- Buffer number for todo.md
	last_focused_winid = nil, -- Window ID that had focus before opening the panel
	-- Proportions based on editor aspect ratio
	horizontal_proportional_width = 0.15, -- Use 25% width when editor is wide (like horizontal monitor)
	vertical_proportional_width = 0.25, -- Use 45% width when editor is tall (like vertical monitor)
	aspect_ratio_threshold = 1.5, -- When width/height is > this, use horizontal proportion
	min_width = 25, -- Minimum width in columns (increased slightly)
	todo_file_path = fn.expand("~/.config/nvim/todo.md"), -- Store the path
}

-- Helper function to calculate target width based on proportion and aspect ratio
local function calculate_target_width()
	local total_columns = api.nvim_get_option_value("columns", {})
	local total_lines = api.nvim_get_option_value("lines", {})
	local target_proportion

	-- Determine aspect ratio to choose the right proportion
	if total_lines == 0 then -- Avoid division by zero
		target_proportion = PanelState.horizontal_proportional_width
	elseif (total_columns / total_lines) > PanelState.aspect_ratio_threshold then
		-- Wider than tall (Horizontal-like layout)
		target_proportion = PanelState.horizontal_proportional_width
		-- print("DEBUG: Using horizontal proportion:", target_proportion)
	else
		-- Taller than wide or square-ish (Vertical-like layout)
		target_proportion = PanelState.vertical_proportional_width
		-- print("DEBUG: Using vertical proportion:", target_proportion)
	end

	local target = math.floor(total_columns * target_proportion)
	-- print("DEBUG: Calculated target:", target, "Min width:", PanelState.min_width)
	return math.max(PanelState.min_width, target) -- Ensure minimum width
end

-- Helper function to get or create the TODO buffer (no changes needed)
local function get_todo_buf()
	if PanelState.bufnr and api.nvim_buf_is_valid(PanelState.bufnr) then
		if not vim.fn.bufloaded(PanelState.bufnr) then
			vim.fn.bufload(PanelState.bufnr)
		end
		return PanelState.bufnr
	end
	local todo_abs = fn.fnamemodify(PanelState.todo_file_path, ":p")
	local bufnr = fn.bufadd(todo_abs)
	vim.fn.bufload(bufnr)
	if fn.filereadable(todo_abs) == 0 then
		fn.writefile({}, todo_abs)
		vim.fn.bufload(bufnr)
	end
	api.nvim_buf_set_option(bufnr, "buflisted", false)
	PanelState.bufnr = bufnr
	return bufnr
end

-- Function to check if the panel is currently open (no changes needed)
local function is_open()
	return PanelState.winid and api.nvim_win_is_valid(PanelState.winid)
end

-- Function to resize the panel proportionally (no changes needed, logic is in calculate_target_width)
local function resize_panel()
	if not is_open() then
		return
	end
	local target_width = calculate_target_width()
	pcall(api.nvim_win_set_width, PanelState.winid, target_width)
end

-- Function to set up buffer-local keymaps for the panel (no changes needed)
local function setup_panel_keymaps(bufnr, winid)
	local task_prefix = "- [ ] "
	vim.keymap.set("i", "<C-Enter>", function()
		local lnum = api.nvim_win_get_cursor(winid)[1]
		local line_content = api.nvim_buf_get_lines(bufnr, lnum - 1, lnum, false)[1] or ""
		local indent = line_content:match("^%s*") or ""
		api.nvim_buf_set_lines(bufnr, lnum, lnum, false, { indent .. task_prefix })
		api.nvim_win_set_cursor(winid, { lnum + 1, #indent + #task_prefix })
	end, { buffer = bufnr, noremap = true, silent = true, desc = "New TODO task below" })
	vim.keymap.set("n", "o", function()
		local lnum = api.nvim_win_get_cursor(winid)[1]
		local line_content = api.nvim_buf_get_lines(bufnr, lnum - 1, lnum, false)[1] or ""
		local indent = line_content:match("^%s*") or ""
		api.nvim_buf_set_lines(bufnr, lnum, lnum, false, { "" })
		api.nvim_buf_set_lines(bufnr, lnum, lnum + 1, false, { indent .. task_prefix })
		api.nvim_win_set_cursor(winid, { lnum + 1, #indent + #task_prefix })
		vim.cmd.startinsert()
	end, { buffer = bufnr, noremap = true, silent = true, desc = "Open new TODO task below" })
	vim.keymap.set("n", "O", function()
		local lnum = api.nvim_win_get_cursor(winid)[1]
		local line_content = api.nvim_buf_get_lines(bufnr, lnum - 1, lnum, false)[1] or ""
		local indent = line_content:match("^%s*") or ""
		api.nvim_buf_set_lines(bufnr, lnum - 1, lnum - 1, false, { indent .. task_prefix })
		api.nvim_win_set_cursor(winid, { lnum, #indent + #task_prefix })
		vim.cmd.startinsert()
	end, { buffer = bufnr, noremap = true, silent = true, desc = "Open new TODO task above" })
	vim.keymap.set("n", "<CR>", function()
		if not winid or not api.nvim_win_is_valid(winid) or not bufnr or not api.nvim_buf_is_valid(bufnr) then
			return
		end
		local lnum = api.nvim_win_get_cursor(winid)[1]
		local line_content = api.nvim_buf_get_lines(bufnr, lnum - 1, lnum, false)[1]
		if line_content == nil or vim.bo[bufnr].readonly or not vim.bo[bufnr].modifiable then
			return
		end
		local incomplete_marker_literal = "[ ] "
		local complete_marker_literal = "[x] "
		local incomplete_marker_pattern = "%[ %] "
		local complete_marker_pattern = "%[x%] "
		local modified = false
		local new_line = nil
		if line_content:find(incomplete_marker_literal, 1, true) then
			new_line = line_content:gsub(incomplete_marker_pattern, complete_marker_literal, 1)
			if new_line ~= line_content then
				modified = true
			end
		elseif line_content:find(complete_marker_literal, 1, true) then
			new_line = line_content:gsub(complete_marker_pattern, incomplete_marker_literal, 1)
			if new_line ~= line_content then
				modified = true
			end
		end
		if modified and new_line then
			pcall(api.nvim_buf_set_lines, bufnr, lnum - 1, lnum, false, { new_line })
			pcall(api.nvim_win_set_cursor, winid, { lnum, 0 })
		end
	end, { buffer = bufnr, noremap = true, silent = true, desc = "Toggle TODO task completion" })
end

-- Function to open the TODO panel (no changes needed, uses calculate_target_width)
local function open()
	if is_open() then
		pcall(api.nvim_set_current_win, PanelState.winid)
		return
	end
	local bufnr = get_todo_buf()
	if not bufnr then
		vim.notify("Error getting TODO buffer", vim.log.levels.ERROR)
		return
	end
	PanelState.last_focused_winid = api.nvim_get_current_win()
	local vs_ok, vs_err = pcall(vim.cmd, "silent! rightbelow vsplit")
	if not vs_ok then
		vim.notify("Error during vsplit command: " .. tostring(vs_err), vim.log.levels.ERROR)
		if PanelState.last_focused_winid and api.nvim_win_is_valid(PanelState.last_focused_winid) then
			pcall(api.nvim_set_current_win, PanelState.last_focused_winid)
		end
		PanelState.last_focused_winid = nil
		return
	end
	local new_winid = api.nvim_get_current_win()
	if not new_winid or not api.nvim_win_is_valid(new_winid) then
		vim.notify("Failed to get a valid window ID after vsplit.", vim.log.levels.ERROR)
		if PanelState.last_focused_winid and api.nvim_win_is_valid(PanelState.last_focused_winid) then
			pcall(api.nvim_set_current_win, PanelState.last_focused_winid)
		end
		PanelState.last_focused_winid = nil
		return
	end
	local setbuf_ok, setbuf_err = pcall(api.nvim_win_set_buf, new_winid, bufnr)
	if not setbuf_ok then
		vim.notify("Failed to set buffer for TODO panel: " .. tostring(setbuf_err), vim.log.levels.ERROR)
		pcall(api.nvim_win_close, new_winid, true)
		if PanelState.last_focused_winid and api.nvim_win_is_valid(PanelState.last_focused_winid) then
			pcall(api.nvim_set_current_win, PanelState.last_focused_winid)
		end
		PanelState.last_focused_winid = nil
		return
	end
	PanelState.winid = new_winid
	api.nvim_win_set_option(new_winid, "winfixbuf", true)
	api.nvim_win_set_option(new_winid, "number", false)
	api.nvim_win_set_option(new_winid, "relativenumber", false)
	api.nvim_buf_set_option(bufnr, "filetype", "markdown")
	local initial_width = calculate_target_width() -- Calculate width based on current aspect ratio
	pcall(api.nvim_win_set_width, new_winid, initial_width)
	setup_panel_keymaps(bufnr, new_winid)
	pcall(api.nvim_set_current_win, new_winid)
end

-- Function to close the TODO panel (no changes needed)
local function close()
	if not is_open() then
		return
	end
	local winid_to_close = PanelState.winid
	local focus_target = PanelState.last_focused_winid
	PanelState.winid = nil
	PanelState.last_focused_winid = nil
	pcall(api.nvim_win_close, winid_to_close, true)
	if focus_target and api.nvim_win_is_valid(focus_target) then
		vim.schedule(function()
			if api.nvim_win_is_valid(focus_target) then
				pcall(api.nvim_set_current_win, focus_target)
			end
		end)
	end
end

-- Function to toggle the panel's visibility (no changes needed)
local function toggle()
	if is_open() then
		if api.nvim_get_current_win() == PanelState.winid then
			close()
		else
			if PanelState.winid and api.nvim_win_is_valid(PanelState.winid) then
				api.nvim_set_current_win(PanelState.winid)
			else
				close()
			end
		end
	else
		open()
	end
end

-- Setup function (no changes needed here, VimResized handled)
local function setup()
	vim.keymap.set("n", "<leader>t", toggle, { desc = "[T]oggle right-side TODO panel" })
	api.nvim_create_autocmd(
		"VimResized",
		{ pattern = "*", desc = "Resize TODO panel proportionally", callback = resize_panel }
	)
	api.nvim_create_autocmd("WinClosed", {
		pattern = "*",
		desc = "Reset TODO Panel state if closed manually",
		callback = function(args)
			local closed_winid = tonumber(args.match)
			if closed_winid and closed_winid == PanelState.winid then
				PanelState.winid = nil
				PanelState.last_focused_winid = nil
			end
		end,
	})
	api.nvim_create_autocmd("BufWinEnter", {
		pattern = PanelState.todo_file_path,
		desc = "Ensure TODO buffer is loaded and keymaps are set",
		callback = function(args)
			local current_winid = api.nvim_get_current_win()
			if args.buf == PanelState.bufnr then
				vim.fn.bufload(args.buf)
				setup_panel_keymaps(args.buf, current_winid)
			end
		end,
	})
end

return { setup = setup, open = open, close = close, toggle = toggle }
