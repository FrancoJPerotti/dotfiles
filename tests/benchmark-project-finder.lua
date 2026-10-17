-- Run from the repo root with the installed Telescope plugins and an existing project cache:
-- nvim --headless -u NONE -l tests/benchmark-project-finder.lua
-- PF_RTP can point at a saved config directory for before/after comparisons.
-- Timings cover the picker and filtering, excluding startup and the background HOME scan.
local rtp = vim.env.PF_RTP or (vim.fn.getcwd() .. '/common/nvim/.config/nvim')
vim.opt.rtp:prepend(rtp)
for _, name in ipairs({'plenary.nvim','telescope.nvim','nvim-web-devicons','telescope-fzf-native.nvim'}) do
 vim.opt.rtp:append(vim.fn.expand('~/.local/share/nvim/lazy/' .. name))
end
vim.o.columns=160
vim.o.lines=55
require('telescope').setup({})
require('telescope').load_extension('fzf')
local projects=vim.json.decode(table.concat(vim.fn.readfile(vim.fn.stdpath('cache') .. '/telescope_project_finder_projects.json'),'\n')).items
local Job=require('plenary.job')
local start=Job.start
local jobs=0
local queued={}
Job.start=function(self,...)
 jobs=jobs+1
 queued[self.args[2] or 'unknown']=true
 return start(self,...)
end
local module=require('telescope.project_finder.picker')
local ts=vim.uv.hrtime()
module.open(projects,{refresh_after_open=false})
local picker=require('telescope.actions.state').get_current_picker(vim.api.nvim_get_current_buf())
assert(vim.wait(3000,function()return picker.manager and picker.manager:num_results()>0 end))
local opening=(vim.uv.hrtime()-ts)/1e6
local completed=0
picker:register_completion_callback(function() completed=completed+1 end)
local queries={'d','do','dot','dotf','dotfi','dotfiles'}
local times={}
for _,q in ipairs(queries) do
 ts=vim.uv.hrtime()
 local before=completed
 picker:reset_prompt(q)
 assert(vim.wait(3000,function()return completed>before end,1),'Filtering did not complete')
 times[#times+1]=(vim.uv.hrtime()-ts)/1e6
 vim.wait(15,function()return false end)
end
vim.wait(700,function()return false end)
local paths=0
for _ in pairs(queued)do paths=paths+1 end
print(vim.json.encode({open_ms=opening, typing_ms=times,git_processes=jobs,queried_projects=paths,projects=#projects}))
require('telescope.actions').close(picker.prompt_bufnr)
vim.wait(300,function()return false end)
vim.cmd('qa!')
