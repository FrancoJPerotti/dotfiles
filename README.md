# My Dotfiles

Welcome to my personal dotfiles repository! This is where I store all the configurations for my Linux setup. The goal is to have a beautiful, functional, and consistent development environment that I can easily replicate on any machine.

## Features

*   **Highly Customized:** Every part of the setup is customized to my liking, from the color scheme to the keybindings.
*   **Automated Setup:** The `install.sh` script automates the installation of all the necessary software and dependencies.
*   **Symlinked Configurations:** The `stow-all.sh` script uses `stow` to symlink all the configuration files, making it easy to keep them in sync.
*   **Custom Scripts:** The repository includes several custom scripts to automate common tasks, such as a power menu, a wallpaper picker, and a workspace toggler.
*   **Coordinated Theme:** The color scheme is consistent across all applications, from the terminal to the editor to the window manager.

## Software

This setup uses a combination of the following software:

*   **Window Manager:** [i3-wm](https://i3wm.org/) - A tiling window manager that is highly configurable and keyboard-driven.
*   **Terminal:** [Kitty](https://sw.kovidgoyal.net/kitty/) - A fast, feature-rich, GPU-based terminal emulator.
*   **Shell:** [Zsh](https://www.zsh.org/) with [Oh My Zsh](https://ohmyz.sh/) and [Powerlevel10k](https://github.com/romkatv/powerlevel10k) - A powerful and customizable shell with a beautiful and informative prompt.
*   **Editor:** [Neovim](https://neovim.io/) - A modern and highly extensible text editor. The configuration is written in Lua and uses `lazy.nvim` for plugin management. Some of the key plugins include Telescope, Treesitter, and LSP Zero.
*   **Application Launcher:** [Rofi](https://github.com/davatorium/rofi) - A versatile application launcher and window switcher.
*   **Status Bar:** [Polybar](https://polybar.github.io/) - A fast and easy-to-use tool for creating status bars.
*   **Compositor:** [Picom](https://github.com/yshui/picom) - A lightweight compositor for X11, providing visual effects like transparency and shadows.
*   **File Manager:** [Yazi](https://github.com/sxyazi/yazi) - A fast and interactive terminal file manager.
*   **Browser:** [Vivaldi](https://vivaldi.com/) - A highly customizable web browser.

And many other command-line tools and utilities.

## Installation

1.  **Clone the repository:**

    ```bash
    git clone https://github.com/your-username/dotfiles.git ~/.dotfiles
    ```

2.  **Run the installation script:**

    The `install.sh` script is designed for Debian-based systems (like Ubuntu). It will install all the necessary packages.

    ```bash
    cd ~/.dotfiles
    sudo ./install.sh
    ```

    For other systems, you will need to install the packages listed in `pkglist.txt` and `aurlist.txt` manually using your system's package manager.

3.  **Stow the dotfiles:**

    This will symlink the configuration files to your home directory.

    ```bash
    ./stow-all.sh
    ```

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

