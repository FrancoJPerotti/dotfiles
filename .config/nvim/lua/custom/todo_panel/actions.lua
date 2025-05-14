local api = vim.api

local M = {}

local task_prefix = "- [ ] "
local indent_unit = "  "
local task_pattern = "^(%s*)(%-%s*%[%s?[x%s]?%].*)" -- Matches indent, then "- [ ] ..." or "- [x] ..."
local incomplete_marker_literal = "[ ] "
local complete_marker_literal = "[x] "
local incomplete_marker_pattern = "%[ %] " -- Escaped for gsub
local complete_marker_pattern = "%[x%] " -- Escaped for gsub

-- Inserts a new task line below the current line
function M.add_task_below(bufnr, winid)
	local lnum = api.nvim_win_get_cursor(winid)[1]
	local line_content = api.nvim_buf_get_lines(bufnr, lnum - 1, lnum, false)[1] or ""
	local indent = line_content:match("^%s*") or ""
	local ok, err = pcall(api.nvim_buf_set_lines, bufnr, lnum, lnum, false, { indent .. task_prefix })
	if ok then
		pcall(api.nvim_win_set_cursor, winid, { lnum + 1, #indent + #task_prefix })
	else
		vim.notify("Error adding task: " .. tostring(err), vim.log.levels.ERROR)
	end
end

-- Opens a new task line below the current line and enters insert mode
function M.open_task_below(bufnr, winid)
	local lnum = api.nvim_win_get_cursor(winid)[1]
	local line_content = api.nvim_buf_get_lines(bufnr, lnum - 1, lnum, false)[1] or ""
	local indent = line_content:match("^%s*") or ""
	local ok1 = pcall(api.nvim_buf_set_lines, bufnr, lnum, lnum, false, { "" })
	if not ok1 then
		vim.notify("Error inserting blank line", vim.log.levels.ERROR)
		return
	end
	local ok2 = pcall(api.nvim_buf_set_lines, bufnr, lnum, lnum + 1, false, { indent .. task_prefix })
	if not ok2 then
		vim.notify("Error setting task line", vim.log.levels.ERROR)
		return
	end
	pcall(api.nvim_win_set_cursor, winid, { lnum + 1, #indent + #task_prefix })
	vim.cmd.startinsert()
end

-- Opens a new task line above the current line and enters insert mode
function M.open_task_above(bufnr, winid)
	local lnum = api.nvim_win_get_cursor(winid)[1]
	local line_content = api.nvim_buf_get_lines(bufnr, lnum - 1, lnum, false)[1] or ""
	local indent = line_content:match("^%s*") or ""
	local ok = pcall(api.nvim_buf_set_lines, bufnr, lnum - 1, lnum - 1, false, { indent .. task_prefix })
	if ok then
		pcall(api.nvim_win_set_cursor, winid, { lnum, #indent + #task_prefix })
		vim.cmd.startinsert()
	else
		vim.notify("Error opening task above", vim.log.levels.ERROR)
	end
end

-- Toggles the completion status of the task on the current line
function M.toggle_task(bufnr, winid)
	local lnum = api.nvim_win_get_cursor(winid)[1]
	local line_content = api.nvim_buf_get_lines(bufnr, lnum - 1, lnum, false)[1]
	if line_content == nil or vim.bo[bufnr].readonly or not vim.bo[bufnr].modifiable then
		return
	end

	local modified = false
	local new_line = nil

	if line_content:find(incomplete_marker_literal, 1, true) then
		new_line = line_content:gsub(incomplete_marker_pattern, complete_marker_literal, 1)
		if new_line ~= line_content then
			modified = true
		end
	elseif line_content:find(complete_marker_literal, 1, true) then
		new_line = line_content:gsub(complete_marker_pattern, incomplete_marker_literal, 1)
		if new_line ~= line_content then
			modified = true
		end
	end

	if modified and new_line then
		pcall(api.nvim_buf_set_lines, bufnr, lnum - 1, lnum, false, { new_line })
		pcall(api.nvim_win_set_cursor, winid, { lnum, 0 })
	end
end

-- Indents the current task line
function M.indent_task(bufnr, winid)
	local lnum, col = unpack(api.nvim_win_get_cursor(winid))
	local line_content = api.nvim_buf_get_lines(bufnr, lnum - 1, lnum, false)[1]
	if line_content and line_content:match(task_pattern) then
		local new_line = indent_unit .. line_content
		pcall(api.nvim_buf_set_lines, bufnr, lnum - 1, lnum, false, { new_line })
		-- Adjust cursor if in insert mode, otherwise just move to new indent start
		if vim.fn.mode():find("i") then
			pcall(api.nvim_win_set_cursor, winid, { lnum, col + #indent_unit })
		else
			pcall(api.nvim_win_set_cursor, winid, { lnum, #indent_unit })
		end
		return true -- Indicate we handled it
	end
	return false -- Indicate we didn't handle it (allow fallback)
end

-- Unindents the current task line
function M.unindent_task(bufnr, winid)
	local lnum, col = unpack(api.nvim_win_get_cursor(winid))
	local line_content = api.nvim_buf_get_lines(bufnr, lnum - 1, lnum, false)[1]
	if line_content and line_content:match(task_pattern) and line_content:sub(1, #indent_unit) == indent_unit then
		local new_line = line_content:sub(#indent_unit + 1)
		pcall(api.nvim_buf_set_lines, bufnr, lnum - 1, lnum, false, { new_line })
		-- Adjust cursor
		local new_col = math.max(0, col - #indent_unit)
		pcall(api.nvim_win_set_cursor, winid, { lnum, new_col })
	end
	-- No fallback needed for unindent in insert mode usually
end

return M
