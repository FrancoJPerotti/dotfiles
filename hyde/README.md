# Hyde Profile (Arch + Hyprland)

This directory contains the Arch Linux profile built around the Hyprland compositor. It is meant to be used together with the shared `common/` profile from the repository root.

For the overall dotfiles architecture and `stow-manager` usage, see `../README.md`.

## Structure

At a high level:

```
dotfiles/
├── common/
│   ├── nvim/
│   ├── zsh/
│   └── ...
├── hyde/
│   ├── hypr/
│   ├── waybar/
│   ├── kitty/
│   ├── zellij/
│   ├── zsh/
│   ├── web_apps/
│   └── ...
└── stow-manager
```

Each top-level directory inside `common/` and `hyde/` is a standalone [GNU Stow](https://www.gnu.org/software/stow/manual/stow.html) package.

## Dependencies

### Official repository packages

Install base packages from `pkglist.txt`:

```bash
sudo pacman -S --needed - < pkglist.txt
```

Key groups include:

- **Hyprland stack:** Hyprland compositor and related Wayland utilities.
- **Terminal/Shell:** `kitty`, `zsh`, `zellij`.
- **Development:** `git`, `neovim`, `gcc`, `make`, `docker`, `github-cli`.
- **Tools:** `btop`, `yazi`, `evince`, `stow`, `tmux`.
- **Java tooling:** `jdk8-openjdk`, `jdk17-openjdk`, `jdk21-openjdk`, `maven`.
- **PDF:** `zathura`, `zathura-pdf-poppler`.

### AUR packages

Install AUR packages from `aurlist.txt` (requires [`yay`](https://github.com/Jguer/yay)):

```bash
yay -S --needed - < aurlist.txt
```

Notable AUR tools:

- `kanata` – advanced keyboard remapping.
- `wl-kbptr` – keyboard-driven mouse pointer for Wayland.
- `conan` – C/C++ package manager.
- `unity-test` – C unit testing framework.
- `vial-appimage` – keyboard configuration tool.

Kanata startup is selected per computer in
`hypr/.config/hypr/lua/machines.lua`, using the hostname reported by `hostname`.
The desktop (`archlinux`) and unknown computers have `kanata = false`.
The laptop (`zenbook`) has `kanata = true`, enabling automatic startup and
the `Super+F11` toggle. Add other computers to that table as needed.

On enabled computers, the default Kanata-owned Colemak layout starts with
Hyprland and uses the standard US International XKB map. Reloading Hyprland
synchronizes keyboard visibility without restarting Kanata if you stopped it
manually. You can also run `~/.local/bin/kanata_up.sh` directly.

```bash
# Activate the default Kanata-owned mapping with US International XKB.
~/.local/bin/kanata_up.sh --current

# Restore the previous Kanata mapping with the custom CDHWIC XKB layout.
~/.local/bin/kanata_up.sh --legacy
```

The default configuration lives at
`~/.config/kanata/colemak-dh-kanata-test.kbd`. Its ASCII symbols emit their
final US keycodes so shortcut handling is consistent in Chromium-based
applications. The standard US International XKB variant supplies dead acute
and grave accents plus `ñ`/`Ñ`, including in terminals. Less common characters
still use Kanata Unicode actions and may not work in every native Wayland
application. The previous `colemak-dh-ansi.kbd` configuration and `cdhwic`
layout remain available through `--legacy`.

### Active Lua configuration and retained legacy files

The active personal Hyprland entry point is `hypr/.config/hypr/hyprland.lua`,
which loads the modules in `hypr/.config/hypr/lua/`.

For a file map, application catalog fields, editing examples and validation
commands, see [Editing Hyprland configuration](HYPRLAND.md). Application
commands, shortcuts, startup stages and window preferences are declared in
`lua/apps.lua`; the other modules interpret that catalog.

The previous configurations remain in their original locations temporarily
for comparison and reference. They are not loaded or launched by the active
Lua configuration:

| Retained file | Active replacement |
| --- | --- |
| `userprefs.conf` | `lua/options.lua`, `lua/input.lua`, `lua/rules.lua`, `lua/events.lua` and `lua/autostart.lua` |
| `keybindings.conf` | `lua/bindings.lua`, `lua/applications.lua` and `lua/workspaces.lua` |
| `autostart.sh` | `lua/autostart.lua`, invoked by `lua/events.lua` |

Keep these files when syncing to another computer; do not source the legacy
`.conf` files or invoke `autostart.sh` from the active configuration.

### Per-computer monitors

Monitor modes, positions, scales and workspace priority are also defined in
`hypr/.config/hypr/lua/machines.lua`. The desktop (`archlinux`) uses `DP-3` at
3840x2160, 60 Hz and scale 1.5.

On `zenbook`, the built-in Samsung panel uses 2880x1800 at 120 Hz, scale 2 and
position `307x1080`. The external Samsung uses 1920x1080 at 60 Hz, scale 1 and
position `67x0`. The `workspace_monitors` list prefers the external Samsung,
then the built-in panel. Workspaces 1–4 and their windows move automatically
when connecting or disconnecting the external monitor; the active numbered
workspace is preserved. Output descriptions use prefixes to tolerate serial
suffix differences. Unknown computers receive no personal monitor modes or
workspace monitor assignment.

### Per-computer Waybar layouts

`machines.lua` also selects Waybar through HyDE on session startup and config
reload. `archlinux` uses `francos_bar_desktop`, which inherits the common bar
and removes brightness and battery modules. `zenbook` uses
`francos_bar_2_monitors`, keeping those laptop controls. The selection skips
reloading Waybar when its saved layout and generated config already match.

Hardware-reading spacing is stored in `waybar/.config/waybar/user-style.css`,
which HyDE imports after its theme styles. It preserves the pre-Lua HyDE values
from the July 16, 2026 backup: `0.2em` horizontal margin and padding on each
side of each reading. Existing Caps Lock styling is
preserved there too. The older three-monitor layout remains available in the
HyDE layout selector.

### Handy transcription shortcuts

Install Handy separately; it is not currently included in `pkglist.txt` or
`aurlist.txt`. The `handy` executable must be available on `PATH`.

The `scripts` Stow package installs `~/.local/bin/handy-smart-toggle.sh`.
Hyprland uses it for `Super+Shift+H` and `F10` (transcription), and
`Super+Shift+K` (transcription with post-processing). If recording is already
active, any of these shortcuts stops the mode that started it.

The wrapper detects the active mode from Handy's debug log at
`~/.local/share/com.pais.handy/logs/handy.log`. Set `HANDY_LOG` in the Hyprland
session environment if the log is stored elsewhere. The destination computer
also needs Handy's models and application settings configured separately.

### Fonts

Some parts of the setup assume Nerd Fonts and icon fonts:

```bash
sudo pacman -S ttf-firacode-nerd ttf-font-awesome
```

## Installation

1. **Clone the repository and change into it (one level up from this folder):**

   ```bash
   git clone https://github.com/franco/dotfiles_ubuntu.git ~/dotfiles
   cd ~/dotfiles
   ```

2. **Install packages for the Hyde profile:**

   ```bash
   cd hyde
   sudo pacman -S --needed - < pkglist.txt
   yay -S --needed - < aurlist.txt
   cd ..
   ```

3. **Stow the `common` and `hyde` profiles using `stow-manager`:**

   ```bash
    ./stow-manager -s hyde
    ```

    The script automatically applies the `common/` base plus the `hyde/` profile.

4. **Install global AI/agent CLIs (npm):**

   Requires Node.js + npm (NVM works well if you want per-user installs).
   Install the repo-managed global tools list:

   ```bash
   ai-tools install
   ```

## Philosophy

- Keep each config isolated in its own folder.
- Symlink only what you need.
- Make onboarding and restoration simple and repeatable.
