local fn = vim.fn
local api = vim.api

local M = {}

-- Default state and configuration
local state = {
	winid = nil,
	bufnr = nil,
	last_focused_winid = nil,
	proportional_width_h = 0.15, -- Horizontal proportion
	proportional_width_v = 0.25, -- Vertical proportion
	aspect_ratio_threshold = 1.5,
	min_width = 25,
	todo_file_path = fn.expand("~/.config/nvim/todo.md"),
}

function M.get_winid()
	return state.winid
end
function M.set_winid(winid)
	state.winid = winid
end

function M.get_bufnr()
	return state.bufnr
end
function M.set_bufnr(bufnr)
	state.bufnr = bufnr
end

function M.get_last_focused_winid()
	return state.last_focused_winid
end
function M.set_last_focused_winid(winid)
	state.last_focused_winid = winid
end

function M.get_todo_file_path()
	return state.todo_file_path
end

function M.get_proportions()
	return state.proportional_width_h, state.proportional_width_v, state.aspect_ratio_threshold
end

function M.get_min_width()
	return state.min_width
end

function M.is_panel_window(winid)
	return winid and winid == state.winid
end

function M.is_open()
	return state.winid and api.nvim_win_is_valid(state.winid)
end

function M.reset_on_close()
	-- Only reset if the currently stored winid is actually being closed
	-- This prevents issues if another autocommand closes a different window
	-- while our panel happens to be open.
	local current_winid_being_closed = tonumber(vim.v.event.match) -- Get winid from WinClosed event
	if current_winid_being_closed and current_winid_being_closed == state.winid then
		state.winid = nil
		state.last_focused_winid = nil
	end
end

return M
