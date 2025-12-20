local function system(cmd)
	if vim.system then
		return vim.system(cmd, { text = true }):wait().stdout or ""
	end

	return vim.fn.system(cmd)
end

return {
	diff = function()
		return system({ "git", "diff", "--no-ext-diff", "--staged" })
	end,
	last_commits = function()
		return system({ "git", "log", "--pretty=format:%s", "-n", "20" })
	end,
}

