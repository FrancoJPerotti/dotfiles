return {
	{
		"dmtrKovalenko/fff.nvim",
		build = function() require("fff.download").download_or_build_binary() end,
		dependencies = { "folke/snacks.nvim" },
		opts = {
			debug = {
				enabled = false,
				show_scores = false,
			},
		},
		lazy = false,
		keys = {
			{
				"<leader><leader>",
				function()
					require("fff").find_files()
				end,
				desc = "FFFind files",
			},
			{
				"<leader>fg",
				function()
					require("fff").find_in_git_root()
				end,
				desc = "FFFind git root",
			},
		},
		config = function(_, opts)
			require("fff").setup(opts)
			require("config.winpick").setup_fff()
		end,
	},
}
