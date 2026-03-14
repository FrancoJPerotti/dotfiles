local M = {}

local function has_parser(lang, bufnr)
	if not lang or lang == "" then
		return false
	end
	if not vim.treesitter or not vim.treesitter.get_parser then
		return false
	end
	return pcall(vim.treesitter.get_parser, bufnr, lang)
end

function M.is_enabled(_, lang, bufnr)
	return has_parser(lang, bufnr)
end

function M.get_module()
	return { additional_vim_regex_highlighting = false }
end

function M.setup(user_config)
	local ok, config = pcall(require, "nvim-treesitter.config")
	if ok and config.setup then
		return config.setup(user_config)
	end
end

return M
