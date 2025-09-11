return {
	"RRethy/vim-illuminate",
	config = function()
		-- custom highlight groups
		vim.api.nvim_set_hl(0, "IlluminatedWordText", { underline = true, bg = "#3c3836" })
		vim.api.nvim_set_hl(0, "IlluminatedWordRead", { underline = true, bg = "#3c3836" })
		vim.api.nvim_set_hl(0, "IlluminatedWordWrite", { underline = true, bg = "#3c3836" })

		require("illuminate").configure({
			-- disable in side-panels and special buffers
			filetypes_denylist = {
				"NvimTree",
				"NeogitStatus",
				"NeogitPopup",
				"NeogitCommitMessage",
				"NeogitConsole",
				"NeogitLogView",
				"TelescopePrompt",
				"TelescopeResults",
			},
		})
	end,
}
