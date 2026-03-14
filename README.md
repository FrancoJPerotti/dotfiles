# My Linux Dotfiles

[![Validate Dotfiles](https://github.com/franco/dotfiles_ubuntu/actions/workflows/validate.yml/badge.svg)](https://github.com/franco/dotfiles_ubuntu/actions/workflows/validate.yml)

A modular and robust system for managing my personal development environment across multiple Linux distributions using GNU Stow.

## Description

This repository contains my personal configuration files (dotfiles) for various tools and applications I use daily. The primary goal is to create a consistent, replicable, and automated development environment across different machines and operating systems, primarily Arch Linux and Ubuntu-based distros.

It solves the problem of manually configuring each new machine by treating configuration as code. By using GNU Stow, we can symlink files and directories from this repository into the home directory in an organized and reversible way.

### Key Features

*   **Modular Structure**: Configurations are split into a `common` base and profile directories (for example `ubuntu-i3`, `hyde`).
*   **Profile-Based Management**: Easily apply or remove entire configurations based on the host OS or desired setup.
*   **Automated Management**: Includes a `stow-manager` script to intelligently preview, apply, and revert configurations.
*   **Validated and Tested**: The repository structure and stow operations are automatically validated via GitHub Actions.
*   **Extensible**: Designed to be easily forked and customized. Adding new profiles or application configs is straightforward.

## Table of Contents

- [Installation](#installation)
- [Quick Start](#quick-start)
- [Profiles](#profiles)
- [Dependencies & Prerequisites](#dependencies--prerequisites)
  - [Core Requirements](#core-requirements-all-profiles)
  - [Common Profile Dependencies](#common-profile-dependencies)
  - [Profile-Specific Dependencies](#profile-specific-dependencies)
  - [Optional Dependencies](#optional-dependencies)
  - [Font Requirements](#font-requirements)
  - [Checking Dependencies](#checking-dependencies)
- [Configuration](#configuration)
  - [Directory Structure](#directory-structure)
  - [Creating a New Profile](#creating-a-new-profile)
  - [Managing Packages](#managing-packages)
- [Development](#development)
- [Testing](#testing)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)
- [License](#license)
- [Authors & Acknowledgments](#authors--acknowledgments)
- [Support & Contact](#support--contact)

## Installation

### Prerequisites

You need to have `git` and `stow` installed.

```bash
# Arch Linux / Manjaro
sudo pacman -S stow git

# Ubuntu / Debian
sudo apt install stow git
```

### Step-by-step Installation

1.  **Clone the repository:**
    ```bash
    git clone https://github.com/franco/dotfiles_ubuntu.git ~/dotfiles
    cd ~/dotfiles
    ```

2.  **Review the packages:**
    Look through the `common/`, `ubuntu-i3/`, and `hyde/` directories to see which configurations will be applied. You can exclude packages by adding their names to the `.stow-exclude` file within a profile directory.

3.  **Preview the changes (Dry Run):**
    It is **highly recommended** to perform a dry run first. This will show you exactly what changes will be made without actually creating any symlinks.
    ```bash
    ./stow-manager --stow -n
    ```
    The script will auto-detect your distribution and show which symlinks it would create.

4.  **Apply the configuration:**
    Once you are satisfied with the preview, apply the configuration.
    ```bash
    ./stow-manager --stow
    ```

## Quick Start

The `stow-manager` script is the primary interface for managing your dotfiles.

### Applying Configurations (Stowing)

```bash
# Preview the 'ubuntu-i3' profile
./stow-manager -s ubuntu-i3 -n

# Apply the 'ubuntu-i3' profile
./stow-manager -s ubuntu-i3

# Preview the 'hyde' profile (Arch + Hyprland)
./stow-manager -s hyde -n

# Apply the 'hyde' profile
./stow-manager -s hyde
```

### Removing Configurations (Unstowing)

You can just as easily remove all symlinks.

```bash
# Preview what will be unstowed
./stow-manager -u -n

# Remove all managed symlinks
./stow-manager -u
```

## Profiles

This repository is organized into a shared base profile and environment-specific profiles:

- **common/** – Shared configuration that is always applied.
- **ubuntu-i3/** – Ubuntu-based desktop profile using the i3 window manager. See [ubuntu-i3/README.md](ubuntu-i3/README.md) for full setup instructions and package lists.
- **hyde/** – Arch Linux Hyprland profile. See [hyde/README.md](hyde/README.md) for full setup instructions and package lists.

## Dependencies & Prerequisites

This section details the dependencies required for each profile and package configuration. The dotfiles are designed to work with multiple Linux distributions, but certain features require specific software.

### Core Requirements (All Profiles)

These are required for basic dotfiles management:

- **git** - Version control system
- **stow** - GNU Stow for symlink management
- **bash** - Shell (for running management scripts)

### Common Profile Dependencies

The `common/` profile contains cross-platform configurations. Install these packages based on your needs:

| Package | Required Software | Installation |
|---------|------------------|--------------|
| **nvim** | Neovim ≥ 0.9.0 | `sudo pacman -S neovim` (Arch)<br>`sudo snap install nvim --classic` (Ubuntu) |
| **yazi** | Yazi file manager | `sudo pacman -S yazi` (Arch)<br>`sudo snap install yazi --classic` (Ubuntu) |
| **zathura** | Zathura PDF viewer<br>zathura-pdf-poppler | `sudo pacman -S zathura zathura-pdf-poppler` (Arch)<br>`sudo apt install zathura zathura-pdf-poppler` (Ubuntu) |
| **Code** | Visual Studio Code | `yay -S visual-studio-code-bin` (Arch)<br>`sudo snap install code --classic` (Ubuntu) |
| **zed** | Zed editor | `yay -S zed` (Arch)<br>`curl -f https://zed.dev/install.sh \| sh` (Ubuntu) |
| **vivaldi** | Vivaldi browser | `yay -S vivaldi` (Arch)<br>Install from [vivaldi.com](https://vivaldi.com/) (Ubuntu) |
| **web_apps** | Modern web browser | Any browser (Firefox, Chrome, Vivaldi, etc.) |

### Profile-Specific Dependencies

Each profile has its own detailed package list and installation flow:

- **Ubuntu i3** – see [ubuntu-i3/README.md](ubuntu-i3/README.md) for the full window manager stack, extra tools, and the `setup.sh` installer.
- **Hyde (Arch + Hyprland)** – see [hyde/README.md](hyde/README.md) for `pkglist.txt`, `aurlist.txt`, and profile-specific notes.

### Optional Dependencies

Some features require additional software not automatically installed:

- **Starship prompt** - Modern shell prompt (installed via `curl -sS https://starship.rs/install.sh | sh`)
- **NVM** - Node Version Manager (for Node.js development)
- **Docker Desktop** - GUI for Docker (Ubuntu only, installed via deb package)
- **Python venv** - For Python development (`python3.12-venv` on Ubuntu)

### AI / Agent CLIs (Global npm tools)

This repo also tracks a small set of global npm-based CLIs (Codex, OpenCode, Claude Code, Gemini CLI, OpenChamber, etc.).

- **List:** `common/ai_tools/.config/ai-tools/npm-global.txt`
- **Installer:** `common/ai_tools/.local/bin/ai-tools`
- **Ubuntu:** `ubuntu-i3/setup.sh` installs these automatically after setting up NVM/Node.
- **Other systems:** stow your profile, then run `ai-tools install`.

### Font Requirements

Some configurations (especially terminal and status bars) work best with nerd fonts:

```bash
# Ubuntu
sudo apt install fonts-firacode fonts-font-awesome

# Arch
sudo pacman -S ttf-firacode-nerd ttf-font-awesome
```

### Checking Dependencies

After installation, verify your dependencies:
```bash
# Check if required binaries are available
command -v stow git nvim yazi zsh kitty

# For i3 users
command -v i3 polybar rofi picom

# For Hyprland users  
command -v hyprland waybar
```

## Configuration

### Directory Structure

The repository is organized into "profiles," which are top-level directories.

```
dotfiles/
├── common/              # Shared configs for all profiles
│   ├── nvim/
│   └── zsh/
├── ubuntu-i3/           # Ubuntu-based desktop (i3)
│   ├── i3/
│   └── polybar/
├── hyde/                # Arch Linux Hyprland profile
│   ├── hypr/
│   └── waybar/
└── stow-manager         # The management script
```

-   `common/`: Contains configurations that are shared across all systems (e.g., `nvim`, `zsh`).
-   `ubuntu-i3/`, `hyde/`: Contain configurations specific to that environment. These are applied *in addition* to `common`.
-   Each package (e.g., `nvim`) mirrors the structure of the `$HOME` directory. For example, `common/nvim/.config/nvim/init.lua` will be symlinked to `~/.config/nvim/init.lua`.

### Creating a New Profile

1.  **Create the profile directory:**
    ```bash
    mkdir work
    ```

2.  **Add your packages:**
    Create subdirectories for each application, mirroring the home directory structure.
    ```bash
    mkdir -p work/git/.config/git
    echo "[user]\n    email = work-email@example.com" > work/git/.config/git/config
    ```

3.  **Apply the new profile:**
    You can apply it alongside your existing profiles.
    ```bash
    ./stow-manager -s work
    ```

### Managing Packages

#### Adding a New Package

1.  Decide which profile the package belongs to (`common` is a good default).
2.  Create the directory structure. For example, to add a `tmux` configuration:
    ```bash
    mkdir -p common/tmux/.config/tmux
    touch common/tmux/.config/tmux/tmux.conf
    ```
3.  Run the manager to apply it:
    ```bash
    ./stow-manager -s
    ```

#### Excluding a Package

If you don't want to install a specific package from a profile, add its name to the `.stow-exclude` file in that profile's directory.

```bash
# Example: Don't stow the 'zsh' package from the common profile
echo "zsh" >> common/.stow-exclude
```

## Development

To work on the dotfiles or the management scripts:

1.  **Set up the environment**: Clone the repository as described in the [Installation](#installation) section.
2.  **Make changes**: Edit existing files, add new packages, or modify the scripts.
3.  **Run local validation**: Before committing, run the same checks that the CI pipeline uses.

    ```bash
    # Check script syntax
    bash -n stow-manager

    # Run ShellCheck for deeper script analysis
    shellcheck stow-manager
    ```
4.  **Use dry-run mode**: Always test your changes with the `-n` flag to prevent unintended side effects.

## Testing

This project includes an automated validation workflow that runs on every push and pull request to the `main` branch. You can see the status badge at the top of this README.

The following checks are performed:
-   **Structure Validation**: Ensures that the `common` directory and at least one profile exist.
-   **Stow Dry-Run**: Simulates stowing and unstowing for each profile to catch any conflicts or errors.
-   **Script Syntax Check**: Validates the Bash syntax of the management scripts.
-   **ShellCheck Analysis**: Statically analyzes the scripts for potential bugs and bad practices.

## Contributing

Contributions are welcome! Whether it's improving a configuration, fixing a bug in a script, or adding a new feature, please feel free to open a pull request.

### Pull Request Process

1.  Fork the repository.
2.  Create a new branch (`git checkout -b feature/my-new-feature`).
3.  Make your changes.
4.  Test your changes locally.
5.  Commit your changes (`git commit -am 'Add some feature'`).
6.  Push to the branch (`git push origin feature/my-new-feature`).
7.  Open a new Pull Request.

## Troubleshooting

### Common Issues

#### Stow Conflicts
If you see errors about existing files when running `stow-manager --stow`:
- **Backup existing files**: Move conflicting files to a backup location
- **Use dry-run first**: Always run `./stow-manager -s -n` to preview changes
- **Check for existing symlinks**: Run `ls -la ~` to identify existing dotfiles

#### Missing Dependencies
If `stow-manager` fails to run:
```bash
# Install GNU Stow
sudo apt install stow        # Ubuntu/Debian
sudo pacman -S stow          # Arch Linux
```

#### Symlinks Not Working
If configurations aren't taking effect after stowing:
- **Reload your shell**: Run `exec $SHELL` or restart your terminal
- **Check symlink paths**: Run `ls -la ~/.config` to verify symlinks were created
- **Verify package structure**: Ensure your package mirrors the `$HOME` directory structure

#### Profile Not Detected
If `stow-manager` doesn't detect your OS correctly:
```bash
# Manually specify your profile
./stow-manager -s ubuntu-i3    # For Ubuntu-based systems
./stow-manager -s hyde         # For Arch-based systems
```

#### Permission Errors
If you encounter permission denied errors:
- **Don't run as root**: Run `stow-manager` as your regular user, not with `sudo`
- **Check directory ownership**: Ensure `~/dotfiles` is owned by your user

#### Unstow Doesn't Remove Files
If `./stow-manager -u` doesn't remove symlinks:
- **Verify stow database**: Stow tracks what it manages; manually created symlinks won't be removed
- **Use verbose mode**: Add `-v` flag for detailed output: `./stow-manager -u -v`

For additional help, please open an issue on the [GitHub issue tracker](https://github.com/franco/dotfiles_ubuntu/issues).

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

Copyright (c) 2025 Franco

## Authors & Acknowledgments

-   **Franco** - *Initial work & maintenance*

Special thanks to the creators and maintainers of all the open-source tools configured in this repository.

## Support & Contact

If you run into any issues or have a question, please open an issue on the [GitHub issue tracker](https://github.com/franco/dotfiles_ubuntu/issues).
