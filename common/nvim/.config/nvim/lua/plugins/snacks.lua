return {
	"folke/snacks.nvim",
	lazy = false,
	priority = 1000,
	opts = {
		-- Used by CodeCompanion's action palette and Fyler's window picker.
		picker = {
			enabled = true,
			-- dressing.nvim owns vim.ui.select in this configuration.
			ui_select = false,
		},
	},
}
