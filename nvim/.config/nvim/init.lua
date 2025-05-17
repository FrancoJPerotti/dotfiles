-- Synchronize the color of nvim with terminal
vim.api.nvim_create_autocmd({ "UIEnter", "ColorScheme" }, {
	callback = function()
		local normal = vim.api.nvim_get_hl(0, { name = "Normal" })
		if not normal.bg then
			return
		end
		io.write(string.format("\027]11;#%06x\027\\", normal.bg))
	end,
})

vim.api.nvim_create_autocmd("UILeave", {
	callback = function()
		io.write("\027]111\027\\")
	end,
})

-- Options
require("options")

-- Keymaps
require("keymaps")

-- Custom Commands
require("custom-commands")

-- Neovide
require("neovide")

-- Todo
require("custom.todo_panel").setup()

-- Lazy
require("config.lazy")

require("bufferline").setup({})

-- Dim inactive buffers
local sunglasses_options = {
	filter_percent = 0.25,
}

require("sunglasses").setup(sunglasses_options)

-- Enable LSP servers
vim.lsp.enable({ "clangd", "lua_ls", "pyright", "rust_analyzer", "bash-language-server" })
