local uv = vim.loop

local M = {}

local function json_encode(value)
	if vim.json and vim.json.encode then
		return vim.json.encode(value)
	end
	return vim.fn.json_encode(value)
end

local function json_decode(value)
	if vim.json and vim.json.decode then
		return vim.json.decode(value)
	end
	return vim.fn.json_decode(value)
end

function M.load(cache_path, expected_version)
	local stat = uv.fs_stat(cache_path)
	if not stat or stat.type ~= "file" then
		return nil
	end

	local ok, lines = pcall(vim.fn.readfile, cache_path)
	if not ok or not lines or #lines == 0 then
		return nil
	end

	local decoded_ok, decoded = pcall(json_decode, table.concat(lines, "\n"))
	if not decoded_ok or type(decoded) ~= "table" then
		return nil
	end

	if decoded.version ~= expected_version then
		return nil
	end

	if type(decoded.items) ~= "table" or vim.tbl_isempty(decoded.items) then
		return nil
	end

	return decoded.items
end

function M.save(cache_path, version, items)
	local payload = {
		version = version,
		generated = os.time(),
		items = items,
	}

	local ok, encoded = pcall(json_encode, payload)
	if not ok or type(encoded) ~= "string" or encoded == "" then
		return
	end

	pcall(vim.fn.writefile, { encoded }, cache_path)
end

return M

