require("yaziline"):setup({
	separator_style = "curvy",
	separator_head = "",
	separator_tail = "",
})

require("full-border"):setup({
	-- Available values: ui.Border.PLAIN, ui.Border.ROUNDED
	type = ui.Border.ROUNDED,
})

require("command-palette"):setup()
