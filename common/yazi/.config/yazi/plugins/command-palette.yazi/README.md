# command-palette.yazi

A small local Yazi command palette for directory bookmarks.

## Usage

Open the palette with the configured keybinding, then use:

- type to fuzzy-filter bookmarks immediately
- arrow keys to move through bookmarks
- `Enter` to jump to the selected bookmark
- `Ctrl-a` to add the current directory as a bookmark
- `Ctrl-d` to delete the selected bookmark
- `Ctrl-u` to clear the filter
- `Esc` or `Ctrl-c` to close the palette

Bookmarks are stored in `$XDG_STATE_HOME/yazi/command-palette-bookmarks.tsv`, or
`~/.local/state/yazi/command-palette-bookmarks.tsv` when `XDG_STATE_HOME` is not set.
