local Job = require("plenary.job")

local cache = require("telescope.project_finder.cache")
local picker = require("telescope.project_finder.picker")
local scan = require("telescope.project_finder.scan")
local util = require("telescope.project_finder.util")

local M = {}

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

local PROJECT_CACHE_VERSION = 1
local PROJECT_CACHE_PATH = vim.fn.stdpath("cache") .. "/telescope_project_finder_projects.json"

local AUTO_REFRESH = util.toboolean(vim.g.project_finder_auto_refresh, true)
local AUTO_REFRESH_INTERVAL_MS = tonumber(vim.g.project_finder_auto_refresh_interval_ms) or 120000
local AUTO_REFRESH_DEBOUNCE_MS = tonumber(vim.g.project_finder_auto_refresh_debounce_ms) or 500

local project_state = {
	cache = {},
	waiters = {},
	scanning = false,
	version = 0,
	job = nil,
}

local auto_refresh_state = {
	scheduled = false,
	last_request_ms = 0,
	timer = nil,
}

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

local function load_project_cache()
	local raw = cache.load(PROJECT_CACHE_PATH, PROJECT_CACHE_VERSION)
	if not raw or vim.tbl_isempty(raw) then
		return
	end

	local cleaned = scan.clean_candidates(raw, ignore_patterns)
	if vim.tbl_isempty(cleaned) then
		return
	end

	project_state.cache = cleaned
	project_state.version = project_state.version + 1
end

local function save_project_cache(list)
	cache.save(PROJECT_CACHE_PATH, PROJECT_CACHE_VERSION, list)
end

local function start_scan()
	local dirs = scan.get_searchable_dirs(search_dirs)
	if vim.tbl_isempty(dirs) then
		notify_waiters({}, false)
		return
	end

	local job_spec = scan.build_scan_job(dirs, ignore_patterns)
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

			local cleaned = scan.clean_candidates(handle:result(), ignore_patterns)
			local changed = util.lists_differ(project_state.cache, cleaned)
			if changed then
				project_state.cache = cleaned
				project_state.version = project_state.version + 1
				vim.schedule(function()
					save_project_cache(cleaned)
				end)
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

local function schedule_scan()
	if not AUTO_REFRESH then
		return
	end
	if AUTO_REFRESH_INTERVAL_MS <= 0 then
		return
	end
	if auto_refresh_state.scheduled then
		return
	end

	auto_refresh_state.scheduled = true
	vim.defer_fn(function()
		auto_refresh_state.scheduled = false

		if project_state.scanning then
			return
		end

		vim.loop.update_time()
		local now_ms = vim.loop.now()
		if auto_refresh_state.last_request_ms > 0 and (now_ms - auto_refresh_state.last_request_ms) < AUTO_REFRESH_INTERVAL_MS then
			return
		end

		auto_refresh_state.last_request_ms = now_ms
		request_scan()
	end, AUTO_REFRESH_DEBOUNCE_MS)
end

local function setup_auto_refresh()
	if not AUTO_REFRESH then
		return
	end

	vim.api.nvim_create_autocmd({ "FocusGained", "DirChanged" }, {
		callback = function()
			schedule_scan()
		end,
	})

	if AUTO_REFRESH_INTERVAL_MS > 0 then
		local timer = vim.loop.new_timer()
		auto_refresh_state.timer = timer
		timer:start(
			AUTO_REFRESH_INTERVAL_MS,
			AUTO_REFRESH_INTERVAL_MS,
			vim.schedule_wrap(function()
				schedule_scan()
			end)
		)

		vim.api.nvim_create_autocmd("VimLeavePre", {
			once = true,
			callback = function()
				if auto_refresh_state.timer then
					pcall(function()
						auto_refresh_state.timer:stop()
						auto_refresh_state.timer:close()
					end)
					auto_refresh_state.timer = nil
				end
			end,
		})
	end
end

function M.open()
	local opts = {
		refresh_after_open = true,
		request_scan = request_scan,
		prefetch_git_info_limit = tonumber(vim.g.project_finder_prefetch_git_info_limit) or 0,
	}

	if #project_state.cache == 0 then
		local msg = project_state.scanning and "Project scan in progress…" or "Scanning for git projects…"
		vim.notify(msg, vim.log.levels.INFO)
		picker.open({}, opts)
		return
	end

	picker.open(project_state.cache, opts)
end

function M.refresh()
	request_scan()
end

load_project_cache()

if vim.v.vim_did_enter == 1 then
	request_scan()
else
	vim.api.nvim_create_autocmd("VimEnter", {
		once = true,
		callback = function()
			request_scan()
		end,
	})
end

setup_auto_refresh()

return M
