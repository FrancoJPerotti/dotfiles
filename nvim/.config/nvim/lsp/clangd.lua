return {
	cmd = { "clangd", "--background-index", "--clang-tidy" },
	filetypes = { "c", "cpp" },
	root_markers = { "compile_commands.json", "compile_flags.txt", ".git" },
}
