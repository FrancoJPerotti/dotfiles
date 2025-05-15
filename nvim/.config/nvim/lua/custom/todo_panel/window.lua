local api = vim.api
local State = require("custom.todo_panel.state")
local Buffer = require("custom.todo_panel.buffer")
local Keymaps = require("custom.todo_panel.keymaps") -- Need this to set keymaps after opening

local M = {}

-- Calculate target width based on proportions and aspect ratio
local function calculate_target_width()
	local total_columns = api.nvim_get_option_value("columns", {})
	local total_lines = api.nvim_get_option_value("lines", {})
	local prop_h, prop_v, threshold = State.get_proportions()
	local target_proportion

	if total_lines == 0 then
		target_proportion = prop_h
	elseif (total_columns / total_lines) > threshold then
		target_proportion = prop_h
	else
		target_proportion = prop_v
	end

	local target = math.floor(total_columns * target_proportion)
	return math.max(State.get_min_width(), target)
end

-- Open the panel window
function M.open()
	if State.is_open() then
		pcall(api.nvim_set_current_win, State.get_winid())
		return
	end

	local bufnr = Buffer.get_bufnr()
	if not bufnr then
		vim.notify("Error getting TODO buffer", vim.log.levels.ERROR)
		return
	end

	State.set_last_focused_winid(api.nvim_get_current_win())

	local vs_ok, vs_err = pcall(vim.cmd, "silent! rightbelow vsplit")
	if not vs_ok then
		vim.notify("Error during vsplit command: " .. tostring(vs_err), vim.log.levels.ERROR)
		State.set_last_focused_winid(nil) -- Reset focus tracking
		return
	end

	local new_winid = api.nvim_get_current_win()
	if not new_winid or not api.nvim_win_is_valid(new_winid) then
		vim.notify("Failed to get valid window ID after vsplit.", vim.log.levels.ERROR)
		State.set_last_focused_winid(nil)
		return
	end

	local setbuf_ok, setbuf_err = pcall(api.nvim_win_set_buf, new_winid, bufnr)
	if not setbuf_ok then
		vim.notify("Failed to set buffer for TODO panel: " .. tostring(setbuf_err), vim.log.levels.ERROR)
		pcall(api.nvim_win_close, new_winid, true)
		State.set_last_focused_winid(nil)
		return
	end

	State.set_winid(new_winid) -- Store the ID only after success

	-- Apply window options
	api.nvim_win_set_option(new_winid, "winfixbuf", true)
	api.nvim_win_set_option(new_winid, "number", false)
	api.nvim_win_set_option(new_winid, "relativenumber", false)
	api.nvim_buf_set_option(bufnr, "filetype", "markdown") -- Set filetype on buffer

	-- Set initial width
	local initial_width = calculate_target_width()
	pcall(api.nvim_win_set_width, new_winid, initial_width)

	-- Set buffer-local keymaps for the new window/buffer
	Keymaps.setup_buffer_local(bufnr, new_winid)

	-- Focus the new window
	pcall(api.nvim_set_current_win, new_winid)
end

-- Close the panel window
function M.close()
	if not State.is_open() then
		return
	end

	local winid_to_close = State.get_winid()
	local focus_target = State.get_last_focused_winid()

	-- Reset state *before* closing window
	State.set_winid(nil)
	State.set_last_focused_winid(nil)

	pcall(api.nvim_win_close, winid_to_close, true)

	if focus_target and api.nvim_win_is_valid(focus_target) then
		vim.schedule(function()
			if api.nvim_win_is_valid(focus_target) then
				pcall(api.nvim_set_current_win, focus_target)
			end
		end)
	end
end

-- Toggle the panel
function M.toggle()
	if State.is_open() then
		if api.nvim_get_current_win() == State.get_winid() then
			M.close()
		else
			pcall(api.nvim_set_current_win, State.get_winid())
		end
	else
		M.open()
	end
end

-- Resize the panel
function M.resize()
	if not State.is_open() then
		return
	end
	local target_width = calculate_target_width()
	pcall(api.nvim_win_set_width, State.get_winid(), target_width)
end

return M
