return {
	"williamboman/mason.nvim",
	dependencies = {
		"WhoIsSethDaniel/mason-tool-installer.nvim",
	},
	config = function()
		-- import mason
		local mason = require("mason")

		-- import mason-tool-installer
		local mason_tool_installer = require("mason-tool-installer")

		-- enable mason and configure icons
		mason.setup({
			providers = {
				"mason.providers.registry-api",
				"mason.providers.client",
			},
			ui = {
				icons = {
					package_installed = "✓",
					package_pending = "➜",
					package_uninstalled = "✗",
				},
			},
		})

		mason_tool_installer.setup({
			ensure_installed = {
				"clangd",
				"bash-language-server",
				"lua-language-server",
				"pyright",
				"rust-analyzer",
				"kotlin-language-server",
				"jdtls",
				-- formatters
				"stylua",
				"black",
				"isort",
				"prettier",
				"shfmt",
				"ktfmt",
				"tex-fmt",
				"xmlformatter",
				"texlab",
				"google-java-format",
				-- linters
				"eslint_d",
				"pylint",
				"checkstyle",
			},
		})
	end,
}
