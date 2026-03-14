vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

-- Autocmds
require("config.autocmds")

-- Options
require("config.options")

-- Keymaps
require("config.keymaps")

-- Custom Commands
require("config.custom-commands")

-- Neovide
require("config.neovide")

-- Lazy
require("core.lazy")

-- LSP
require("core.lsp")

vim.cmd(
	[[command! TidyCurrent execute "cexpr system('clang-tidy -p build/lint/build/Debug ' ..shellescape(expand('%:p')))" | copen]]
)
