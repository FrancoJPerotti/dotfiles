return {
	"A7Lavinraj/fyler.nvim",
	dependencies = { "nvim-tree/nvim-web-devicons", "folke/snacks.nvim" },
	branch = "main", -- Use stable branch for production
	lazy = false, -- Necessary for `default_explorer` to work properly
	keys = {
		{
			"<leader>e",
			function()
				require("fyler").toggle({ kind = "float" })
			end,
			desc = "Toggle Fyler view (float)",
		},
	},
	config = function()
		local function close_view(self)
			if self.action_call then
				self:action_call("n_close")
			else
				self:exec_action("n_close")
			end
		end

		local function close_with_save(self)
			if not self.win or not vim.api.nvim_buf_is_valid(self.win.bufnr) then
				close_view(self)
				return
			end

			local function has_changes()
				if not self.files or not self.files.diff_with_buffer then
					return false
				end

				local ok, operations = pcall(function()
					return self.files:diff_with_buffer()
				end)
				if not ok then
					vim.notify("Fyler diff failed: " .. tostring(operations), vim.log.levels.ERROR)
					return false
				end
				return operations and not vim.tbl_isempty(operations)
			end

			if not has_changes() then
				close_view(self)
				return
			end

			self:dispatch_mutation()

			local attempts = 0
			local function check_and_close()
				if not self.win or not vim.api.nvim_buf_is_valid(self.win.bufnr) then
					return
				end
				if not has_changes() then
					close_view(self)
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
			integrations = {
				icon = "nvim_web_devicons",
				winpick = {
					provider = "snacks",
				},
			},
			views = {
				finder = {
					-- Skips confirmation for simple edits with following condition:
					-- CREATE <= 5 && DELETE == 0 && MOVE <= 1 && COPY <= 1
					confirm_simple = false,
					git_status = {
						enabled = true,
						symbols = {
							Untracked = "U",
							Added = " ",
							Modified = " ",
							Deleted = " ",
							Renamed = " ",
							Copied = "~",
							Conflict = "!",
							Ignored = "◌",
						},
					},
					mappings = {
						["q"] = "CloseView",
						["<Esc>"] = close_with_save,
						["<CR>"] = "Select",
						["<C-t>"] = "SelectTab",
						["<C-v>"] = "SelectVSplit",
						["<C-x>"] = "SelectSplit",
						["^"] = "GotoParent",
						["="] = "GotoCwd",
						["."] = "GotoNode",
						["#"] = "CollapseAll",
						["<BS>"] = "CollapseNode",
					},
					win = {
						kind = "float",
						kinds = {
							float = {
								height = "70%",
								width = "40%",
								top = "10%",
								left = "30%",
							},
						},
					},
				},
			},
		})
	end,
}
