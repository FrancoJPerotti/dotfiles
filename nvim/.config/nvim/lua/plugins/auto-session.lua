return {
	"rmagatti/auto-session",
	lazy = false,

	---enables autocomplete for opts
	---@module "auto-session"
	---@type AutoSession.Config
	opts = {
		suppressed_dirs = { "~/", "~/Projects", "~/Downloads", "/" },
		-- log_level = 'debug',
	},

	vim.keymap.set("n", "<C-s>", "<cmd>AutoSession search<cr>", { desc = "Select session" }),
}
