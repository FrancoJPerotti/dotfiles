-- Space as leader
vim.g.mapleader = " "

local keymap = vim.keymap

-- Define mappings for command-line mode
keymap.set("c", "<Up>", [[wildmenumode() ? "\<left>" : "\<up>"]], { expr = true, noremap = true })
keymap.set("c", "<Down>", [[wildmenumode() ? "\<right>" : "\<down>"]], { expr = true, noremap = true })
keymap.set("c", "<Left>", [[wildmenumode() ? "\<up>" : "\<left>"]], { expr = true, noremap = true })
keymap.set("c", "<Right>", [[wildmenumode() ? " \<bs>\<C-Z>" : "\<right>"]], { expr = true, noremap = true })

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

-- Go to the next paragraph
keymap.set("n", "<S-Down>", "}", { noremap = true, silent = true })
keymap.set("v", "<S-Down>", "}", { noremap = true, silent = true })
keymap.set("x", "<S-Down>", "}", { noremap = true, silent = true })

-- Go to the previous paragraph
keymap.set("n", "<S-Up>", "{", { noremap = true, silent = true })
keymap.set("v", "<S-Up>", "{", { noremap = true, silent = true })
keymap.set("x", "<S-Up>", "{", { noremap = true, silent = true })

-- Move through buffers
keymap.set("n", "<C-l>", "<cmd>bprevious<CR>", { desc = "Previous buffer", silent = true })
keymap.set("n", "<C-ñ>", "<cmd>bnext<CR>", { desc = "Next buffer", silent = true })

-- Remap split navigation with leader key
keymap.set("n", "<C-n>", "<C-w>h", { desc = "Focus left", silent = true })
keymap.set("n", "<C-e>", "<C-w>j", { desc = "Focus down", silent = true })
keymap.set("n", "<C-i>", "<C-w>k", { desc = "Focus up", silent = true })
keymap.set("n", "<C-o>", "<C-w>l", { desc = "Focus right", silent = true })

-- Move one page up/down
keymap.set("n", "<M-i>", "<C-b>", { silent = true })
keymap.set("n", "<M-e>", "<C-f>", { silent = true })

-- Navigate wildmenu with arrow keys in command-line mode
keymap.set("c", "<Down>", "<C-n>", { noremap = true })
keymap.set("c", "<Up>", "<C-p>", { noremap = true })

-- Use <Right> to select a recommendation without executing it
keymap.set("c", "<Right>", 'pumvisible() ? "\\<C-y>" : "\\<Right>"', { noremap = true, expr = true, silent = true })

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
keymap.set("n", "<leader>ac", "<cmd>CtxIngest<CR>", { desc = "Copy LLM context to clipboard" })

-- Delete word backward
keymap.set("i", "<C-BS>", "<C-W>", { noremap = true, silent = true })

-- Hot Reload Config
keymap.set(
	"n",
	"<leader>rc",
	"<cmd>luafile ~/.config/nvim/init.lua<CR>",
	{ desc = "Reload config", noremap = true, silent = true }
)

keymap.set("n", "?", "<cmd>:lua vim.diagnostic.open_float()<CR>", { desc = "Open diagnostics" })

keymap.set("t", "<C-BS>", "<C-w>", { noremap = true, silent = true })
