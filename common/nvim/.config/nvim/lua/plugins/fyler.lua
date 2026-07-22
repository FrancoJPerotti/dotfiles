return {
	"A7Lavinraj/fyler.nvim",
	dependencies = { "nvim-tree/nvim-web-devicons", "folke/snacks.nvim" },
	branch = "main", -- Use stable branch for production
	lazy = false, -- Necessary for `default_explorer` to work properly
	keys = {
		{
			"<leader>e",
			function()
				require("fyler").toggle()
			end,
			desc = "Toggle Fyler view (floating)",
		},
	},
	config = function()
		local function close_with_save(self)
			if not self.buf_id or not vim.api.nvim_buf_is_valid(self.buf_id) then
				self:close()
				return
			end

			if not vim.api.nvim_get_option_value("modified", { buf = self.buf_id }) then
				self:close()
				return
			end

			self:mutate()

			local attempts = 0
			local function check_and_close()
				if not self.buf_id or not vim.api.nvim_buf_is_valid(self.buf_id) then
					return
				end
				if not vim.api.nvim_get_option_value("modified", { buf = self.buf_id }) then
					self:close()
					return
				end
				attempts = attempts + 1
				if attempts > 200 then
					return
				end
				vim.defer_fn(check_and_close, 50)
			end

			vim.defer_fn(check_and_close, 50)
		end

		require("fyler").setup({
			auto_confirm_simple_mutation = true,
			kind = "floating",
			ui = {
				hidden_items = {
					-- This is a dotfiles repository, so hiding every dot-prefixed
					-- directory makes folders containing only `.config` look empty.
					switches = {},
					patterns = { "/%.git$" },
					always_visible = {},
					always_hidden = {},
				},
			},
			integrations = {
				icon = "nvim_web_devicons",
				window_picker = function()
					return require("snacks").picker.util.pick_win()
				end,
			},
			kind_presets = {
				floating = {
					height = "70%",
					width = "40%",
					row = "center",
					col = "center",
				},
			},
			extensions = {
				git = {
					enabled = true,
					icons = {
						["??"] = { icon = "U", hl = "FylerGitUntracked" },
						[" M"] = { icon = " ", hl = "FylerGitModified" },
						["M "] = { icon = " ", hl = "FylerGitStaged" },
						["MM"] = { icon = " ", hl = "FylerGitStaged" },
						[" D"] = { icon = " ", hl = "FylerGitDeleted" },
						["D "] = { icon = " ", hl = "FylerGitStaged" },
						["R "] = { icon = " ", hl = "FylerGitRenamed" },
						["UU"] = { icon = "!", hl = "FylerGitConflict" },
						["!!"] = { icon = "◌", hl = "FylerGitIgnored" },
					},
				},
			},
			mappings = {
				n = {
					["<Esc>"] = { action = close_with_save },
					["<C-t>"] = { action = "select", args = { tabedit = true } },
					["<C-v>"] = { action = "select", args = { vsplit = true } },
					["<C-x>"] = { action = "select", args = { split = true } },
					["^"] = { action = "visit", args = { parent = true } },
					["="] = { action = "visit" },
					["."] = { action = "visit", args = { cursor = true } },
					["<BS>"] = { action = "shrink", args = { parent = true } },
				},
			},
		})
	end,
}
