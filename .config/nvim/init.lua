-- Synchronize the color of nvim with terminal
vim.api.nvim_create_autocmd({ "UIEnter", "ColorScheme" }, {
  callback = function()
    local normal = vim.api.nvim_get_hl(0, { name = "Normal" })
    if not normal.bg then return end
    io.write(string.format("\027]11;#%06x\027\\", normal.bg))
  end,
})

vim.api.nvim_create_autocmd("UILeave", {
  callback = function() io.write("\027]111\027\\") end,
})

-- Basic Neovim configuration in Lua
vim.o.number = true              -- Show line numbers
vim.o.relativenumber = true      -- Show relative line numbers
vim.o.tabstop = 4               -- Set tab width
vim.o.shiftwidth = 4            -- Set shift width
vim.o.expandtab = true          -- Use spaces instead of tabs

-- Enable line wrapping
vim.o.wrap = true

-- Enable search highlighting
vim.o.hlsearch = true

-- Use Clipboard
vim.o.clipboard = "unnamedplus"

-- Space as leader
vim.g.mapleader = " "

-- Move up
vim.keymap.set('n', '<Up>', 'k', { noremap = true, silent = true })
vim.keymap.set('v', '<Up>', 'k', { noremap = true, silent = true })
vim.keymap.set('x', '<Up>', 'k', { noremap = true, silent = true })
-- Move down
vim.keymap.set('n', '<Down>', 'j', { noremap = true, silent = true })
vim.keymap.set('v', '<Down>', 'j', { noremap = true, silent = true })
vim.keymap.set('x', '<Down>', 'j', { noremap = true, silent = true })
-- Move left
vim.keymap.set('n', '<Left>', 'h', { noremap = true, silent = true })
vim.keymap.set('v', '<Left>', 'h', { noremap = true, silent = true })
vim.keymap.set('x', '<Left>', 'h', { noremap = true, silent = true })
-- Move right
vim.keymap.set('n', '<Right>', 'l', { noremap = true, silent = true })
vim.keymap.set('v', '<Right>', 'l', { noremap = true, silent = true })
vim.keymap.set('x', '<Right>', 'l', { noremap = true, silent = true })

-- Go to the end of the line
vim.keymap.set('n', '<End>', 'g_', { noremap = true, silent = true })
vim.keymap.set('v', '<End>', 'g_', { noremap = true, silent = true })
vim.keymap.set('x', '<End>', 'g_', { noremap = true, silent = true })
-- Go to the beginning of the line
vim.keymap.set('n', '<Home>', '^', { noremap = true, silent = true })
vim.keymap.set('v', '<Home>', '^', { noremap = true, silent = true })
vim.keymap.set('x', '<Home>', '^', { noremap = true, silent = true })

-- Go to the next word
vim.keymap.set('n', '<C-Right>', 'w', { noremap = true, silent = true })
vim.keymap.set('v', '<C-Right>', 'w', { noremap = true, silent = true })
vim.keymap.set('x', '<C-Right>', 'w', { noremap = true, silent = true })
-- Go to the previous word
vim.keymap.set('n', '<C-Left>', 'b', { noremap = true, silent = true })
vim.keymap.set('v', '<C-Left>', 'b', { noremap = true, silent = true })
vim.keymap.set('x', '<C-Left>', 'b', { noremap = true, silent = true })

-- Go to the end of the document
vim.keymap.set('n', 'g<End>', 'G', { noremap = true, silent = true })
vim.keymap.set('v', 'g<End>', 'G', { noremap = true, silent = true })
vim.keymap.set('x', 'g<End>', 'G', { noremap = true, silent = true })
-- Go to the beginning of the document
vim.keymap.set('n', 'g<Home>', 'gg', { noremap = true, silent = true })
vim.keymap.set('v', 'g<Home>', 'gg', { noremap = true, silent = true })
vim.keymap.set('x', 'g<Home>', 'gg', { noremap = true, silent = true })

-- Go to the next paragraph
vim.keymap.set('n', 'g<Down>', '}', { noremap = true, silent = true })
vim.keymap.set('v', 'g<Down>', '}', { noremap = true, silent = true })
vim.keymap.set('x', 'g<Down>', '}', { noremap = true, silent = true })
-- Go to the previous paragraph
vim.keymap.set('n', 'g<Up>', '{', { noremap = true, silent = true })
vim.keymap.set('v', 'g<Up>', '{', { noremap = true, silent = true })
vim.keymap.set('x', 'g<Up>', '{', { noremap = true, silent = true })


-- Hot Reload Config
vim.api.nvim_set_keymap('n', '<leader>r', ':luafile ~/.config/nvim/init.lua<CR>', { noremap = true, silent = true })

require("config.lazy")
