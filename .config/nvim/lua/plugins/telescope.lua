return {
	"nvim-telescope/telescope.nvim",
	branch = "0.1.x",
	dependencies = {
		"nvim-lua/plenary.nvim",
		{ "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
		"nvim-tree/nvim-web-devicons",
		"folke/todo-comments.nvim",
	},
	config = function()
		local telescope = require("telescope")
		local actions = require("telescope.actions")
		local pickers = require("telescope.pickers")
		local finders = require("telescope.finders")
		local conf = require("telescope.config").values
		local action_state = require("telescope.actions.state")

		-- 🔤 Abbreviate path by shortening intermediate dirs
		local function abbreviate_path(path)
			local home = vim.fn.getenv("HOME")
			path = path:gsub("^" .. home .. "/", "") -- remove ~/ entirely

			local parts = vim.split(path, "/")
			for i = 1, #parts - 1 do
				parts[i] = parts[i]:sub(1, 4)
			end

			return table.concat(parts, "/")
		end

		-- 🔁 Preload project directories on startup using your find command
		local project_dirs = vim.fn.systemlist([[
			find ~ -type d -name .git -prune 2>/dev/null |
			sed 's|/\.git||' |
			grep -v '/\.[^/]\+'
		]])

		-- 📁 Custom picker uses preloaded dirs
		local function project_folder_picker()
			pickers
				.new({}, {
					prompt_title = "📁 Switch Project",
					finder = finders.new_table({
						results = vim.tbl_map(function(path)
							return {
								display = abbreviate_path(path),
								value = path,
							}
						end, project_dirs),
						entry_maker = function(entry)
							return {
								value = entry.value,
								display = entry.display,
								ordinal = entry.display,
							}
						end,
					}),
					sorter = conf.generic_sorter({}),
					attach_mappings = function(prompt_bufnr, _)
						actions.select_default:replace(function()
							local selection = action_state.get_selected_entry().value
							actions.close(prompt_bufnr)

							vim.cmd("cd " .. vim.fn.fnameescape(selection))
							vim.notify("Changed cwd to: " .. selection, vim.log.levels.INFO)

							local ok, tree = pcall(require, "nvim-tree.api")
							if ok then
								tree.tree.change_root(selection)
							end
						end)
						return true
					end,
				})
				:find()
		end

		telescope.setup({
			defaults = {
				path_display = { "smart" },
				mappings = {
					i = {
						["<C-k>"] = actions.move_selection_previous,
						["<C-j>"] = actions.move_selection_next,
						["<C-q>"] = actions.send_selected_to_qflist + actions.open_qflist,
					},
				},
			},
			pickers = {
				find_files = {
					follow = true,
				},
			},
		})

		telescope.load_extension("fzf")

		-- Set keymaps
		local keymap = vim.keymap
		keymap.set(
			"n",
			"<leader><leader>",
			"<cmd>Telescope find_files theme=dropdown<cr>",
			{ desc = "Fuzzy find files in cwd" }
		)
		keymap.set(
			"n",
			"<leader>fr",
			"<cmd>Telescope oldfiles theme=dropdown<cr>",
			{ desc = "Fuzzy find recent files" }
		)
		keymap.set("n", "<leader>fs", "<cmd>Telescope live_grep theme=dropdown<cr>", { desc = "Find string in cwd" })
		keymap.set(
			"n",
			"<leader>fc",
			"<cmd>Telescope grep_string theme=dropdown<cr>",
			{ desc = "Find string under cursor in cwd" }
		)
		keymap.set("n", "<leader>ft", "<cmd>TodoTelescope theme=dropdown<cr>", { desc = "Find todos" })
		keymap.set("n", "<leader>fp", project_folder_picker, { desc = "Switch project folder (cwd)" })
		keymap.set("n", "gr", "<cmd>Telescope lsp_references theme=dropdown<cr>", { desc = "Find references" })
	end,
}
