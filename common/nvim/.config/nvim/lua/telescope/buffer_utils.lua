local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")

local M = {}

function M.smart_delete(prompt_bufnr)
	----------------------------------------------------------------------------
	-- save the picker’s prompt window *before* we move anywhere else
	----------------------------------------------------------------------------
	local prompt_win = vim.api.nvim_get_current_win()

	local entry = action_state.get_selected_entry()
	if not entry or not entry.bufnr then
		return
	end
	local target = entry.bufnr

	----------------------------------------------------------------------------
	-- 1. if the target buffer is visible, show something else in those windows
	----------------------------------------------------------------------------
	local wins = vim.fn.getbufinfo(target)[1].windows or {}
	for _, win in ipairs(wins) do
		vim.api.nvim_set_current_win(win)

		vim.cmd("bprevious")
		if vim.api.nvim_get_current_buf() == target then
			vim.cmd("bnext")
		end
		if vim.api.nvim_get_current_buf() == target then
			vim.cmd("enew") -- last buffer → open an empty one
		end
	end

	----------------------------------------------------------------------------
	-- 2. wipe the buffer
	----------------------------------------------------------------------------
	vim.api.nvim_buf_delete(target, { force = true })

	----------------------------------------------------------------------------
	-- 3. jump back to the prompt window *then* close the picker
	----------------------------------------------------------------------------
	if vim.api.nvim_win_is_valid(prompt_win) then
		vim.api.nvim_set_current_win(prompt_win)
	end
	actions.close(prompt_bufnr)
end

return M
