if not vim.g.neovide then
	return
end

vim.g.neovide_scale_factor = 0.85
vim.g.neovide_position_animation_length = 0
vim.g.neovide_cursor_animation_length = 0.0
vim.g.neovide_cursor_trail_size = 0
vim.g.neovide_cursor_animate_in_insert_mode = false
vim.g.neovide_cursor_animate_command_line = false

local function update_scale(delta)
	vim.g.neovide_scale_factor = vim.g.neovide_scale_factor + delta
end

vim.keymap.set("n", "<C-+>", function()
	update_scale(0.05)
end, { desc = "Neovide Zoom In" })
vim.keymap.set("n", "<C-->", function()
	update_scale(-0.05)
end, { desc = "Neovide Zoom Out" })
vim.keymap.set("n", "<C-0>", function()
	vim.g.neovide_scale_factor = 1.0
	vim.notify("Neovide scale reset to 1.0")
end, { desc = "Neovide Reset Zoom" })
