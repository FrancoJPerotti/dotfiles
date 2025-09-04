return {
	"brianhuster/live-preview.nvim",
	dependencies = { "nvim-telescope/telescope.nvim" },

	opts = {
		browser = [[sh -c 'exec /opt/vivaldi/vivaldi --app="$0"']],
	},

	keys = {
		{
			"<leader>mp",
			function()
				-- Always restart: close (ignore errors), then start after a tiny delay
				pcall(vim.cmd, "LivePreview close")
				-- small delay avoids race conditions while the server shuts down
				vim.defer_fn(function()
					vim.cmd("LivePreview start")
					vim.notify("LivePreview: restarted", vim.log.levels.INFO)
				end, 150)
			end,
			desc = "Restart LivePreview (close+start)",
		},
	},

	config = function(_, opts)
		require("livepreview").setup(opts)
	end,
}
