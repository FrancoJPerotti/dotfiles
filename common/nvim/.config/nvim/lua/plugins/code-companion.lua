return {
	"olimorris/codecompanion.nvim",
	opts = {
		display = {
			action_palette = {
				width = 95,
				height = 10,
				prompt = "Prompt ", -- Prompt used for interactive LLM calls
				provider = "snacks", -- Can be "default", "telescope", "fzf_lua", "mini_pick" or "snacks". If not specified, the plugin will autodetect installed providers.
				opts = {
					show_preset_actions = true, -- Show the preset actions in the action palette?
					show_preset_prompts = true, -- Show the preset prompt library in the action palette?
					title = "CodeCompanion actions", -- The title of the action palette
				},
			},
			chat = {
				window = {
					width = 0.3,
				},
			},
		},
		interactions = {
			inline = {
				keymaps = {
					accept_change = {
						modes = { n = "ga" },
						description = "Accept the suggested change",
					},
					reject_change = {
						modes = { n = "gr" },
						opts = { nowait = true },
						description = "Reject the suggested change",
					},
				},
			},
		},
		prompt_library = {
			markdown = {
				dirs = {
					vim.fn.stdpath("config") .. "/prompts/codecompanion",
				},
			},
		},
	},
	dependencies = {
		"nvim-lua/plenary.nvim",
		"nvim-treesitter/nvim-treesitter",
		"j-hui/fidget.nvim",
		"folke/snacks.nvim",
		config = true,
	},

	vim.keymap.set({ "n", "v" }, "<leader>aa", "<cmd>CodeCompanionActions<cr>", { noremap = true, silent = true }),
	vim.keymap.set({ "n", "v" }, "<leader>ac", "<cmd>CodeCompanionChat Toggle<cr>", { noremap = true, silent = true }),
	vim.keymap.set("v", "<leader>ac", "<cmd>CodeCompanionChat Add<cr>", { noremap = true, silent = true }),
	vim.keymap.set("v", "<leader>ae", ":CodeCompanion<cr>", { noremap = true, silent = false }),
	vim.keymap.set("n", "<leader>ae", "V:CodeCompanion<cr>", { noremap = true, silent = false }),
	vim.keymap.set("n", "<leader>gc", "<cmd>CodeCompanion /commit_message<cr>", { noremap = true, silent = true }),

	-- Expand 'cc' into 'CodeCompanion' in the command line
	vim.cmd([[cab cc CodeCompanion]]),
}
