return {
	"vague2k/huez.nvim",
	branch = "stable",
	lazy = false,
	priority = 1000,
	import = "huez-manager.import",
	config = function()
		require("huez").setup({
			fallback = "tokyonight-night",
			background = "dark",
		})
	end,
}
