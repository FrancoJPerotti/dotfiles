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

vim.lsp.config("lua_ls", {
	on_init = function(client)
		if client.workspace_folders then
			local path = client.workspace_folders[1].name
			if
				path ~= vim.fn.stdpath("config")
				and (vim.uv.fs_stat(path .. "/.luarc.json") or vim.uv.fs_stat(path .. "/.luarc.jsonc"))
			then
				return
			end
		end

		client.config.settings.Lua = vim.tbl_deep_extend("force", client.config.settings.Lua, {
			runtime = {
				-- Tell the language server which version of Lua you're using (most
				-- likely LuaJIT in the case of Neovim)
				version = "LuaJIT",
				-- Tell the language server how to find Lua modules same way as Neovim
				-- (see `:h lua-module-load`)
				path = {
					"lua/?.lua",
					"lua/?/init.lua",
				},
			},
			-- Make the server aware of Neovim runtime files
			workspace = {
				checkThirdParty = false,
				library = {
					vim.env.VIMRUNTIME,
					-- Depending on the usage, you might want to add additional paths
					-- here.
					-- '${3rd}/luv/library'
					-- '${3rd}/busted/library'
				},
				-- Or pull in all of 'runtimepath'.
				-- NOTE: this is a lot slower and will cause issues when working on
				-- your own configuration.
				-- See https://github.com/neovim/nvim-lspconfig/issues/3189
				-- library = {
				--   vim.api.nvim_get_runtime_file('', true),
				-- }
			},
		})
	end,
	settings = {
		Lua = {},
	},
})

vim.lsp.enable(servers)
