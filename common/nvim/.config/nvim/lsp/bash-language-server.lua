return {
	cmd = { "bash-language-server", "start" },
	filetypes = { "sh" },
	root_markers = {
		".git",
		".bashrc",
		".bash_profile",
		".shellcheckrc",
	},
	single_file_support = true,
	settings = {
		bashIde = {
			globPattern = "*@(.sh|.inc|.bash|.command)",
		},
	},
}
