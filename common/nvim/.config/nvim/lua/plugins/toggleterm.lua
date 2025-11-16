return {
	{
		"akinsho/toggleterm.nvim",
		config = true,
		cmd = "ToggleTerm",
		keys = { { "<C-t>", "<cmd>ToggleTerm<cr>", desc = "Toggle floating terminal" } },
		opts = {
			open_mapping = [[<C-t>]],
			direction = "float",
			float_opts = {
				border = "curved",
				winblend = 0,
			},
			shade_filetypes = {},
			hide_numbers = true,
			insert_mappings = true,
			terminal_mappings = true,
			start_in_insert = true,
			close_on_exit = true,
		},
	},
}
