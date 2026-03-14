return {
	"https://codeberg.org/andyg/leap.nvim",
	opts = {
		preview_filter = function()
			return false
		end,
		safe_labels = {},
		labels = "arstneiohdypfugwvqmlxkcz/ARSTNEIOHDFPYGUVWQMLXZ",
	},
	vim.keymap.set("n", "t", "<Plug>(leap-anywhere)"),
}
