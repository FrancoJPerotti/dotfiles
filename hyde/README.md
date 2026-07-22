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

After stowing the profile, the default Kanata-owned Colemak layout starts with
Hyprland and uses the standard US International XKB map. It can be toggled with
`Super+F11` or by running `~/.local/bin/kanata_up.sh`.

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
