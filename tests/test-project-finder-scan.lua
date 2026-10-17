-- Run from the repository root: nvim --headless -u NONE -l tests/test-project-finder-scan.lua
vim.opt.rtp:prepend(vim.fn.getcwd() .. '/common/nvim/.config/nvim')
local scan = require('telescope.project_finder.scan')
local tmp = vim.fn.tempname()
local function run()
 vim.fn.mkdir(tmp .. '/normal/.git/objects/internal/.git', 'p')
 vim.fn.mkdir(tmp .. '/normal/nested/.git', 'p')
 vim.fn.mkdir(tmp .. '/ignored/.git', 'p')
 vim.fn.mkdir(tmp .. '/worktree', 'p')
 vim.fn.writefile({'gitdir: /somewhere'}, tmp .. '/worktree/.git')
 local expected = {tmp .. '/normal', tmp .. '/normal/nested', tmp .. '/worktree'}
 local function check(spec)
  local args = {spec.command}
  vim.list_extend(args, spec.args)
  local result = vim.system(args, {text=true}):wait()
  assert(result.code == 0, result.stderr)
  local candidates = scan.clean_candidates(vim.split(vim.trim(result.stdout), '\n'), {'ignored'})
  assert(vim.deep_equal(candidates, expected), vim.inspect(candidates))
 end
 check(scan.build_scan_job({tmp}, {'ignored'}))
 local executable = vim.fn.executable
 vim.fn.executable = function(name) return name == 'fd' and 0 or executable(name) end
 local fallback = scan.build_scan_job({tmp}, {'ignored'})
 vim.fn.executable = executable
 check(fallback)
 print('OK: fd/find parity; nested repos, worktrees, ignores, pruning Git internals.')
end
local ok, err = xpcall(run, debug.traceback)
vim.fn.delete(tmp, 'rf')
if not ok then error(err) end
vim.cmd('qa!')
