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
		local smart_delete = require("telescope.buffer_utils").smart_delete
		local project_finder = require("telescope.project_finder")

		telescope.setup({
			defaults = {
				vimgrep_arguments = {
					"rg",
					"--color=never",
					"--no-heading",
					"--with-filename",
					"--line-number",
					"--column",
					"--smart-case",
					"--fixed-strings",
				},
				path_display = { "smart" },
				mappings = {
					i = {
						["<Esc>"] = actions.close,
						["<C-e>"] = actions.cycle_history_next,
						["<C-i>"] = actions.cycle_history_prev,
					},
					n = {
						["<C-e>"] = actions.cycle_history_next,
						["<C-i>"] = actions.cycle_history_prev,
					},
				},
				history = {
					path = vim.fn.stdpath("data") .. "/telescope_history",
					limit = 200,
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
					previewer = true, -- enable preview
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

		local keymap = vim.keymap

		-- Fuzzy find files with PREVIEW on the RIGHT
		keymap.set("n", "<leader><leader>", function()
			require("telescope.builtin").find_files({
				layout_strategy = "flex",
				layout_config = {
					width = 0.90,
					height = 0.85,
					prompt_position = "bottom",
					preview_cutoff = 1,
					horizontal = {
						preview_width = 0.55,
						mirror = false,
					},
				},
				hidden = true,
				follow = true,
			})
		end, { desc = "Fuzzy find files in cwd (preview on right)" })

		-- Fuzzy find recent files
		keymap.set(
			"n",
			"<leader>fr",
			"<cmd>Telescope oldfiles theme=dropdown<cr>",
			{ desc = "Fuzzy find recent files" }
		)

		-- Fuzzy find strings
		keymap.set("n", "<leader>fs", "<cmd>Telescope live_grep<cr>", { desc = "Find string in cwd" })

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
		keymap.set("n", "<leader>fp", project_finder.open, { desc = "Switch project folder (cwd)" })

		-- Fuzzy find references
		keymap.set("n", "gr", "<cmd>Telescope lsp_references theme=dropdown<cr>", { desc = "Find references" })

		-- Fuzzy find buffers
		keymap.set("n", "<leader>t", "<cmd>Telescope buffers theme=dropdown<cr>", { desc = "Show buffer list" })
	end,
}
