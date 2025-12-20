return {
	"nvim-treesitter/nvim-treesitter",
	branch = "main",
	lazy = false,
	build = ":TSUpdate",
	dependencies = {
		{
			"windwp/nvim-ts-autotag",
			config = function()
				require("nvim-ts-autotag").setup()
			end,
		},
	},
		config = function()
			local ts = require("nvim-treesitter")

			ts.setup({
				install_dir = vim.fn.stdpath("data") .. "/site",
			})

			pcall(function()
				vim.treesitter.language.register("json", { "jsonc" })
				vim.treesitter.language.register("yaml", { "yml" })
			end)

			ts.install({
				"bash",
				"c",
				"css",
			"gitignore",
			"graphql",
			"html",
			"java",
			"javascript",
			"json",
			"lua",
			"markdown",
			"markdown_inline",
			"prisma",
			"python",
			"query",
			"rust",
			"svelte",
			"tsx",
			"typescript",
			"vim",
			"vimdoc",
			"yaml",
			})

			local group = vim.api.nvim_create_augroup("UserTreesitter", { clear = true })
			vim.api.nvim_create_autocmd("FileType", {
				group = group,
				pattern = "*",
				callback = function(args)
					if vim.bo[args.buf].filetype == "dockerfile" then
						return
					end
					pcall(vim.treesitter.start, args.buf)
					pcall(function()
						vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
					end)
			end,
		})
	end,
}
