return {
	{
		"dmtrKovalenko/fff.nvim",
		version = "0.10.0",
		-- enabled = false,
		build = function()
			require("fff.download").download_or_build_binary()
		end,
		dependencies = { "folke/snacks.nvim" },
		init = function()
			vim.g.fff = vim.tbl_deep_extend("force", vim.g.fff or {}, {
				lazy_sync = true,
			})
		end,
		opts = {
			lazy_sync = true,
			debug = {
				enabled = false,
				show_scores = false,
			},
			keymaps = {
				select_split = "<C-x>",
				select_vsplit = "<C-v>",
			},
			select = {
				select_window = function(_, action)
					if action == "tab" then
						return nil
					end
					return require("config.winpick").pick_window({})
				end,
			},
		},
		lazy = true,
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
		end,
	},
}
