local uv = vim.loop

local M = {}

local HOME_DIR = (uv.os_homedir and uv.os_homedir()) or vim.env.HOME

local function expand_dir(path)
	local expanded = vim.fn.expand(path)
	if expanded == "" then
		return nil
	end

	local stat = uv.fs_stat(expanded)
	if not stat or stat.type ~= "directory" then
		return nil
	end

	return vim.fn.fnamemodify(expanded, ":p")
end

function M.get_searchable_dirs(search_dirs)
	local dirs = {}
	local seen = {}

	for _, dir in ipairs(search_dirs or {}) do
		local expanded = expand_dir(dir)
		if expanded and not seen[expanded] then
			table.insert(dirs, expanded)
			seen[expanded] = true
		end
	end

	return dirs
end

local function should_ignore_path(path, ignore_patterns)
	for _, pattern in ipairs(ignore_patterns or {}) do
		if path:find(pattern, 1, true) then
			return true
		end
	end
	return false
end

local function normalize_candidate(path)
	if not path or path == "" then
		return nil
	end

	local normalized = path:gsub("/%.git/?$", ""):gsub("/+$", "")
	if HOME_DIR and normalized:sub(1, 2) == "~/" then
		normalized = HOME_DIR .. normalized:sub(2)
	end
	if normalized:sub(1, 1) ~= "/" then
		local ok, abs = pcall(vim.fn.fnamemodify, normalized, ":p")
		if ok and abs and abs ~= "" then
			normalized = abs
		end
	end

	if normalized == "" then
		return nil
	end

	return normalized
end

function M.clean_candidates(raw_list, ignore_patterns)
	if not raw_list or vim.tbl_isempty(raw_list) then
		return {}
	end

	table.sort(raw_list)

	local clean_list = {}
	local seen = {}
	local last_valid_path = ""

	for _, raw in ipairs(raw_list) do
		local candidate = normalize_candidate(raw)
		if candidate and not seen[candidate] and not should_ignore_path(candidate, ignore_patterns) then
			if last_valid_path == "" or not vim.startswith(candidate, last_valid_path .. "/") then
				table.insert(clean_list, candidate)
				seen[candidate] = true
				last_valid_path = candidate
			end
		end
	end

	return clean_list
end

function M.build_scan_job(dirs, ignore_patterns)
	if vim.fn.executable("fd") == 1 then
		-- Include both .git directories and files (worktrees/submodules).
		local args = { "-H", "-a", "--no-ignore", "--glob", ".git", "-t", "d", "-t", "f" }
		for _, pattern in ipairs(ignore_patterns or {}) do
			table.insert(args, "--exclude")
			table.insert(args, pattern)
		end
		vim.list_extend(args, dirs)

		return {
			command = "fd",
			args = args,
		}
	end

	local args = {}
	for _, dir in ipairs(dirs or {}) do
		table.insert(args, dir)
	end

	-- Prune ignored directories to avoid expensive descents; keeps output equivalent to excludes.
	if not vim.tbl_isempty(ignore_patterns or {}) then
		table.insert(args, "(")
		for idx, pattern in ipairs(ignore_patterns) do
			if idx > 1 then
				table.insert(args, "-o")
			end
			table.insert(args, "-name")
			table.insert(args, pattern)
		end
		table.insert(args, ")")
		table.insert(args, "-prune")
		table.insert(args, "-o")
	end

	vim.list_extend(args, { "-name", ".git", "-print" })

	return {
		command = "find",
		args = args,
	}
end

return M
