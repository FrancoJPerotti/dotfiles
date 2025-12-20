return {
	"miversen33/sunglasses.nvim",
	config = function()
		require("sunglasses").setup({
			filter_percent = 0.25,
		})
	end,
}
