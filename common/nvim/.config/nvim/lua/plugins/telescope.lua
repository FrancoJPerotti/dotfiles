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
		local winpick = require("config.winpick")

		local ok_parsers, ts_parsers = pcall(require, "nvim-treesitter.parsers")
		if ok_parsers then
			local ts_lang = vim.treesitter and vim.treesitter.language
			if not ts_parsers.ft_to_lang and ts_lang and ts_lang.get_lang then
				ts_parsers.ft_to_lang = ts_lang.get_lang
			end
			if not ts_parsers.get_parser and vim.treesitter and vim.treesitter.get_parser then
				ts_parsers.get_parser = vim.treesitter.get_parser
			end
		end
		local ok_configs, ts_configs = pcall(require, "nvim-treesitter.configs")
		if ok_configs then
			if not ts_configs.is_enabled then
				ts_configs.is_enabled = function(_, lang, bufnr)
					if not lang or lang == "" then
						return false
					end
					return pcall(vim.treesitter.get_parser, bufnr, lang)
				end
			end
			if not ts_configs.get_module then
				ts_configs.get_module = function()
					return { additional_vim_regex_highlighting = false }
				end
			end
		end
		local select_edit = winpick.telescope_select("edit")
		local select_split = winpick.telescope_select("split")
		local select_vsplit = winpick.telescope_select("vsplit")
		local select_tab = winpick.telescope_select("tab")

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
						["<CR>"] = select_edit,
						["<C-x>"] = select_split,
						["<C-v>"] = select_vsplit,
						["<C-t>"] = select_tab,
						["<C-e>"] = actions.cycle_history_next,
						["<C-i>"] = actions.cycle_history_prev,
					},
					n = {
						["<CR>"] = select_edit,
						["<C-x>"] = select_split,
						["<C-v>"] = select_vsplit,
						["<C-t>"] = select_tab,
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
				-- find_files = {
				-- 	follow = true,
				-- 	file_ignore_patterns = { "node_modules", ".git", ".venv" },
				-- 	hidden = true,
				-- 	previewer = true, -- enable preview
				-- },
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
