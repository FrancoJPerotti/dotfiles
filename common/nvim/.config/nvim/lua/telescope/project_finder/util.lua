local uv = vim.loop

local M = {}

local HAS_NVIM_STRWIDTH = type(vim.api.nvim_strwidth) == "function"

function M.strwidth(text)
	if HAS_NVIM_STRWIDTH then
		return vim.api.nvim_strwidth(text or "")
	end
	return vim.fn.strdisplaywidth(text or "")
end

function M.trim(str)
	if not str then
		return ""
	end
	return (str:gsub("^%s+", ""):gsub("%s+$", ""))
end

function M.truncate_text(text, max)
	if not text then
		return ""
	end
	if #text <= max then
		return text
	end
	return text:sub(1, max - 1) .. "…"
end

function M.toboolean(value, default)
	if value == nil then
		return default
	end
	if value == false or value == 0 then
		return false
	end
	if type(value) == "string" then
		local lowered = value:lower()
		if lowered == "0" or lowered == "false" or lowered == "no" or lowered == "off" then
			return false
		end
	end
	return true
end

function M.basename(path)
	return path:match("([^/]+)$") or path
end

local HOME_DIR = (uv.os_homedir and uv.os_homedir()) or vim.env.HOME

function M.tildeify(path)
	if not HOME_DIR or HOME_DIR == "" then
		return path
	end
	if path == HOME_DIR then
		return "~"
	end
	local home_prefix = HOME_DIR
	if home_prefix:sub(-1) ~= "/" then
		home_prefix = home_prefix .. "/"
	end
	if path:sub(1, #home_prefix) == home_prefix then
		return "~/" .. path:sub(#home_prefix + 1)
	end
	return path
end

function M.shorten_display(display, max_len)
	local columns = vim.o.columns > 0 and vim.o.columns or 80
	max_len = max_len or math.max(40, columns - 60)

	if M.strwidth(display) <= max_len then
		return display
	end

	if max_len <= 1 then
		return vim.fn.strcharpart(display, 0, max_len)
	end

	-- Preserve the tail of the path so you can still identify the project.
	local chars = vim.fn.strchars(display)
	local tail_len = math.max(1, max_len - 1)
	local start = math.max(0, chars - tail_len)
	local tail = vim.fn.strcharpart(display, start, tail_len)
	return "…" .. tail
end

function M.shorten_path(path, max_len)
	return M.shorten_display(M.tildeify(path), max_len)
end

function M.lists_differ(a, b)
	if #a ~= #b then
		return true
	end

	for idx = 1, #a do
		if a[idx] ~= b[idx] then
			return true
		end
	end

	return false
end

return M

