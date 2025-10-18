-- 1) Make Compose files use the filetype the server expects
vim.filetype.add({
	pattern = {
		["docker%-compose%.ya?ml"] = "yaml.docker-compose",
		["compose%.ya?ml"] = "yaml.docker-compose",
	},
})

-- 2) Diagnostics: tidy but not noisy
vim.diagnostic.config({
	virtual_lines = true,
	underline = true,
	update_in_insert = false,
	severity_sort = true,
	float = { border = "rounded", source = true },
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

-- 3) Define configs BEFORE enabling (so settings actually apply)
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
			runtime = { version = "LuaJIT", path = { "lua/?.lua", "lua/?/init.lua" } },
			workspace = { checkThirdParty = false, library = { vim.env.VIMRUNTIME } },
		})
	end,
	settings = { Lua = {} },
})

-- Optional: register empty configs (not required, but silences "no config" warnings in some setups)
vim.lsp.config("dockerls", {})
vim.lsp.config("docker_compose_language_service", {})
vim.lsp.config("bashls", {})

-- 4) Enable servers with the CORRECT names (no dupes)
vim.lsp.enable({
	"clangd",
	"lua_ls",
	"pyright",
	"rust_analyzer",
	"bashls", -- was: bash-language-server (wrong)
	"dockerls",
	"docker_compose_language_service",
})
