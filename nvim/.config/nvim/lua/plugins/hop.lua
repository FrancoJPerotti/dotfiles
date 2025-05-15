return {
	"smoka7/hop.nvim",
	version = "*",
	opts = { keys = "arstneiodhpl", quit_key = "q" },
	config = function(_, opts)
		local hop = require("hop")
		hop.setup(opts)

		-- Create custom command for hopping to character/word matches
		vim.api.nvim_create_user_command("HopEasyMotion", function()
			local char = vim.fn.getchar()
			-- Convert numeric char code to string
			char = type(char) == "number" and vim.fn.nr2char(char) or char

			-- Create pattern based on input character type
			local pattern
			if char:match("%a") then
				-- For letters: match words starting with that letter (case insensitive)
				pattern = "\\c\\<" .. char
			elseif char:match("[%(%)]") then
				-- For parentheses: match them literally
				pattern = char
			elseif char == "." then
				-- For period: match literal period
				pattern = "\\."
			else
				-- For other non-letters: escape special characters
				pattern = char:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
			end

			---@diagnostic disable-next-line: missing-fields
			hop.hint_patterns({
				current_line_only = false,
				multi_windows = true,
				hint_position = require("hop.hint").HintPosition.BEGIN,
			}, pattern)
		end, { desc = "Hop to words starting with input character" })
	end,
	keys = {
		{ "<leader>s", "<cmd>HopChar1<cr>", desc = "Hop to word" },
	},
}
