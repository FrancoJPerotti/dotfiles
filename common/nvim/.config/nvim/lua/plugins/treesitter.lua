return {
	"nvim-treesitter/nvim-treesitter",
	branch = "main",
	lazy = false,
	build = function()
		if vim.fn.executable("tree-sitter") == 1 then
			vim.cmd.TSUpdate()
		end
	end,
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

		if vim.fn.executable("tree-sitter") == 1 then
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
		end

		local group = vim.api.nvim_create_augroup("UserTreesitter", { clear = true })
		vim.api.nvim_create_autocmd("FileType", {
			group = group,
			pattern = "*",
			callback = function(args)
				local filetype = vim.bo[args.buf].filetype
				if filetype == "dockerfile" or filetype == "" or vim.bo[args.buf].buftype ~= "" then
					return
				end

				local lang = vim.treesitter.language.get_lang(filetype) or filetype
				if not pcall(vim.treesitter.language.inspect, lang) then
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
