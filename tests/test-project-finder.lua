-- Run from the repository root: nvim --headless -u NONE -l tests/test-project-finder.lua
local root = vim.fn.getcwd()
vim.opt.rtp:prepend(root .. '/common/nvim/.config/nvim')
for _, name in ipairs({ 'plenary.nvim', 'telescope.nvim', 'nvim-web-devicons' }) do
 vim.opt.rtp:append(vim.fn.expand('~/.local/share/nvim/lazy/' .. name))
end
vim.o.columns = 160
vim.o.lines = 55
local refresh, scan_callback
local calls = 0
local metadata = {}
local visible_batches = {}
package.loaded['telescope.project_finder.git'] = {
 get_cached = function(path) return metadata[path] end,
 get_sync = function() error('Blocking git lookup called') end,
 request = function() calls = calls + 1 end,
 request_visible = function(paths) visible_batches[#visible_batches + 1] = paths end,
 set_refresh_callback = function(cb) refresh = cb end,
}
local picker_module = require('telescope.project_finder.picker')
local paths = {}
for i=1,200 do paths[i] = '/tmp/project-' .. i end
picker_module.open(paths, {
 prefetch_git_info_limit = 10,
 request_scan = function(cb) scan_callback = cb end,
})
assert(vim.wait(2000, function()
 local p = require('telescope.actions.state').get_current_picker(vim.api.nvim_get_current_buf())
 return p.manager and p.manager:num_results() > 100
end), 'Picker did not populate')
local picker = require('telescope.actions.state').get_current_picker(vim.api.nvim_get_current_buf())
assert(picker:get_selection().value == paths[1], 'Initial selection did not skip the header')
local finder = picker.finder
picker:set_selection(picker:get_row(8))
local selection = picker:get_selection()
assert(selection and selection.value, 'No project selected')
local processed = picker.stats.processed
local refresh_calls = 0
local original_refresh = picker.refresh
picker.refresh = function(self, ...)
 refresh_calls = refresh_calls + 1
 return original_refresh(self, ...)
end
metadata[selection.value] = {
 branch = 'updated-branch', last_commit = 'just now', status_icon = '●',
}
refresh({[selection.value] = true})
vim.wait(300, function() return false end)
assert(refresh_calls == 0, 'Git update reran fuzzy matching')
assert(picker.stats.processed == processed, 'Git update reprocessed projects')
assert(selection.branch == 'updated-branch', 'Visible Git metadata did not update')
assert(picker.finder == finder, 'Git update rebuilt the finder')
assert(picker:get_selection() == selection, 'Git update reset selection')
assert(calls == 10, 'Transient display rows launched Git queries')
assert(#visible_batches > 0, 'Visible Git queries were not scheduled')
assert(#visible_batches[#visible_batches] < #paths, 'Hidden projects were queried')
picker:set_selection(picker:get_row(60))
local scrolled = picker:get_selection()
vim.wait(200, function() return false end)
assert(vim.tbl_contains(visible_batches[#visible_batches], scrolled.value), 'Scrolled project did not get a Git query')
local function assert_best_match()
 local best
 for entry in picker.manager:iter() do
  if not entry.is_header then best = entry; break end
 end
 assert(best and picker:get_selection() == best, 'Typing did not select the best project match')
end
picker:reset_prompt('project-19')
vim.wait(200, function() return false end)
assert_best_match()
picker:reset_prompt('project')
vim.wait(200, function() return false end)
assert_best_match()
picker:reset_prompt('/tmp/project-199')
assert(vim.wait(2000, function()
 local batch = visible_batches[#visible_batches]
 return #batch == 1 and batch[1] == '/tmp/project-199'
end), 'Queries did not follow filtered results')
assert_best_match()
picker:reset_prompt('no-such-project-xyz')
assert(vim.wait(2000, function() return #visible_batches[#visible_batches] == 0 end), 'Empty results retained pending Git queries')
require('telescope.actions').close(picker.prompt_bufnr)
assert(refresh == nil, 'Closing the picker did not clear Git callback')
scan_callback({'/tmp/new-project'}, true)
print('OK: 200 projects; deferred visible queries; scrolling and filtering; no refilter on Git updates; selection preserved; close cleanup.')
vim.cmd('qa!')
