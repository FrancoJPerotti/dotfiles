local api = vim.api
local Actions = require("custom.todo_panel.actions")

local M = {}

-- Sets up the global keymap to toggle the panel
function M.setup_global(toggle_func)
	vim.keymap.set("n", "<leader>t", toggle_func, { desc = "[T]oggle right-side TODO panel" })
end

-- Sets up the buffer-local keymaps for the panel itself
function M.setup_buffer_local(bufnr, winid)
	local opts = { buffer = bufnr, noremap = true, silent = true }

	-- INSERT MODE
	vim.keymap.set("i", "<C-Enter>", function()
		Actions.add_task_below(bufnr, winid)
	end, vim.tbl_extend("force", opts, { desc = "New TODO task below" }))
	vim.keymap.set("i", "<Tab>", function()
		-- Attempt to indent; if it returns false (not a task line), insert indent unit
		if not Actions.indent_task(bufnr, winid) then
			return "  " -- Fallback: return indent string (adjust if using tabs)
		end
	end, vim.tbl_extend("force", opts, { expr = true, desc = "Indent TODO task / Insert indent" })) -- Use expr = true
	vim.keymap.set("i", "<S-Tab>", function()
		Actions.unindent_task(bufnr, winid)
	end, vim.tbl_extend("force", opts, { desc = "Unindent TODO task" }))

	-- NORMAL MODE
	vim.keymap.set("n", "o", function()
		Actions.open_task_below(bufnr, winid)
	end, vim.tbl_extend("force", opts, { desc = "Open new TODO task below" }))
	vim.keymap.set("n", "O", function()
		Actions.open_task_above(bufnr, winid)
	end, vim.tbl_extend("force", opts, { desc = "Open new TODO task above" }))
	vim.keymap.set("n", "<CR>", function()
		Actions.toggle_task(bufnr, winid)
	end, vim.tbl_extend("force", opts, { desc = "Toggle TODO task completion" }))
	vim.keymap.set("n", "<Tab>", function()
		Actions.indent_task(bufnr, winid)
	end, vim.tbl_extend("force", opts, { desc = "Indent TODO task" }))
	vim.keymap.set("n", "<S-Tab>", function()
		Actions.unindent_task(bufnr, winid)
	end, vim.tbl_extend("force", opts, { desc = "Unindent TODO task" }))
end

return M
