return {
	cmd = { "texlab" },
	filetypes = { "tex", "bib" },
	root_markers = { ".git" },
	settings = {
		texlab = {
			build = {
				onSave = false,
			},
			chktex = {
				onOpenAndSave = true,
				onEdit = true,
			},
		},
	},
}
