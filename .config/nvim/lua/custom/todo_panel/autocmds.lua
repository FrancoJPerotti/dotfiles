local api = vim.api
local State = require("custom.todo_panel.state")
local Window = require("custom.todo_panel.window")
local Buffer = require("custom.todo_panel.buffer")
local Keymaps = require("custom.todo_panel.keymaps") -- Need this for BufWinEnter

local M = {}

function M.setup()
	-- Optional: Open on startup
	-- api.nvim_create_autocmd("VimEnter", {
	--   pattern = "*",
	--   desc = "Open TODO Panel on Vim Enter",
	--   callback = Window.open,
	--   once = true,
	-- })

	api.nvim_create_autocmd("VimResized", {
		pattern = "*",
		desc = "Resize TODO panel proportionally",
		callback = Window.resize, -- Call the resize function from window module
	})

	api.nvim_create_autocmd("WinClosed", {
		pattern = "*",
		desc = "Reset TODO Panel state if closed manually",
		callback = State.reset_on_close, -- Call state reset function
	})

	api.nvim_create_autocmd("BufWinEnter", {
		pattern = State.get_todo_file_path(), -- Use path from state
		desc = "Ensure TODO buffer is loaded and keymaps are set",
		callback = function(args)
			local current_winid = api.nvim_get_current_win()
			-- Ensure buffer is loaded *before* setting keymaps
			local bufnr = Buffer.get_bufnr() -- This ensures it's created/loaded
			if args.buf == bufnr then
				-- Setup keymaps for the buffer in the window it just entered
				Keymaps.setup_buffer_local(args.buf, current_winid)
			end
		end,
	})
end

return M
