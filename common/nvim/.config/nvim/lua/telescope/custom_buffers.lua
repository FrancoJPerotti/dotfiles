local entry_display = require("telescope.pickers.entry_display")
local make_entry = require("telescope.make_entry")
local devicons = require("nvim-web-devicons")

-- ── custom highlight (green dot) that survives :colorscheme  ───────────────
local function set_hl()
	vim.api.nvim_set_hl(0, "BufferModifiedDot", { link = "String" })
end
set_hl()
vim.api.nvim_create_autocmd("ColorScheme", { callback = set_hl })

local MOD_GLYPH = "●"

-- ── helpers ────────────────────────────────────────────────────────────────
local function diag_counts(bufnr)
	local err, warn = 0, 0
	for _, d in ipairs(vim.diagnostic.get(bufnr)) do
		if d.severity == vim.diagnostic.severity.ERROR then
			err = err + 1
		elseif d.severity == vim.diagnostic.severity.WARN then
			warn = warn + 1
		end
	end
	return err, warn
end

local function diag_cell(count, icon, hl)
	if count == 0 then
		return nil, 0
	end
	local text = icon .. " " .. count
	return { text, hl }, vim.fn.strdisplaywidth(text)
end

-- ── entry-maker ────────────────────────────────────────────────────────────
local M = {}

function M.gen_with_dot(opts)
	local base = make_entry.gen_from_buffer(opts or {})

	return function(entry)
		entry = base(entry)

		local bufnr = entry.bufnr
		local filename = vim.fn.fnamemodify(entry.filename, ":t")
		local modified = vim.api.nvim_buf_get_option(bufnr, "modified")

		-- devicon + colour
		local icon, icon_hl = "", ""
		if devicons and filename ~= "" then
			local ext = vim.fn.fnamemodify(filename, ":e")
			icon, icon_hl = devicons.get_icon(filename, ext, { default = true })
		end

		-- diagnostics (once per entry)
		local err_n, warn_n = diag_counts(bufnr)
		local err_cell, err_w = diag_cell(err_n, "󰅚", "DiagnosticError")
		local warn_cell, warn_w = diag_cell(warn_n, "󰀪", "DiagnosticWarn")
		local diag_raw_width = err_w + warn_w + (err_w > 0 and warn_w > 0 and 1 or 0)

		------------------------------------------------------------------------
		-- display (runs on every redraw)
		------------------------------------------------------------------------
		entry.display = function()
			local picker_w = vim.api.nvim_win_get_width(0)

			-- 1. left part: dot  icon  filename
			local left = entry_display.create({
				separator = " ",
				items = {
					{ width = 2 }, -- dot
					{ width = 1 }, -- icon
					{ remaining = true }, -- filename fills the rest
				},
			})({
				{ modified and MOD_GLYPH or " ", "BufferModifiedDot" },
				{ icon, icon_hl },
				filename,
			})

			-- 2. compute padding so diagnostics block touches right border
			local pad_len = picker_w - vim.fn.strdisplaywidth(left) - diag_raw_width - 2
			if pad_len < 0 then
				pad_len = 0
			end
			local pad = (" "):rep(pad_len)

			-- 3. build diagnostics cells (warn first), prepend padding once
			local diag_cells, items = {}, {}
			if warn_cell then
				warn_cell[1] = pad .. warn_cell[1]
				diag_cells[#diag_cells + 1] = warn_cell
			end
			if err_cell then
				local sep = (#diag_cells > 0) and " " or pad
				err_cell[1] = sep .. err_cell[1]
				diag_cells[#diag_cells + 1] = err_cell
			end
			for _, c in ipairs(diag_cells) do
				items[#items + 1] = { width = vim.fn.strdisplaywidth(c[1]) }
			end
			local diag = entry_display.create({ separator = "", items = items })(diag_cells)

			return left .. diag
		end

		return entry
	end
end

return M
