return {
	"saghen/blink.cmp",
	dependencies = { "rafamadriz/friendly-snippets", "fang2hou/blink-copilot" },
	version = "1.*",
	opts = {
		keymap = { preset = "default", ["<CR>"] = { "accept", "fallback" } },

		appearance = { nerd_font_variant = "mono" },

		-- merge your completion options into a single table (you had two keys before; the last one wins)
		completion = {
			documentation = { auto_show = true },
			accept = { auto_brackets = { enabled = true } },
		},

		sources = {
			default = { "copilot", "lsp", "path", "snippets", "buffer" },
			providers = {
				copilot = {
					name = "copilot",
					module = "blink-copilot",
					score_offset = 100,
					async = true,
				},
			},
		},

		fuzzy = { implementation = "prefer_rust_with_warning" },

		enabled = function()
			local disabled = { "NvimTree", "DressingInput" }
			return vim.g.blink_autocomplete_enabled ~= false and not vim.tbl_contains(disabled, vim.bo.filetype)
		end,
	},

	opts_extend = { "sources.default" },
	init = function()
		vim.api.nvim_create_user_command("BlinkToggle", function()
			vim.g.blink_autocomplete_enabled = vim.g.blink_autocomplete_enabled == false
			vim.notify("Blink autocomplete: " .. (vim.g.blink_autocomplete_enabled and "ON" or "OFF"))
		end, { desc = "Toggle Blink completion", force = true })
	end,
}
