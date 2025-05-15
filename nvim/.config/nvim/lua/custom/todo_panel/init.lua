local Window = require("custom.todo_panel.window")
local Keymaps = require("custom.todo_panel.keymaps")
local Autocmds = require("custom.todo_panel.autocmds")

local M = {}

function M.setup()
	-- Set up global keymap (<leader>t) to call Window.toggle
	Keymaps.setup_global(Window.toggle)
	-- Set up all autocommands
	Autocmds.setup()
end

-- Expose public API functions
M.toggle = Window.toggle
M.open = Window.open
M.close = Window.close

return M

-- Example usage in your main init.lua:
-- require('custom.todo_panel').setup()
