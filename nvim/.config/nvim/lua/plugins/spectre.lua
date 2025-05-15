return {
	{
		"nvim-pack/nvim-spectre",
		dependencies = { "nvim-lua/plenary.nvim" },
		config = function()
			require("spectre").setup({
				-- your overrides (or leave empty for defaults)
			})
			-- map <leader>sr to open Spectre
			vim.keymap.set("n", "<leader>ra", require("spectre").open, { desc = "Spectre: Search and Replace" })
		end,
	},
}
