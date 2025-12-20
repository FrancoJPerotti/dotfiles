local Job = require("plenary.job")
local util = require("telescope.project_finder.util")

local M = {}

local INCLUDE_UNTRACKED = vim.g.project_finder_include_untracked

local state = {
	cache = {},
	inflight = {},
	queue = {},
	qhead = 1,
	qtail = 0,
	running = 0,
	max = tonumber(vim.g.project_finder_git_concurrency) or 6,
	refresh_cb = nil,
	refresh_scheduled = false,
}

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

local function parse_git_status_lines(lines)
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
			branch = util.trim(branch)
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

local function read_commit_meta_from_line(commit_line)
	if not commit_line or commit_line == "" then
		return "no commits", 0
	end

	local rel, epoch = commit_line:match("^(.*)|(%d+)$")
	rel = util.trim(rel or commit_line)
	return rel, tonumber(epoch) or 0
end

local function make_info(status, last_commit, commit_epoch)
	local branch_text = format_branch_text(status.branch, status.ahead, status.behind)
	local branch_hl = get_branch_highlight(status.branch, status.dirty)
	local commit_hl = get_commit_highlight(commit_epoch)
	local status_icon, status_hl = get_status_indicator(status)

	return {
		branch = branch_text,
		last_commit = last_commit,
		commit_epoch = commit_epoch,
		branch_hl = branch_hl,
		commit_hl = commit_hl,
		status_icon = status_icon,
		status_hl = status_hl,
		name_hl = status.dirty and "DiagnosticWarn" or nil,
	}
end

local function schedule_git_refresh()
	if state.refresh_scheduled then
		return
	end
	state.refresh_scheduled = true

	vim.defer_fn(function()
		state.refresh_scheduled = false
		if type(state.refresh_cb) == "function" then
			pcall(state.refresh_cb)
		end
	end, 60)
end

local function enqueue(path)
	if state.cache[path] or state.inflight[path] then
		return
	end
	state.inflight[path] = true
	state.qtail = state.qtail + 1
	state.queue[state.qtail] = path
end

local function dequeue()
	if state.qhead > state.qtail then
		return nil
	end
	local path = state.queue[state.qhead]
	state.queue[state.qhead] = nil
	state.qhead = state.qhead + 1
	return path
end

local function drain_queue()
	while state.running < state.max do
		local path = dequeue()
		if not path then
			return
		end

		state.running = state.running + 1

		local function finish()
			state.inflight[path] = nil
			state.running = math.max(0, state.running - 1)
			drain_queue()
		end

		local untracked = util.toboolean(INCLUDE_UNTRACKED, true)
		local status_args = { "-C", path, "status", "-sb", "--ignore-submodules=dirty" }
		if not untracked then
			table.insert(status_args, "--untracked-files=no")
		end

		local ok_status, status_job = pcall(Job.new, Job, {
			command = "git",
			args = status_args,
			env = { GIT_OPTIONAL_LOCKS = "0" },
			on_exit = vim.schedule_wrap(function(handle, return_val)
				if return_val ~= 0 then
					state.cache[path] = make_info({ branch = "detached", ahead = 0, behind = 0, dirty = false }, "no commits", 0)
					schedule_git_refresh()
					finish()
					return
				end

				local status = parse_git_status_lines(handle:result())

				local ok_log, log_job = pcall(Job.new, Job, {
					command = "git",
					args = { "-C", path, "log", "-1", "--format=%cr|%ct" },
					env = { GIT_OPTIONAL_LOCKS = "0" },
					on_exit = vim.schedule_wrap(function(log_handle, log_val)
						local last_commit, commit_epoch = "no commits", 0
						if log_val == 0 then
							last_commit, commit_epoch = read_commit_meta_from_line(util.trim((log_handle:result() or {})[1] or ""))
						end

						state.cache[path] = make_info(status, last_commit, commit_epoch)
						schedule_git_refresh()
						finish()
					end),
				})

				if not ok_log then
					finish()
					return
				end

				log_job:start()
			end),
		})

		if not ok_status then
			finish()
		else
			status_job:start()
		end
	end
end

local function run_git_command_lines(path, args)
	local cmd = { "git", "-C", path }
	vim.list_extend(cmd, args)

	local ok, result = pcall(vim.fn.systemlist, cmd)
	if not ok or vim.v.shell_error ~= 0 then
		return nil
	end

	return result
end

local function run_git_command(path, args)
	local result = run_git_command_lines(path, args)
	if not result or not result[1] then
		return nil
	end
	return util.trim(result[1])
end

function M.get_cached(path)
	return state.cache[path]
end

function M.get_sync(path)
	if state.cache[path] then
		return state.cache[path]
	end

	local untracked = util.toboolean(INCLUDE_UNTRACKED, true)
	local status_args = { "status", "-sb", "--ignore-submodules=dirty" }
	if not untracked then
		table.insert(status_args, "--untracked-files=no")
	end

	local status_lines = run_git_command_lines(path, status_args)
	local status = parse_git_status_lines(status_lines)
	local commit_line = run_git_command(path, { "log", "-1", "--format=%cr|%ct" })
	local last_commit, commit_epoch = read_commit_meta_from_line(commit_line)

	local info = make_info(status, last_commit, commit_epoch)
	state.cache[path] = info
	return info
end

function M.request(path)
	enqueue(path)
	drain_queue()
end

function M.set_refresh_callback(cb)
	state.refresh_cb = cb
end

return M
