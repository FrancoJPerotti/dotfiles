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
require("config.options")

-- Keymaps
require("config.keymaps")

-- Custom Commands
require("config.custom-commands")

-- Neovide
require("config.neovide")

-- Lazy
require("core.lazy")

-- LSP
require("core.lsp")

-- Dim inactive buffers
local sunglasses_options = {
	filter_percent = 0.25,
}

require("sunglasses").setup(sunglasses_options)
