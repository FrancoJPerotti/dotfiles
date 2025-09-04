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
					show_default_actions = true, -- Show the default actions in the action palette?
					show_default_prompt_library = true, -- Show the default prompt library in the action palette?
					title = "CodeCompanion actions", -- The title of the action palette
				},
			},
			chat = {
				window = {
					width = 0.3,
				},
			},
		},
		strategies = {
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
			["Commit Message"] = {
				strategy = "inline",
				description = "Generate a commit message",
				opts = {
					short_name = "commit_message",
					auto_submit = true,
					placement = "before",
					is_slash_command = true,
				},
				prompts = {
					{
						role = "user",
						content = function()
							return string.format(
								[[You are an expert at following the Conventional Commit specification. Given the git diff listed below, please generate a commit message for me:

` ` `diff
%s
` ` `

When unsure about the module names to use in the commit message, you can refer to the last 20 commit messages in this repository:

` ` `
%s
` ` `

Output only the commit message without any explanations and follow-up suggestions.
]],
								vim.fn.system("git diff --no-ext-diff --staged"),
								vim.fn.system('git log --pretty=format:"%s" -n 20')
							)
						end,
						opts = {
							contains_code = true,
						},
					},
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
