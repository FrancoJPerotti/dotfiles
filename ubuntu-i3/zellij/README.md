# Zellij Workflows

This repository includes a generic workflow launcher for Zellij. Workflows are
stored as TOML manifests under `.config/zellij/workflows/` and rendered into
KDL layouts at runtime by the `zellij-workflow` helper.

## Structure

Each manifest resembles:

```toml
name = "Workspace"
session = "workspace"
description = "Projects plus tool agents"

[context]
project_root = "$home/code"

[defaults]
shell = "/bin/zsh"
shell_args = ["-ic"]

[[tabs]]
name = "Editor"
[tabs.root]
cwd = "$project_root"
command = "nvim"

[[foreach]]
glob = "$project_root/*"
[foreach.tab]
name = "${basename_spaces_title}"
[foreach.root]
cwd = "$path"
```

- `${…}` placeholders are expanded before the layout is generated. Common
  values include `path`, `basename`, and the entries defined in `[context]`.
- Tabs are described by a `root` pane. Panes can set `cwd`, `command`, and
  `split_direction`, and may list child panes to create splits.
- `[[foreach]]` blocks clone a tab template for each filesystem match.

## Tooling

- `scripts/.local/bin/zellij-workflow` renders manifests, launches sessions, and
  exposes helper commands (`list`, `start`, `sessions`, `kill`, `rofi-menu`).
- `scripts/.local/bin/rofi_zellij_picker.sh` is an interactive front-end that
  mirrors the audio picker style: choose a workflow to launch/recreate or manage
  existing sessions through Rofi menus.

## Sample Workflows

- `workspace.toml` &ndash; general-purpose workspace mirroring your original script.
- `dev_loop.toml` &ndash; focused project loop with editor, dev server, tests, and log tail.
- `multi_repo_overview.toml` &ndash; generates a status tab for every directory matched by `repo_glob`, showing git status, recent commits, and an interactive shell.

Set `ZELLIJ_WORKFLOW_DIR` to override the manifest location (it defaults to
`~/.config/zellij/workflows`). The default shell, terminal, and layout cache
directory can also be tweaked inside each manifest's `[defaults]` table.
