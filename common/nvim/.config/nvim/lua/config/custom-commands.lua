vim.api.nvim_create_user_command("OpenAllFilesWithExt", function(opts)
	local ext = opts.args
	if ext == "" then
		print("Please provide a file extension.")
		return
	end

	-- Get list of matching files (recursive)
	local handle = io.popen("find . -type f -name '*." .. ext .. "'")
	if not handle then
		print("Error listing files.")
		return
	end
	local result = handle:read("*a")
	handle:close()

	-- Split result into lines (filenames)
	local files = {}
	for filename in result:gmatch("[^\r\n]+") do
		table.insert(files, filename)
	end

	if #files == 0 then
		print("No files found with extension: " .. ext)
		return
	end

	-- Open files in buffers
	for _, file in ipairs(files) do
		vim.cmd("edit " .. file)
	end
end, {
	nargs = 1,
	complete = function()
		return { "txt", "lua", "py", "md", "c", "cpp", "java" }
	end,
})

vim.api.nvim_create_autocmd("TermOpen", {
	pattern = "*",
	callback = function()
		vim.keymap.set("t", "<Esc>", [[<C-\><C-n>]], { buffer = 0 })
	end,
})
