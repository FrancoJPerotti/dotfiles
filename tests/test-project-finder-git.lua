-- Run from the repository root: nvim --headless -u NONE -l tests/test-project-finder-git.lua
vim.opt.rtp:prepend(vim.fn.getcwd() .. '/common/nvim/.config/nvim')
vim.opt.rtp:append(vim.fn.expand('~/.local/share/nvim/lazy/plenary.nvim'))
vim.g.project_finder_git_concurrency = 1
vim.g.project_finder_git_cache_ttl_ms = 1000
local tmp = vim.fn.tempname()
vim.fn.mkdir(tmp, 'p')
local function git_cmd(path, ...)
 local args = { 'git', '-C', path }
 vim.list_extend(args, {...})
 local result = vim.system(args, {text=true}):wait()
 assert(result.code == 0, result.stderr)
 return vim.trim(result.stdout or '')
end
local function run()
 local paths = {}
 for i = 1, 8 do
  local path = tmp .. '/repo-' .. i
  vim.fn.mkdir(path, 'p')
  git_cmd(path, 'init', '-q', '-b', 'main')
  paths[i] = path
 end
 git_cmd(paths[1], '-c', 'user.name=Test', '-c', 'user.email=test@example.invalid', 'commit', '-q', '--allow-empty', '-m', 'test')
 local Job = require('plenary.job')
 local original_start = Job.start
 local starts = 0
 local started_paths = {}
 Job.start = function(self, ...)
  starts = starts + 1
  started_paths[self.args[2]] = true
  return original_start(self, ...)
 end
 local git = require('telescope.project_finder.git')
 local updates = 0
 git.set_refresh_callback(function(changed)
  assert(next(changed), 'Empty update')
  updates = updates + 1
 end)
 for _, path in ipairs(paths) do git.request(path) end
 git.set_refresh_callback(nil)
 assert(vim.wait(3000, function() return git.get_cached(paths[1]) ~= nil end), 'Running Git query did not finish')
 vim.wait(200, function() return false end)
 assert(starts == 2, 'Closed picker started pending queries: ' .. starts)
 assert(updates == 0, 'Closed picker got an update')
 local info = git.get_cached(paths[1])
 assert(info.branch == 'main' and info.status_icon == '○', 'Wrong initial Git metadata')
 git.request(paths[1])
 assert(starts == 2, 'Fresh cache launched another process')
 git.set_refresh_callback(function() updates = updates + 1 end)
 git.request(paths[2])
 assert(vim.wait(3000, function() return git.get_cached(paths[2]) ~= nil end), 'Canceled queue entry could not be requested again')
 vim.wait(200, function() return false end)
 git.request_visible({paths[3], paths[4], paths[5]})
 git.request_visible({paths[8]})
 assert(vim.wait(3000, function() return git.get_cached(paths[8]) ~= nil end), 'New visible projects were not prioritized')
 assert(not started_paths[paths[4]] and not started_paths[paths[5]], 'Obsolete hidden queries were started')
 vim.wait(200, function() return false end)
 local before = updates
 vim.fn.writefile({'untracked'}, paths[1] .. '/new-file')
 vim.wait(1100, function() return false end)
 git.request(paths[1])
 assert(git.get_cached(paths[1]) == info, 'Expired metadata vanished before its replacement was ready')
 assert(vim.wait(3000, function() return git.get_cached(paths[1]).status_icon == '●' end), 'Expired cache did not update')
 assert(vim.wait(1000, function() return updates > before end), 'Changed metadata did not notify picker')
 git.set_refresh_callback(nil)
 Job.start = original_start
 print('OK: real Git metadata, fresh cache reuse, expired cache refresh, canceled queue, reopened picker.')
end
local ok, err = xpcall(run, debug.traceback)
vim.fn.delete(tmp, 'rf')
if not ok then error(err) end
vim.cmd('qa!')
