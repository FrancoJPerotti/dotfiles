local mason_bin = vim.fs.normalize(vim.fn.stdpath("data") .. "/mason/bin")
if vim.fn.isdirectory(mason_bin) == 1 then
	local current_path = vim.env.PATH or ""
	if not current_path:find(mason_bin, 1, true) then
		vim.env.PATH = mason_bin .. ":" .. current_path
	end
end

local servers = {
	"clangd",
	"lua_ls",
	"pyright",
	"rust_analyzer",
	"bash-language-server",
	"kotlin_language_server",
	"texlab",
}

local function load_server_config(name)
	local config_path = vim.fs.joinpath(vim.fn.stdpath("config"), "lsp", ("%s.lua"):format(name))
	if vim.uv.fs_stat(config_path) then
		local ok, config = pcall(dofile, config_path)
		if not ok then
			vim.notify(("Failed to load LSP config for %s: %s"):format(name, config), vim.log.levels.ERROR)
			return
		end

		if type(config) == "table" then
			vim.lsp.config(name, config)
		end
	end
end

for _, server in ipairs(servers) do
	load_server_config(server)
end

vim.diagnostic.config({
	virtual_lines = true,
	-- virtual_text = true,
	underline = true,
	update_in_insert = false,
	severity_sort = true,
	float = {
		border = "rounded",
		source = true,
	},
	signs = {
		text = {
			[vim.diagnostic.severity.ERROR] = "󰅚 ",
			[vim.diagnostic.severity.WARN] = "󰀪 ",
			[vim.diagnostic.severity.INFO] = "󰋽 ",
			[vim.diagnostic.severity.HINT] = "󰌶 ",
		},
		numhl = {
			[vim.diagnostic.severity.ERROR] = "ErrorMsg",
			[vim.diagnostic.severity.WARN] = "WarningMsg",
		},
	},
})

vim.lsp.enable(servers)
