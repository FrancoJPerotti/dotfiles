local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local action_state = require("telescope.actions.state")
local actions = require("telescope.actions")
local themes = require("telescope.themes")
local devicons = require("nvim-web-devicons")
local Job = require("plenary.job")
local uv = vim.loop

local M = {}
local HEADER_SENTINEL = { __project_finder_header = true }

local picker_layout = {
	width = 0.85,
	height = 0.55,
}

local function strwidth(text)
	return vim.fn.strdisplaywidth(text or "")
end

local search_dirs = {
	"~",
	-- "~/dev",
	-- "~/work",
}

local ignore_patterns = {
	"Library",
	".local",
	".cache",
	".gemini",
	".cargo",
	".npm",
	"node_modules",
}

local git_info_cache = {}
local project_state = {
	cache = {},
	waiters = {},
	scanning = false,
	version = 0,
	job = nil,
}

local PREFETCH_GIT_INFO_LIMIT = 80

local run_git_command_lines
local run_git_command
local get_git_info

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

local function get_searchable_dirs()
	local dirs = {}
	local seen = {}

	for _, dir in ipairs(search_dirs) do
		local expanded = expand_dir(dir)
		if expanded and not seen[expanded] then
			table.insert(dirs, expanded)
			seen[expanded] = true
		end
	end

	return dirs
end

local function should_ignore_path(path)
	for _, pattern in ipairs(ignore_patterns) do
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

	local normalized = vim.fn.fnamemodify(path, ":p")
	normalized = normalized:gsub("/%.git/?$", "")
	normalized = normalized:gsub("/+$", "")

	if normalized == "" then
		return nil
	end

	return normalized
end

local function clean_candidates(raw_list)
	if not raw_list or vim.tbl_isempty(raw_list) then
		return {}
	end

	table.sort(raw_list)

	local clean_list = {}
	local seen = {}
	local last_valid_path = ""

	for _, raw in ipairs(raw_list) do
		local candidate = normalize_candidate(raw)
		if candidate and not seen[candidate] and not should_ignore_path(candidate) then
			if last_valid_path == "" or not vim.startswith(candidate, last_valid_path .. "/") then
				table.insert(clean_list, candidate)
				seen[candidate] = true
				last_valid_path = candidate
			end
		end
	end

	return clean_list
end

local function lists_differ(a, b)
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

local function notify_waiters(list, changed)
	if #project_state.waiters == 0 then
		return
	end

	local waiters = project_state.waiters
	project_state.waiters = {}

	for _, cb in ipairs(waiters) do
		if type(cb) == "function" then
			vim.schedule(function()
				local ok, err = pcall(cb, list, changed)
				if not ok then
					vim.notify("Project finder callback failed: " .. err, vim.log.levels.ERROR)
				end
			end)
		end
	end
end

local function build_scan_job(dirs)
	if vim.fn.executable("fd") == 1 then
		local args = { "-H", "-a", "--no-ignore", "-t", "d", "-t", "f", "^\\.git$" }
		for _, pattern in ipairs(ignore_patterns) do
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
	for _, dir in ipairs(dirs) do
		table.insert(args, dir)
	end
	vim.list_extend(args, { "-name", ".git" })
	for _, pattern in ipairs(ignore_patterns) do
		vim.list_extend(args, { "-not", "-path", string.format("*/%s/*", pattern) })
	end

	return {
		command = "find",
		args = args,
	}
end

local function start_scan()
	local dirs = get_searchable_dirs()
	if vim.tbl_isempty(dirs) then
		notify_waiters({}, false)
		return
	end

	local job_spec = build_scan_job(dirs)
	if not job_spec then
		notify_waiters(project_state.cache, false)
		return
	end

	project_state.scanning = true
	local ok, job = pcall(Job.new, Job, {
		command = job_spec.command,
		args = job_spec.args,
		on_exit = vim.schedule_wrap(function(handle, return_val)
			project_state.scanning = false
			project_state.job = nil

			if return_val ~= 0 then
				local stderr = table.concat(handle:stderr_result() or {}, "\n")
				if stderr ~= "" then
					vim.notify("Project scan failed:\n" .. stderr, vim.log.levels.WARN)
				end
				notify_waiters(project_state.cache, false)
				return
			end

			local cleaned = clean_candidates(handle:result())
			local changed = lists_differ(project_state.cache, cleaned)
			if changed then
				project_state.cache = cleaned
				project_state.version = project_state.version + 1
			end
			notify_waiters(project_state.cache, changed)
		end),
	})

	if not ok then
		project_state.scanning = false
		project_state.job = nil
		vim.notify("Unable to start project scan: " .. job, vim.log.levels.ERROR)
		notify_waiters(project_state.cache, false)
		return
	end

	project_state.job = job
	job:start()
end

local function request_scan(cb)
	if cb then
		table.insert(project_state.waiters, cb)
	end

	if project_state.scanning then
		return
	end

	start_scan()
end

local function trim(str)
	if not str then
		return ""
	end
	return (str:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function truncate_text(text, max)
	if not text then
		return ""
	end
	if #text <= max then
		return text
	end
	return text:sub(1, max - 1) .. "…"
end

local function shorten_path(path, max_len)
	local display = vim.fn.fnamemodify(path, ":~")
	local columns = vim.o.columns > 0 and vim.o.columns or 80
	max_len = max_len or math.max(40, columns - 60)

	if strwidth(display) <= max_len then
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

local function format_branch_text(branch, ahead, behind)
	local label = branch ~= "" and branch or "detached"
	local parts = { label }
	if ahead and ahead > 0 then
		table.insert(parts, string.format("⇡%d", ahead))
	end
	if behind and behind > 0 then
		table.insert(parts, string.format("⇣%d", behind))
	end
	return table.concat(parts, " ")
end

local function get_branch_highlight(branch, dirty)
	if branch == "detached" then
		return "DiagnosticWarn"
	end
	if dirty then
		return "GitSignsChange"
	end
	if branch == "main" or branch == "master" or branch == "trunk" or branch == "develop" then
		return "GitSignsAdd"
	end
	return "TelescopeResultsNumber"
end

local function get_commit_highlight(epoch)
	if not epoch or epoch == 0 then
		return "DiagnosticHint"
	end

	local age = os.time() - epoch
	if age < 2 * 24 * 60 * 60 then
		return "GitSignsAdd"
	end
	if age < 14 * 24 * 60 * 60 then
		return "GitSignsChange"
	end
	if age > 90 * 24 * 60 * 60 then
		return "DiagnosticWarn"
	end
	return "TelescopeResultsComment"
end

local function get_status_indicator(info)
	if info.dirty then
		return "●", "DiagnosticError"
	end
	return "○", "Comment"
end

-- Returns the MAXIMUM allowed picker width (e.g. 85% of screen)
local function get_max_picker_width()
	local columns = vim.o.columns > 0 and vim.o.columns or 120
	local width = picker_layout.width or 0.8
	return math.floor(columns * width)
end

local function compute_column_meta(projects)
	local icon = 2
	local status = 2
	local lengths = {
		name = 0,
		branch = 0,
		commit = 0,
		path = 0,
	}

	local prefetched = 0
	for _, path in ipairs(projects) do
		local name = vim.fn.fnamemodify(path, ":t")
		lengths.name = math.max(lengths.name, strwidth(name))

		local path_display = vim.fn.fnamemodify(path, ":~")
		lengths.path = math.max(lengths.path, strwidth(path_display))

		local info = git_info_cache[path]
		if not info and prefetched < PREFETCH_GIT_INFO_LIMIT then
			info = get_git_info(path)
			prefetched = prefetched + 1
		end
		if info then
			lengths.branch = math.max(lengths.branch, strwidth(info.branch))
			lengths.commit = math.max(lengths.commit, strwidth(info.last_commit))
		end
	end

	lengths.name = math.min(math.max(lengths.name + 2, 14), 48)
	lengths.branch = math.min(math.max(lengths.branch + 2, 20), 60)
	lengths.commit = math.min(math.max(lengths.commit + 2, 10), 24)
	lengths.path = math.max(lengths.path + 2, 24)

	-- Check against max available space
	local max_available = math.max(70, get_max_picker_width() - 8)
	local total = icon + status + lengths.name + lengths.branch + lengths.commit + lengths.path

	if total > max_available then
		local overflow = total - max_available
		local function reduce(field, min_value)
			if overflow <= 0 then
				return
			end
			local reducible = lengths[field] - min_value
			if reducible <= 0 then
				return
			end
			local delta = math.min(reducible, overflow)
			lengths[field] = lengths[field] - delta
			overflow = overflow - delta
		end

		reduce("path", 18)
		reduce("branch", 18)
		reduce("name", 14)
		reduce("commit", 10)
	end

	return {
		icon = icon,
		status = status,
		name = lengths.name,
		branch = lengths.branch,
		commit = lengths.commit,
		path = lengths.path,
	}
end

local function parse_git_status(path)
	local lines = run_git_command_lines(path, { "status", "-sb", "--ignore-submodules=dirty" })
	if not lines then
		return {
			branch = "detached",
			ahead = 0,
			behind = 0,
			dirty = false,
		}
	end

	local header = lines[1] or ""
	local branch_segment = header:gsub("^## ", "")
	local branch = "detached"

	if branch_segment ~= "" then
		if branch_segment:match("HEAD") then
			branch = "detached"
		else
			local ellipsis = branch_segment:find("%.%.%.")
			if ellipsis then
				branch = branch_segment:sub(1, ellipsis - 1)
			else
				local space_pos = branch_segment:find(" ")
				if space_pos then
					branch = branch_segment:sub(1, space_pos - 1)
				else
					branch = branch_segment
				end
			end
			branch = trim(branch)
		end
	end

	local ahead = tonumber(header:match("ahead (%d+)")) or 0
	local behind = tonumber(header:match("behind (%d+)")) or 0
	local dirty = #lines > 1

	return {
		branch = branch ~= "" and branch or "detached",
		ahead = ahead,
		behind = behind,
		dirty = dirty,
	}
end

local function read_commit_meta(path)
	local commit_line = run_git_command(path, { "log", "-1", "--format=%cr|%ct" })
	if not commit_line or commit_line == "" then
		return "no commits", 0
	end

	local rel, epoch = commit_line:match("^(.*)|(%d+)$")
	rel = trim(rel or commit_line)
	return rel, tonumber(epoch) or 0
end

run_git_command_lines = function(path, args)
	local cmd = { "git", "-C", path }
	vim.list_extend(cmd, args)

	local ok, result = pcall(vim.fn.systemlist, cmd)
	if not ok or vim.v.shell_error ~= 0 then
		return nil
	end

	return result
end

run_git_command = function(path, args)
	local result = run_git_command_lines(path, args)
	if not result or not result[1] then
		return nil
	end
	return trim(result[1])
end

get_git_info = function(path)
	if git_info_cache[path] then
		return git_info_cache[path]
	end

	local status = parse_git_status(path)
	local last_commit, commit_epoch = read_commit_meta(path)

	local branch_text = format_branch_text(status.branch, status.ahead, status.behind)
	local branch_hl = get_branch_highlight(status.branch, status.dirty)
	local commit_hl = get_commit_highlight(commit_epoch)
	local status_icon, status_hl = get_status_indicator(status)

	local info = {
		branch = branch_text,
		last_commit = last_commit,
		commit_epoch = commit_epoch,
		branch_hl = branch_hl,
		commit_hl = commit_hl,
		status_icon = status_icon,
		status_hl = status_hl,
		name_hl = status.dirty and "DiagnosticWarn" or nil,
	}

	git_info_cache[path] = info
	return info
end

local function perform_project_switch(target_path)
	local lib = require("auto-session")

	vim.notify("Saving session...", vim.log.levels.INFO)
	vim.cmd("AutoSession save")
	vim.cmd("silent! %bd!")
	vim.cmd("cd " .. vim.fn.fnameescape(target_path))

	vim.schedule(function()
		lib.restore_session()
		vim.notify("Switched to: " .. target_path, vim.log.levels.INFO)
	end)
end

local function ensure_clean_buffers()
	local bufs = vim.api.nvim_list_bufs()
	for _, bufnr in ipairs(bufs) do
		if vim.api.nvim_buf_is_loaded(bufnr) and vim.api.nvim_buf_get_option(bufnr, "modified") then
			local bname = vim.api.nvim_buf_get_name(bufnr)
			if bname == "" then
				vim.api.nvim_set_current_buf(bufnr)
				local new_name = vim.fn.input("⚠️  Unnamed buffer modified. Save as (Enter to Cancel): ")
				if new_name == "" then
					vim.notify("Switch aborted.", vim.log.levels.WARN)
					return false
				end
				local filepath = vim.fn.getcwd() .. "/" .. new_name
				vim.api.nvim_buf_set_name(bufnr, filepath)
				vim.cmd("write")
			end
		end
	end

	local ok_save, err = pcall(vim.cmd, "wall")
	if not ok_save then
		vim.notify("⚠️  Save failed. Switch aborted.\n" .. (err or ""), vim.log.levels.ERROR)
		return false
	end

	return true
end

local function make_entry_display(columns)
	local entry_display = require("telescope.pickers.entry_display")
	local displayer = entry_display.create({
		separator = " ",
		items = {
			{ width = columns.icon },
			{ width = columns.status },
			{ width = columns.name },
			{ width = columns.branch },
			{ width = columns.commit },
			{ width = columns.path },
		},
	})

	return function(entry)
		return displayer({
			{ entry.icon, entry.icon_hl or "TelescopeResultsIdentifier" },
			{ entry.status_icon or "○", entry.status_hl or "Comment" },
			{ entry.name, entry.name_hl or "TelescopeResultsNormal" },
			{ entry.branch, entry.branch_hl or "TelescopeResultsNumber" },
			{ entry.last_commit, entry.commit_hl or "TelescopeResultsComment" },
			{ entry.path_display, entry.path_hl or "Comment" },
		})
	end
end

local function make_header_entry(display_fn)
	local header_hl = "TelescopeResultsTitle"
	local header_columns = {
		icon = "Ic",
		icon_hl = header_hl,
		status_icon = "St",
		status_hl = header_hl,
		name = "Project",
		name_hl = header_hl,
		branch = "Branch",
		branch_hl = header_hl,
		last_commit = "Last Commit",
		commit_hl = header_hl,
		path_display = "Path",
		path_hl = header_hl,
	}

	return {
		value = nil,
		ordinal = "icon status project branch commit path",
		is_header = true,
		display = function()
			return display_fn(header_columns)
		end,
	}
end

local function make_entry_maker(display_fn, col_meta)
	local header_entry = make_header_entry(display_fn)
	local branch_width = math.max(12, (col_meta and col_meta.branch or 20) - 2)
	local commit_width = math.max(10, (col_meta and col_meta.commit or 14) - 2)
	local path_width = math.max(18, (col_meta and col_meta.path or get_max_picker_width()) - 2)

	return function(item)
		if item == HEADER_SENTINEL then
			return header_entry
		end

		local path = item
		local name = vim.fn.fnamemodify(path, ":t")
		local icon = devicons.get_icon(name, "isDirectory", { default = true }) or ""

		local entry = {
			value = path,
			ordinal = table.concat({ name, path }, " "),
			name = name,
			path_display = shorten_path(path, path_width),
			icon = icon,
			branch = "…",
			last_commit = "…",
			status_icon = "○",
			status_hl = "Comment",
			branch_hl = "TelescopeResultsNumber",
			commit_hl = "TelescopeResultsComment",
			name_hl = nil,
			path_hl = "Comment",
			_git_loaded = false,
		}

		entry.display = function()
			if not entry._git_loaded then
				entry._git_loaded = true
				local git_info = get_git_info(path)
				entry.branch = truncate_text(git_info.branch, branch_width)
				entry.last_commit = truncate_text(git_info.last_commit, commit_width)
				entry.branch_hl = git_info.branch_hl
				entry.commit_hl = git_info.commit_hl
				entry.status_icon = git_info.status_icon
				entry.status_hl = git_info.status_hl
				entry.name_hl = git_info.name_hl or entry.name_hl
				entry.ordinal = table.concat({ name, git_info.branch, path }, " ")
			end
			return display_fn(entry)
		end

		return entry
	end
end

local function open_picker(projects, opts)
	opts = opts or {}
	local refresh_after_open = opts.refresh_after_open ~= false
	local items = projects or {}

	-- Calculate dynamic width based on the content
	local init_col_meta = compute_column_meta(items)
	local total_content_width = init_col_meta.icon
		+ init_col_meta.status
		+ init_col_meta.name
		+ init_col_meta.branch
		+ init_col_meta.commit
		+ init_col_meta.path
	-- 5 separators (spaces) + padding (approx 6 for borders/margins)
	local dynamic_width = total_content_width + 5 + 6
	local max_width = get_max_picker_width()

	-- Ensure minimal width for title and max width
	dynamic_width = math.max(40, math.min(dynamic_width, max_width))

	local function build_finder(list)
		local col_meta = compute_column_meta(list)
		local display_fn = make_entry_display(col_meta)
		local results = { HEADER_SENTINEL }
		for _, path in ipairs(list) do
			table.insert(results, path)
		end
		return finders.new_table({
			results = results,
			entry_maker = make_entry_maker(display_fn, col_meta),
		})
	end

	local picker
	picker = pickers.new(
		themes.get_dropdown({
			prompt_title = " Git Projects",
			previewer = false,
			bottom_pane = false,
			layout_config = {
				height = picker_layout.height,
				width = dynamic_width, -- Use calculated width here
			},
		}),
		{
			finder = build_finder(items),
			sorter = conf.generic_sorter({}),
			attach_mappings = function(prompt_bufnr, _)
				actions.select_default:replace(function()
					local selection = action_state.get_selected_entry()
					if not selection or selection.is_header then
						return
					end

					actions.close(prompt_bufnr)

					if not ensure_clean_buffers() then
						return
					end

					perform_project_switch(selection.value)
				end)
				return true
			end,
		}
	)

	picker:find()

	if not refresh_after_open then
		return
	end

	request_scan(function(new_list, changed)
		if not changed then
			return
		end

		local ok = pcall(function()
			picker:refresh(build_finder(new_list), { reset_prompt = false })
		end)

		if not ok then
			-- Picker was likely closed; no action needed.
			return
		end
	end)
end

function M.open()
	if #project_state.cache == 0 then
		request_scan(function(list)
			open_picker(list, { refresh_after_open = false })
		end)

		local msg = project_state.scanning and "Project scan in progress…" or "Scanning for git projects…"
		vim.notify(msg, vim.log.levels.INFO)
		return
	end

	open_picker(project_state.cache, { refresh_after_open = true })
end

function M.refresh()
	request_scan()
end

request_scan()

return M
