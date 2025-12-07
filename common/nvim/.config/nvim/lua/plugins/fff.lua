return {
	{
		"dmtrKovalenko/fff.nvim",
		build = function() require("fff.download").download_or_build_binary() end,
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
	},
}
