# Ubuntu i3 Profile

This directory contains the Ubuntu-based i3 desktop profile. It is intended to be used together with the shared `common/` profile from the repository root.

For an overview of the dotfiles system and `stow-manager`, see `../README.md`.

## Features

* **Highly customized desktop:** Consistent theme, keybindings, and tooling across the whole environment.
* **Automated setup:** The `setup.sh` script installs required packages and configures the system.
* **Stow-based management:** The root `stow-manager` script symlinks all configuration files in a reproducible way.
* **Custom scripts:** Includes helpers for power menus, wallpapers, workspace toggling, and more.

## Software

This profile uses a combination of the following software:

* **Window Manager:** [i3-wm](https://i3wm.org/) – tiling window manager, keyboard-driven and highly configurable.
* **Terminal:** [Kitty](https://sw.kovidgoyal.net/kitty/) – fast, GPU-based terminal emulator.
* **Shell:** [Zsh](https://www.zsh.org/) with [Oh My Zsh](https://ohmyz.sh/) and [Powerlevel10k](https://github.com/romkatv/powerlevel10k).
* **Editor:** [Neovim](https://neovim.io/) – Lua configuration with `lazy.nvim`, Telescope, Treesitter, LSP, etc.
* **Launcher:** [Rofi](https://github.com/davatorium/rofi) – application launcher and window switcher.
* **Status Bar:** [Polybar](https://polybar.github.io/).
* **Compositor:** [Picom](https://github.com/yshui/picom).
* **File Manager:** [Yazi](https://github.com/sxyazi/yazi).
* **Browser:** [Vivaldi](https://vivaldi.com/) (plus Firefox and others as needed).

## Dependencies

### Core window manager stack

```bash
# Install i3 and essential components
sudo apt install i3-wm i3lock polybar rofi picom dunst

# Display and utilities
sudo apt install brightnessctl playerctl feh lxappearance
```

### Terminal & shell

```bash
# Kitty terminal (official installer)
curl -L https://sw.kovidgoyal.net/kitty/installer.sh | sh /dev/stdin launch=n

# Zsh with plugins
sudo apt install zsh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
```

### Additional tools

| Category | Packages | Purpose |
|----------|----------|---------|
| **System Tools** | `btop`, `stow`, `tree`, `tmux` | Monitoring, symlinks, utilities |
| **Development** | `git`, `gh`, `gcc`, `make`, `ripgrep`, `fzf` | Version control, building, searching |
| **Clipboard** | `xclip`, `xdotool`, `greenclip` | Clipboard management for X11 |
| **Display** | `wmctrl`, `imagemagick`, `flameshot` | Window control, screenshots |
| **Applications** | `firefox`, `evince`, `eog` | Browser, PDF, images |
| **Terminal Multiplexer** | `zellij` | Modern tmux alternative |

### Fonts

Some parts of the setup assume a Nerd Font and icon fonts are available:

```bash
sudo apt install fonts-firacode fonts-font-awesome
```

## Installation

1. **Clone the repository and change into it (one level up from this folder):**

   ```bash
   git clone https://github.com/franco/dotfiles_ubuntu.git ~/dotfiles
   cd ~/dotfiles
   ```

2. **Run the Ubuntu desktop setup script:**

   ```bash
   cd ubuntu-i3
    sudo ./setup.sh --install
    cd ..
    ```

    This installs i3-wm, polybar, rofi, picom, kitty, neovim, Docker, VS Code, Vivaldi, and the other dependencies listed above.
    It also installs global npm-based agent CLIs (Codex, OpenCode, Claude Code, Gemini CLI, OpenChamber, etc.) after setting up NVM/Node.

3. **Stow the `common` and `ubuntu-i3` profiles using `stow-manager`:**

   ```bash
   ./stow-manager -s ubuntu-i3
   ```

   The script automatically applies the `common/` base plus the `ubuntu-i3/` profile.

### Kanata on i3/X11

The VivoBook X510UQ uses the profile-specific
`~/.config/kanata/vivobook-x510uq.kbd`. It expects an ISO keyboard with the
`<LSGT>` key between left Shift and Z and runs over the standard `us(intl)` XKB
layout. The shared Kanata config used by the Hyde/Zenbook profile is left
unchanged. `setup.sh` installs the pinned Kanata 1.11.0 binary with checksum
verification.

Before enabling the user service, run a supervised trial:

```bash
~/.local/bin/kanata_trial.sh --check
~/.local/bin/kanata_trial.sh --start
```

The trial remains active until confirmed with `kanata_trial.sh --keep` or
restored explicitly with `kanata_trial.sh --rollback`. Keeping the trial enables
`kanata.service`; rolling back disables it and starts the previous shared
configuration.

## Keybindings

Here are some of the most important keybindings for i3:

### Window Management

| Keybinding              | Description                                |
| ----------------------- | ------------------------------------------ |
| `F12`                   | Kill focused window                        |
| `Super + Shift + f`     | Toggle floating for focused window         |
| `Super + n, e, i, o`    | Change focus (left, down, up, right)       |
| `Super + Left/Down/Up/Right` | Move focused window                    |
| `Super + Mod1 + n/o`    | Shrink/grow window width                   |
| `Super + Mod1 + i/e`    | Shrink/grow window height                  |

### Applications

| Keybinding              | Description                                |
| ----------------------- | ------------------------------------------ |
| `Super + Space`         | Open a new terminal                        |
| `Super + Return`        | Open the application launcher (Rofi)       |
| `Super + Shift + Return`| Open the file browser (Rofi)               |
| `Super + p`             | Take a screenshot (select area)            |
| `Super + c`             | Show clipboard history (Rofi)              |
| `Super + Shift + =`     | Show power menu (Rofi)                     |

### Workspaces

| Keybinding              | Description                                |
| ----------------------- | ------------------------------------------ |
| `Super + h`             | Switch to 'web' workspace                  |
| `Super + Shift + /`     | Switch to 'editor' workspace               |
| `Super + '`             | Switch to 'term' workspace                 |
| `Super + /`             | Switch to 'exp' workspace                  |
| `Super + s`             | Toggle 'spotify' workspace                 |
| `Super + d`             | Toggle 'discord' workspace                 |
| `Super + w`             | Toggle 'whatsapp' workspace                |
| `Super + t`             | Toggle 'ticktick' workspace                |
| `Super + Tab`           | Toggle 'chatgpt' workspace (tabbed)        |
| `Super + g`             | Toggle 'github' workspace (tabbed)         |
| `Super + f`             | Toggle 'zathura' workspace (tabbed)        |
| `Super + m`             | Toggle 'mail' workspace (tabbed)           |
| `Super + -`             | Toggle 'meet' workspace (tabbed)           |

### System

| Keybinding              | Description                                |
| ----------------------- | ------------------------------------------ |
| `Super + Shift + r`     | Reload i3 configuration                    |
| `Super + Shift + u`     | Update system packages                     |
| `Super + Shift + w`     | Open wallpaper picker                      |
