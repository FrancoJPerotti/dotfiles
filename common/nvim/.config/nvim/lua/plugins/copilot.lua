return {
	"zbirenbaum/copilot.lua",
	cmd = "Copilot",
	event = "InsertEnter",
	opts = function()
		-- detect Node path from a login zsh (so nvm works)
		local h = io.popen([[zsh -lc 'command -v node']])
		local node = h and h:read("*l") or nil
		if h then
			h:close()
		end

		return {
			suggestion = { enabled = false },
			panel = { enabled = false },
			filetypes = {
				markdown = true,
				help = true,
			},
			-- point Copilot to the correct Node
			copilot_node_command = node or vim.fn.exepath("node"),
		}
	end,
}
