local keymap = vim.keymap

keymap.set("c", "<C-BS>", "<C-w>", { noremap = true })

-- Move up
keymap.set("n", "<Up>", "k", { noremap = true, silent = true })
keymap.set("v", "<Up>", "k", { noremap = true, silent = true })
keymap.set("x", "<Up>", "k", { noremap = true, silent = true })
keymap.set("n", "k", "<nop>", { silent = true })
keymap.set("v", "k", "<nop>", { silent = true })
keymap.set("x", "k", "<nop>", { silent = true })

-- Move down
keymap.set("n", "<Down>", "j", { noremap = true, silent = true })
keymap.set("v", "<Down>", "j", { noremap = true, silent = true })
keymap.set("x", "<Down>", "j", { noremap = true, silent = true })
keymap.set("n", "j", "<nop>", { silent = true })
keymap.set("v", "j", "<nop>", { silent = true })
keymap.set("x", "j", "<nop>", { silent = true })

-- Move left
keymap.set("n", "<Left>", "h", { noremap = true, silent = true })
keymap.set("v", "<Left>", "h", { noremap = true, silent = true })
keymap.set("x", "<Left>", "h", { noremap = true, silent = true })
keymap.set("n", "h", "<nop>", { silent = true })
keymap.set("v", "h", "<nop>", { silent = true })
keymap.set("x", "h", "<nop>", { silent = true })

-- Move right
keymap.set("n", "<Right>", "l", { noremap = true, silent = true })
keymap.set("v", "<Right>", "l", { noremap = true, silent = true })
keymap.set("x", "<Right>", "l", { noremap = true, silent = true })
keymap.set("n", "l", "<nop>", { silent = true })
keymap.set("v", "l", "<nop>", { silent = true })
keymap.set("x", "l", "<nop>", { silent = true })

-- Go to the end of the line
keymap.set("n", "<End>", "g_", { noremap = true, silent = true })
keymap.set("v", "<End>", "g_", { noremap = true, silent = true })
keymap.set("x", "<End>", "g_", { noremap = true, silent = true })
-- Go to the beginning of the line
keymap.set("n", "<Home>", "^", { noremap = true, silent = true })
keymap.set("v", "<Home>", "^", { noremap = true, silent = true })
keymap.set("x", "<Home>", "^", { noremap = true, silent = true })

-- Go to the next word
keymap.set("n", "<C-Right>", "w", { noremap = true, silent = true })
keymap.set("v", "<C-Right>", "w", { noremap = true, silent = true })
keymap.set("x", "<C-Right>", "w", { noremap = true, silent = true })
-- Go to the previous word
keymap.set("n", "<C-Left>", "b", { noremap = true, silent = true })
keymap.set("v", "<C-Left>", "b", { noremap = true, silent = true })
keymap.set("x", "<C-Left>", "b", { noremap = true, silent = true })

-- Remap split navigation with leader key
keymap.set("n", "<C-n>", "<C-w>h", { desc = "Focus left", silent = true })
keymap.set("n", "<C-e>", "<C-w>j", { desc = "Focus down", silent = true })
keymap.set("n", "<C-i>", "<C-w>k", { desc = "Focus up", silent = true })
keymap.set("n", "<C-o>", "<C-w>l", { desc = "Focus right", silent = true })

-- Move one page up/down
keymap.set("n", "<M-i>", "<C-b>", { silent = true })
keymap.set("n", "<M-e>", "<C-f>", { silent = true })

-- Close
keymap.set("n", "<C-q><C-q>", "<cmd>bd<CR>", { noremap = true, silent = true, desc = "Close Buffer" })
keymap.set("n", "<C-q><C-w>", "<cmd>q<CR>", { noremap = true, silent = true, desc = "Close Window" })
keymap.set("n", "<C-q><C-a>", "<cmd>qa<CR>", { noremap = true, silent = true, desc = "Close All Buffers" })

-- Save buffer
keymap.set("n", "<C-w><C-w>", "<cmd>w<CR>", { desc = "Save Buffer" })
keymap.set("n", "<C-w><C-a>", "<cmd>wa<CR>", { desc = "Save All Buffers" })

-- Switch Source/Header
keymap.set("n", "<leader>o", "<cmd>LspClangdSwitchSourceHeader<CR>", { desc = "Switch source/header" })

-- LLM Context to Clipboard
keymap.set("n", "<leader>ai", "<cmd>CtxIngest<CR>", { desc = "Copy LLM context to clipboard" })

-- Delete word backward
keymap.set("i", "<C-BS>", "<C-W>", { noremap = true, silent = true })
keymap.set("t", "<C-BS>", "<C-w>", { noremap = true, silent = true })

-- Hot Reload Config
keymap.set(
	"n",
	"<leader>rc",
	"<cmd>luafile ~/.config/nvim/init.lua<CR>",
	{ desc = "Reload config", noremap = true, silent = true }
)

-- Move to next diagnostic
keymap.set("n", "<leader>dn", vim.diagnostic.goto_next, { desc = "Go to next diagnostic" })
-- Move to previous diagnostic
keymap.set("n", "<leader>dN", vim.diagnostic.goto_prev, { desc = "Go to previous diagnostic" })

keymap.set("n", "<C-=>", "<C-w>=", { desc = "Equalize window sizes" })

-- Lazy
keymap.set("n", "<leader>ll", "<cmd>Lazy<CR>", { desc = "Open Lazy" })
keymap.set("n", "<leader>lu", "<cmd>Lazy update<CR>", { desc = "Update plugins" })
keymap.set("n", "<leader>li", "<cmd>Lazy install<CR>", { desc = "Install plugins" })
