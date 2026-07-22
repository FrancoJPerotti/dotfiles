-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
	local lazyrepo = "https://github.com/folke/lazy.nvim.git"
	local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
	if vim.v.shell_error ~= 0 then
		vim.api.nvim_echo({
			{ "Failed to clone lazy.nvim:\n", "ErrorMsg" },
			{ out, "WarningMsg" },
			{ "\nPress any key to exit..." },
		}, true, {})
		vim.fn.getchar()
		os.exit(1)
	end
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
	{ import = "plugins" },
}, {
	-- General settings
	install = { colorscheme = { "habamax" } },
	checker = {
		enabled = true,
		notify = false,
	},
	change_detection = {
		notify = false,
	},
	rocks = {
		-- No configured plugin uses LuaRocks. Avoid bootstrapping a broken,
		-- unused hererocks installation and the corresponding health error.
		enabled = false,
	},
})

vim.api.nvim_create_autocmd("FileType", {
	pattern = "lazy",
	callback = function()
		vim.keymap.set("n", "<Esc>", "<cmd>q<CR>", { buffer = true, desc = "Close Lazy with <Esc>" })
		-- Optional: disable q if you don't want it
		-- vim.keymap.del("n", "q", { buffer = true })
	end,
})
