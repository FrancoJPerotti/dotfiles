# My Linux Dotfiles

[![Validate Dotfiles](https://github.com/franco/dotfiles_ubuntu/actions/workflows/validate.yml/badge.svg)](https://github.com/franco/dotfiles_ubuntu/actions/workflows/validate.yml)

A modular and robust system for managing my personal development environment across multiple Linux distributions using GNU Stow.

## Description

This repository contains my personal configuration files (dotfiles) for various tools and applications I use daily. The primary goal is to create a consistent, replicable, and automated development environment across different machines and operating systems, primarily Arch Linux and Ubuntu-based distros.

It solves the problem of manually configuring each new machine by treating configuration as code. By using GNU Stow, we can symlink files and directories from this repository into the home directory in an organized and reversible way.

### Key Features

*   **Modular Structure**: Configurations are split into a `common` base and distro-specific profiles (`arch`, `ubuntu`).
*   **Profile-Based Management**: Easily apply or remove entire configurations based on the host OS or desired setup.
*   **Automated Management**: Includes a `stow-manager` script to intelligently preview, apply, and revert configurations.
*   **Validated and Tested**: The repository structure and stow operations are automatically validated via GitHub Actions.
*   **Extensible**: Designed to be easily forked and customized. Adding new profiles or application configs is straightforward.

## Table of Contents

- [Installation](#installation)
- [Quick Start](#quick-start)
- [Configuration](#configuration)
  - [Directory Structure](#directory-structure)
  - [Creating a New Profile](#creating-a-new-profile)
  - [Managing Packages](#managing-packages)
- [Development](#development)
- [Testing](#testing)
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
    Look through the `common/`, `arch/`, and `ubuntu/` directories to see which configurations will be applied. You can exclude packages by adding their names to the `.stow-exclude` file within a profile directory.

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

The script automatically detects your OS and applies the `common` profile plus the relevant OS-specific profile.

```bash
# Preview what will be stowed (recommended)
./stow-manager -s -n

# Apply the configuration
./stow-manager -s
```

You can also explicitly specify a profile:

```bash
# Preview the 'arch' profile
./stow-manager -s arch -n

# Apply the 'ubuntu' profile
./stow-manager -s ubuntu
```

### Removing Configurations (Unstowing)

You can just as easily remove all symlinks.

```bash
# Preview what will be unstowed
./stow-manager -u -n

# Remove all managed symlinks
./stow-manager -u
```

## Configuration

### Directory Structure

The repository is organized into "profiles," which are top-level directories.

```
dotfiles/
├── common/              # Shared configs for all profiles
│   ├── nvim/
│   └── zsh/
├── arch/                # Arch Linux specific (e.g., Hyprland)
│   ├── hypr/
│   └── waybar/
├── ubuntu/              # Ubuntu specific (e.g., i3)
│   ├── i3/
│   └── polybar/
└── stow-manager         # The management script
```

-   `common/`: Contains configurations that are shared across all systems (e.g., `nvim`, `zsh`).
-   `arch/`, `ubuntu/`: Contain configurations specific to that environment. These are applied *in addition* to `common`.
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
    You can apply it alongside the auto-detected profiles.
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
bash -n stow-all.sh

# Run ShellCheck for deeper script analysis
shellcheck stow-manager stow-all.sh
    ```
4.  **Use dry-run mode**: Always test your changes with the `-n` flag to prevent unintended side effects.

## Testing

This project includes an automated validation workflow that runs on every push and pull request to the `main` branch. You can see the status badge at the top of this README.

The following checks are performed:
-   **Structure Validation**: Ensures that the `common` directory and at least one profile exist.
-   **Stow Dry-Run**: Simulates stowing and unstowing for both `arch` and `ubuntu` profiles to catch any conflicts or errors.
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

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

Copyright (c) 2025 [Your Name]

## Authors & Acknowledgments

-   **[Your Name]** - *Initial work & maintenance*

Special thanks to the creators and maintainers of all the open-source tools configured in this repository.

## Support & Contact

If you run into any issues or have a question, please open an issue on the [GitHub issue tracker](https://github.com/franco/dotfiles_ubuntu/issues).