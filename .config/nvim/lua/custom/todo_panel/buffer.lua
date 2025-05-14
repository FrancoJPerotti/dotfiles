local api = vim.api
local fn = vim.fn
local State = require("custom.todo_panel.state")

local M = {}

-- Gets the buffer number for the TODO file, creating/loading if necessary
function M.get_bufnr()
	local current_bufnr = State.get_bufnr()
	if current_bufnr and api.nvim_buf_is_valid(current_bufnr) then
		if not fn.bufloaded(current_bufnr) then
			fn.bufload(current_bufnr)
		end
		return current_bufnr
	end

	local todo_abs = fn.fnamemodify(State.get_todo_file_path(), ":p")
	local bufnr = fn.bufadd(todo_abs)
	vim.fn.bufload(bufnr) -- Ensure buffer is loaded

	if fn.filereadable(todo_abs) == 0 then
		fn.writefile({}, todo_abs)
		vim.fn.bufload(bufnr) -- Reload after creating
	end

	-- Set buffer options
	api.nvim_buf_set_option(bufnr, "buflisted", false)
	api.nvim_buf_set_option(bufnr, "swapfile", false) -- Don't create swap file for todo list
	api.nvim_buf_set_option(bufnr, "bufhidden", "hide") -- Keep buffer loaded when hidden

	State.set_bufnr(bufnr)
	return bufnr
end

return M
