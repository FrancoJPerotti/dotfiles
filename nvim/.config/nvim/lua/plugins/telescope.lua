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
		local smart_delete = require("telescope.buffer_utils").smart_delete
		local themes = require("telescope.themes")

		-- Abbreviate path by shortening intermediate dirs
		local function abbreviate_path(path)
			local home = vim.fn.getenv("HOME")
			path = path:gsub("^" .. home .. "/", "") -- remove ~/ entirely

			local parts = vim.split(path, "/")
			for i = 1, #parts - 1 do
				parts[i] = parts[i]:sub(1, 4)
			end

			return table.concat(parts, "/")
		end

		-- Preload project directories on startup using your find command
		local project_dirs = vim.fn.systemlist([[
			find ~ -type d -name .git -prune 2>/dev/null |
			sed 's|/\.git||' |
			grep -v '/\.[^/]\+'
		]])

		-- Custom picker uses pre-loaded dirs
		local function project_folder_picker()
			pickers
				.new(
					themes.get_dropdown({
						prompt_title = " Git Projects",
					}),
					{ -- normal picker opts
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
					}
				)
				:find()
		end

		telescope.setup({
			defaults = {
				path_display = { "smart" },
				mappings = {
					i = {
						["<Esc>"] = actions.close,
					},
				},
			},
			pickers = {
				live_grep = {
					file_ignore_patterns = { "node_modules", ".git", ".venv" },
					additional_args = function(_)
						return { "--hidden" }
					end,
				},
				find_files = {
					follow = true,
					file_ignore_patterns = { "node_modules", ".git", ".venv" },
					hidden = true,
					previewer = false,
				},
				buffers = {
					entry_maker = require("telescope.custom_buffers").gen_with_dot(),
					previewer = false,
					mappings = {
						i = { ["<C-d>"] = smart_delete },
						n = { ["<C-d>"] = smart_delete },
					},
				},
			},
		})

		telescope.load_extension("fzf")

		-- Set keymaps
		local keymap = vim.keymap

		-- Fuzzy find files
		keymap.set(
			"n",
			"<leader><leader>",
			"<cmd>Telescope find_files theme=dropdown<cr>",
			{ desc = "Fuzzy find files in cwd" }
		)

		-- Fuzzy find recent files
		keymap.set(
			"n",
			"<leader>fr",
			"<cmd>Telescope oldfiles theme=dropdown<cr>",
			{ desc = "Fuzzy find recent files" }
		)

		-- Fuzzy find strings
		keymap.set("n", "<leader>fs", "<cmd>Telescope live_grep theme=dropdown<cr>", { desc = "Find string in cwd" })

		-- Fuzzy find string under cursor
		keymap.set(
			"n",
			"<leader>fc",
			"<cmd>Telescope grep_string theme=dropdown<cr>",
			{ desc = "Find string under cursor in cwd" }
		)

		-- Fuzzy find functions/methods
		keymap.set("n", "<leader>ff", function()
			require("telescope.builtin").lsp_document_symbols({
				symbols = { "function", "method" },
			})
		end, { desc = "Jump to function/method (LSP)" })

		-- Fuzzy find TODOs
		keymap.set("n", "<leader>ft", "<cmd>TodoTelescope theme=dropdown<cr>", { desc = "Find todos" })

		-- Fuzzy find git projects
		keymap.set("n", "<leader>fp", project_folder_picker, { desc = "Switch project folder (cwd)" })

		-- Fuzzy find references
		keymap.set("n", "gr", "<cmd>Telescope lsp_references theme=dropdown<cr>", { desc = "Find references" })

		-- Fuzzy find buffers
		keymap.set("n", "<leader>t", "<cmd>Telescope buffers theme=dropdown<cr>", { desc = "Show buffer list" })
	end,
}
