local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local action_state = require("telescope.actions.state")
local actions = require("telescope.actions")
local themes = require("telescope.themes")
local devicons = require("nvim-web-devicons")

local git = require("telescope.project_finder.git")
local util = require("telescope.project_finder.util")

local M = {}

local HEADER_SENTINEL = { __project_finder_header = true }

local picker_layout = {
	width = 0.85,
	height = 0.55,
}

local path_display_cache = {}

local function get_max_picker_width()
	local columns = vim.o.columns > 0 and vim.o.columns or 120
	local width = picker_layout.width or 0.8
	return math.floor(columns * width)
end

local function compute_column_meta(projects, opts)
	opts = opts or {}

	local icon = 2
	local status = 2
	local lengths = {
		name = 0,
		branch = 0,
		commit = 0,
		path = 0,
	}

	local prefetched = 0
	local prefetch_limit = tonumber(opts.prefetch_git_info_limit) or 0

	for _, path in ipairs(projects) do
		local cached = path_display_cache[path]
		if not cached then
			local name = util.basename(path)
			local display = util.tildeify(path)
			cached = {
				name = name,
				name_width = util.strwidth(name),
				display = display,
				display_width = util.strwidth(display),
			}
			path_display_cache[path] = cached
		end

		lengths.name = math.max(lengths.name, cached.name_width)
		lengths.path = math.max(lengths.path, cached.display_width)

		local info = git.get_cached(path)
		if not info and prefetched < prefetch_limit then
			info = git.get_sync(path)
			prefetched = prefetched + 1
		end
		if info then
			lengths.branch = math.max(lengths.branch, util.strwidth(info.branch))
			lengths.commit = math.max(lengths.commit, util.strwidth(info.last_commit))
		end
	end

	lengths.name = math.min(math.max(lengths.name + 2, 14), 48)
	lengths.branch = math.min(math.max(lengths.branch + 2, 20), 60)
	lengths.commit = math.min(math.max(lengths.commit + 2, 10), 24)
	lengths.path = math.max(lengths.path + 2, 24)

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
		icon = "",
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
		local cached = path_display_cache[path]
		if not cached then
			local name = util.basename(path)
			local display = util.tildeify(path)
			cached = {
				name = name,
				name_width = util.strwidth(name),
				display = display,
				display_width = util.strwidth(display),
			}
			path_display_cache[path] = cached
		end

		local name = cached.name
		local icon = devicons.get_icon("git", nil, { default = true }) or ""

		local entry = {
			value = path,
			ordinal = table.concat({ name, path }, " "),
			name = name,
			path_display = util.shorten_display(cached.display, path_width),
			icon = icon,
			branch = "…",
			last_commit = "…",
			status_icon = "○",
			status_hl = "Comment",
			branch_hl = "TelescopeResultsNumber",
			commit_hl = "TelescopeResultsComment",
			name_hl = nil,
			path_hl = "Comment",
			_git_applied = false,
		}

		entry.display = function()
			local info = git.get_cached(path)
			if info then
				if not entry._git_applied then
					entry._git_applied = true
					entry.branch = util.truncate_text(info.branch, branch_width)
					entry.last_commit = util.truncate_text(info.last_commit, commit_width)
					entry.branch_hl = info.branch_hl
					entry.commit_hl = info.commit_hl
					entry.status_icon = info.status_icon
					entry.status_hl = info.status_hl
					entry.name_hl = info.name_hl or entry.name_hl
					entry.ordinal = table.concat({ name, info.branch, path }, " ")
				end
			else
				git.request(path)
			end
			return display_fn(entry)
		end

		return entry
	end
end

function M.open(projects, opts)
	opts = opts or {}
	local refresh_after_open = opts.refresh_after_open ~= false
	local request_scan = opts.request_scan
	local items = projects or {}

	local init_col_meta = compute_column_meta(items, opts)
	local total_content_width = init_col_meta.icon
		+ init_col_meta.status
		+ init_col_meta.name
		+ init_col_meta.branch
		+ init_col_meta.commit
		+ init_col_meta.path
	local dynamic_width = total_content_width + 5 + 6
	local max_width = get_max_picker_width()
	dynamic_width = math.max(40, math.min(dynamic_width, max_width))

	local current_items = items
	local current_col_meta = init_col_meta

	local function build_finder(list, col_meta_override)
		local col_meta = col_meta_override or compute_column_meta(list, opts)
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
				width = dynamic_width,
			},
		}),
		{
			finder = build_finder(items, init_col_meta),
			sorter = conf.generic_sorter({}),
			attach_mappings = function(prompt_bufnr, _)
				actions.select_default:replace(function()
					local selection = action_state.get_selected_entry()
					if not selection or selection.is_header then
						return
					end

					actions.close(prompt_bufnr)
					git.set_refresh_callback(nil)

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

	git.set_refresh_callback(function()
		if not picker or not picker.prompt_bufnr or not vim.api.nvim_buf_is_valid(picker.prompt_bufnr) then
			git.set_refresh_callback(nil)
			return
		end
		pcall(function()
			picker:refresh(build_finder(current_items, current_col_meta), { reset_prompt = false })
		end)
	end)

	if not refresh_after_open or type(request_scan) ~= "function" then
		return
	end

	request_scan(function(new_list, changed)
		if not changed then
			return
		end

		current_items = new_list
		current_col_meta = compute_column_meta(new_list, opts)

		local ok = pcall(function()
			picker:refresh(build_finder(current_items, current_col_meta), { reset_prompt = false })
		end)

		if not ok then
			return
		end
	end)
end

return M
