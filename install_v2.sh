#!/usr/bin/env bash
#
# Ubuntu Desktop Setup Script (Repair & Install Version)
#
# Description: A comprehensive script to provision a new Ubuntu desktop.
#              It actively finds and repairs broken APT configurations
#              before installing and configuring the system.
#
# Usage:       sudo ./setup-script.sh
#
set -uo pipefail

# ========== Error Handling ==========
err_trap() {
    local err=$?
    local line_number=${BASH_LINENO[0]}
    local command_str="${BASH_COMMAND}"
    trap - ERR
    printf "\n\033[1;31m"
    echo "============================================================"
    echo "FATAL ERROR: A command failed on line $line_number with exit code $err."
    echo "The command was: $command_str"
    echo "============================================================"
    printf "\033[0m"
    exit $err
}
trap err_trap ERR

# ========== Configuration & Constants ==========
readonly TARGET_USER="${SUDO_USER:-$USER}"
readonly USER_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)

# UI/UX Helpers
readonly C_RESET=$'\033[0m'
readonly C_BOLD=$'\033[1m'
readonly C_CYAN=$'\033[1;36m'
readonly C_YELLOW=$'\033[1;33m'
readonly C_RED=$'\033[1;31m'
readonly C_GREEN=$'\033[1;32m'
readonly S_TICK="${C_GREEN}✓${C_RESET}"
readonly S_CROSS="${C_RED}✗${C_RESET}"
readonly S_SKIP="${C_YELLOW}→${C_RESET}"
TASKS_COMPLETED=0
TASKS_SKIPPED=0

# ========== Helper Functions ==========
log_step() { printf "\n%s%s==> %s%s\n" "$C_BOLD" "$C_CYAN" "$*" "$C_RESET"; }
log_ok() {
    printf "%s %s\n" "$S_TICK" "$*"
    ((TASKS_COMPLETED++))
}
log_skip() {
    printf "%s %s\n" "$S_SKIP" "$*"
    ((TASKS_SKIPPED++))
}
log_err() {
    printf "\n%s %s\n" "$S_CROSS" "$*" >&2
    exit 1
}
have() { command -v "$1" >/dev/null 2>&1; }

# ========== Installation Modules ==========

cleanup_managed_repos() {
    log_step "Repairing system by cleaning up old repository configurations..."
    local files_to_remove=(
        # VS Code - The source of the conflict
        "/etc/apt/sources.list.d/vscode.list"
        "/usr/share/keyrings/packages.microsoft.gpg"
        "/usr/share/keyrings/microsoft.gpg" # The specific conflicting old key
        # Other managed repos
        "/etc/apt/sources.list.d/github-cli.list"
        "/usr/share/keyrings/githubcli-archive-keyring.gpg"
        "/etc/apt/sources.list.d/vivaldi-archive.list"
        "/usr/share/keyrings/vivaldi-browser.gpg"
        "/etc/apt/sources.list.d/docker.list"
        "/etc/apt/keyrings/docker.gpg"
    )
    for file in "${files_to_remove[@]}"; do
        if [ -f "$file" ]; then
            rm -f "$file"
            log_ok "Removed conflicting file: $file"
        fi
    done

    # Aggressively remove any lingering VS Code repo definitions using old key
    for f in /etc/apt/sources.list.d/*.list; do
        [ -e "$f" ] || break
        if grep -qE 'https?://packages.microsoft.com/repos/code' "$f"; then
            rm -f "$f"
            log_ok "Removed VS Code repo list: $f"
        fi
    done
    if [ -f "/etc/apt/sources.list" ] && grep -qE 'https?://packages.microsoft.com/repos/code' "/etc/apt/sources.list"; then
        sed -i '/packages.microsoft.com\/repos\/code/d' "/etc/apt/sources.list"
        log_ok "Removed VS Code repo lines from /etc/apt/sources.list"
    fi
}

initialize_system() {
    log_step "Initializing System and Configuring APT Repositories"
    if [[ "$EUID" -ne 0 ]]; then log_err "This script must be run as root. Please use 'sudo'."; fi
    log_ok "Running as root"
    if ! have curl || ! have jq || ! have git || ! have add-apt-repository || ! have lsb_release; then
        log_step "Installing prerequisite tools..."
        export DEBIAN_FRONTEND=noninteractive
        apt-get update -qq
        apt-get install -yq curl jq git software-properties-common lsb-release
    fi
    log_ok "Prerequisite tools are installed"

    # --- THIS IS THE FIX ---
    # Run the cleanup function to ensure a clean state before proceeding.
    cleanup_managed_repos

    local codename
    codename=$(lsb_release -cs 2>/dev/null | tail -n 1)
    if [ -z "$codename" ]; then log_err "Could not determine OS codename."; fi
    log_ok "Detected OS codename: $codename"
    add-apt-repository -y universe >/dev/null 2>&1 && log_ok "Enabled 'universe' repository"
    add-apt-repository -y multiverse >/dev/null 2>&1 && log_ok "Enabled 'multiverse' repository"

    add_repo() {
        local name="$1" key_url="$2" key_path="$3" repo_line="$4" repo_file="$5"
        curl -fsSL "$key_url" | gpg --dearmor --yes -o "$key_path"
        chmod a+r "$key_path"
        echo "$repo_line" >"$repo_file"
        log_ok "Configured '$name' repository"
    }

    add_repo "GitHub CLI" \
        "https://cli.github.com/packages/githubcli-archive-keyring.gpg" "/usr/share/keyrings/githubcli-archive-keyring.gpg" \
        "deb [signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
        "/etc/apt/sources.list.d/github-cli.list"
    add_repo "VS Code" \
        "https://packages.microsoft.com/keys/microsoft.asc" "/usr/share/keyrings/packages.microsoft.gpg" \
        "deb [arch=amd64,arm64,armhf signed-by=/usr/share/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" \
        "/etc/apt/sources.list.d/vscode.list"
    add_repo "Vivaldi" \
        "https://repo.vivaldi.com/archive/linux_signing_key.pub" "/usr/share/keyrings/vivaldi-browser.gpg" \
        "deb [signed-by=/usr/share/keyrings/vivaldi-browser.gpg arch=amd64] https://repo.vivaldi.com/archive/deb/ stable main" \
        "/etc/apt/sources.list.d/vivaldi-archive.list"
    add_repo "Docker Engine" \
        "https://download.docker.com/linux/ubuntu/gpg" "/etc/apt/keyrings/docker.gpg" \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu ${codename} stable" \
        "/etc/apt/sources.list.d/docker.list"
}

install_apt_packages() {
    log_step "Installing packages via APT"
    local core_pkgs=(
        brightnessctl
        btop
        cliphist
        dunst
        eog
        evince
        eza
        feh
        firefox
        fzf
        gcc
        git
        lxappearance
        maim
        make
        picom
        playerctl
        python3.12-venv
        rofi
        imagemagick
        i3-wm
        i3lock
        polybar
        ripgrep
        stow
        tmux
        tree
        unzip
        vim
        wmctrl
        xclip
        xdotool
        zathura
        zathura-pdf-poppler
        zsh
    )
    local repo_pkgs=(
        gh
        code
        vivaldi-stable
        docker-ce
        docker-ce-cli
        containerd.io
        docker-buildx-plugin
        docker-compose-plugin
    )
    apt-get update -qq
    apt-get install -yq "${core_pkgs[@]}" "${repo_pkgs[@]}"
    if ! getent group docker | grep -q "\b$TARGET_USER\b"; then
        usermod -aG docker "$TARGET_USER"
        log_ok "Added user '$TARGET_USER' to the 'docker' group"
    else log_skip "User '$TARGET_USER' is already in the 'docker' group"; fi
}

install_kitty() {
    log_step "Installing Kitty terminal emulator"
    local kitty_app_dir="$USER_HOME/.local/kitty.app"
    local installer_url="https://sw.kovidgoyal.net/kitty/installer.sh"
    if [ ! -x "$kitty_app_dir/bin/kitty" ]; then
        sudo -u "$TARGET_USER" bash -lc "set -euo pipefail; curl -L $installer_url | sh /dev/stdin launch=n"
        log_ok "Installed Kitty from official installer"
    else
        log_skip "Kitty already installed at $kitty_app_dir"
    fi
}

configure_kitty_default() {
    log_step "Configuring Kitty as default terminal"
    local kitty_app_dir="$USER_HOME/.local/kitty.app"
    local kitty_bin="$kitty_app_dir/bin/kitty"
    local kitty_symlink="$USER_HOME/.local/bin/kitty"
    if [ ! -x "$kitty_bin" ]; then
        log_skip "Kitty not installed at $kitty_bin, skipping default terminal configuration"
        return
    fi
    sudo -u "$TARGET_USER" mkdir -p "$USER_HOME/.local/bin"
    sudo -u "$TARGET_USER" ln -sf "$kitty_bin" "$kitty_symlink"
    log_ok "Ensured Kitty launcher symlink at $kitty_symlink"
    local alternatives
    alternatives=$(update-alternatives --list x-terminal-emulator 2>/dev/null || true)
    if ! grep -Fx "$kitty_symlink" <<<"$alternatives"; then
        update-alternatives --install /usr/bin/x-terminal-emulator x-terminal-emulator "$kitty_symlink" 50
        log_ok "Registered Kitty with update-alternatives"
    else
        log_skip "Kitty already registered with update-alternatives"
    fi
    update-alternatives --set x-terminal-emulator "$kitty_symlink"
    log_ok "Set Kitty as the default terminal emulator"
}

install_standalone_tools() {
    log_step "Installing standalone tools"
    if ! dpkg-query -W -f='${Status}' docker-desktop 2>/dev/null | grep -q "install ok installed"; then
        log_step "Installing Docker Desktop..."
        local url="https://desktop.docker.com/linux/main/amd64/docker-desktop-amd64.deb"
        local deb_path="/tmp/docker-desktop.deb"
        curl -fL -o "$deb_path" "$url"
        apt-get install -yq "$deb_path" || apt-get -f install -yq
        rm "$deb_path"
        log_ok "Installed Docker Desktop"
    else
        log_skip "Docker Desktop is already installed"
    fi
    if ! have snap; then apt-get install -yq snapd; fi
    if ! have nvim; then snap install nvim --classic && log_ok "Installed Neovim (snap)"; else log_skip "Neovim already installed"; fi
    if ! have yazi; then snap install yazi --classic && log_ok "Installed Yazi (snap)"; else log_skip "Yazi already installed"; fi
    if ! have starship; then
        sudo -u "$TARGET_USER" sh -c 'curl -sS https://starship.rs/install.sh | sh -s -- -y -f'
        log_ok "Installed Starship"
    else log_skip "Starship already installed"; fi
    if ! have zellij; then
        local arch
        case "$(uname -m)" in
        x86_64 | amd64) arch="x86_64" ;; aarch64 | arm64) arch="aarch64" ;;
        *) log_err "Unsupported architecture for Zellij: $(uname -m)" ;;
        esac
        local url="https://github.com/zellij-org/zellij/releases/latest/download/zellij-${arch}-unknown-linux-musl.tar.gz"
        curl -fL "$url" | tar xz -C /usr/local/bin
        log_ok "Installed Zellij"
    else log_skip "Zellij already installed"; fi

    # ========== Greenclip (Rofi clipboard manager) ==========
    log_step "Installing and configuring Greenclip"
    if ! have greenclip; then
        local tmp_dir
        tmp_dir="$(mktemp -d)"
        curl -fL "https://github.com/erebe/greenclip/releases/download/v4.2/greenclip" -o "$tmp_dir/greenclip"
        install -m 0755 "$tmp_dir/greenclip" "/usr/local/bin/greenclip"
        rm -rf "$tmp_dir"
        log_ok "Installed Greenclip (v4.2)"
    else
        log_skip "Greenclip already installed"
    fi

    local gc_cfg_dir="$USER_HOME/.config"
    local gc_cfg_file="$gc_cfg_dir/greenclip.toml"
    if [ ! -f "$gc_cfg_file" ]; then
        log_step "Creating ~/.config/greenclip.toml with sane defaults"
        sudo -u "$TARGET_USER" mkdir -p "$gc_cfg_dir"
        cat >"$gc_cfg_file" <<'EOF'
max_history_length = 200
history_file = "~/.cache/greenclip.history"
use_primary_selection_as_input = true
trim_space_from_selection = true
image_support = true
static_history = []
enable_blacklist = false
blacklisted_applications = []
EOF
        chown "$TARGET_USER":"$TARGET_USER" "$gc_cfg_file"
        log_ok "Created default Greenclip config"
    else
        log_skip "Greenclip config already present"
    fi
}

configure_shell() {
    log_step "Configuring Zsh and plugins for user '$TARGET_USER'"
    local zsh_custom_dir="$USER_HOME/.oh-my-zsh/custom"
    if [ ! -d "$USER_HOME/.oh-my-zsh" ]; then
        sudo -u "$TARGET_USER" sh -c 'RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"'
        log_ok "Installed Oh-My-Zsh"
    else log_skip "Oh-My-Zsh already installed"; fi
    install_plugin() {
        local name="$1" repo="$2"
        local dest="$zsh_custom_dir/plugins/$name"
        if [ ! -d "$dest" ]; then
            sudo -u "$TARGET_USER" git clone --depth=1 "$repo" "$dest" >/dev/null 2>&1
            log_ok "Installed Zsh plugin: $name"
        else log_skip "Zsh plugin '$name' already installed"; fi
    }
    install_plugin "zsh-autosuggestions" "https://github.com/zsh-users/zsh-autosuggestions"
    install_plugin "zsh-syntax-highlighting" "https://github.com/zsh-users/zsh-syntax-highlighting"
    install_plugin "zsh-256color" "https://github.com/chrissicool/zsh-256color"
    if [ ! -d "$zsh_custom_dir/themes/powerlevel10k" ]; then
        sudo -u "$TARGET_USER" git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$zsh_custom_dir/themes/powerlevel10k" >/dev/null 2>&1
        log_ok "Installed Powerlevel10k theme"
    else log_skip "Powerlevel10k theme already installed"; fi
    local zshrc_path="$USER_HOME/.zshrc"
    if [ -f "$zshrc_path" ]; then
        if [ ! -f "$zshrc_path.bak.setup" ]; then
            cp "$zshrc_path" "$zshrc_path.bak.setup"
            chown "$TARGET_USER":"$TARGET_USER" "$zshrc_path.bak.setup"
            log_ok "Backed up existing .zshrc"
        fi
        sed -i '/# >>> MANAGED ZSH CONFIG >>>/,/# <<< MANAGED ZSH CONFIG <<</d' "$zshrc_path"
        cat >>"$zshrc_path" <<EOF
# >>> MANAGED ZSH CONFIG >>>
ZSH_THEME="powerlevel10k/powerlevel10k"
plugins=(git sudo zsh-256color zsh-autosuggestions zsh-syntax-highlighting)
eval "\$(starship init zsh)"
export EDITOR="nvim"
export VISUAL="nvim"
# <<< MANAGED ZSH CONFIG <<<
EOF
        chown "$TARGET_USER":"$TARGET_USER" "$zshrc_path"
        log_ok "Configured .zshrc with managed settings"
    else log_skip ".zshrc not found, skipping configuration"; fi
}

install_user_environment() {
    log_step "Setting up user-specific environment (NVM, Fonts)"
    local nvm_dir="$USER_HOME/.nvm"
    if [ ! -d "$nvm_dir" ]; then
        local latest_nvm_ver
        latest_nvm_ver=$(curl -s "https://api.github.com/repos/nvm-sh/nvm/releases/latest" | jq -r .tag_name)
        sudo -u "$TARGET_USER" bash -c "curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/${latest_nvm_ver}/install.sh | bash"
        log_ok "Installed NVM ($latest_nvm_ver)"
        sudo -u "$TARGET_USER" bash -lc "source $nvm_dir/nvm.sh && nvm install node && nvm alias default node"
        log_ok "Installed latest Node.js and set as default"
    else log_skip "NVM already installed"; fi
    if ! sudo -u "$TARGET_USER" bash -c "fc-list | grep -qi 'JetBrainsMono Nerd Font'"; then
        log_step "Installing JetBrainsMono Nerd Font for user '$TARGET_USER'..."
        sudo -u "$TARGET_USER" bash -c '
            set -e
            FONT_DIR="$HOME/.local/share/fonts"
            mkdir -p "$FONT_DIR"
            URL=$(curl -s https://api.github.com/repos/ryanoasis/nerd-fonts/releases/latest | jq -r ".assets[] | select(.name==\"JetBrainsMono.zip\") | .browser_download_url")
            TMP_ZIP="/tmp/JetBrainsMono.zip"
            curl -fL "$URL" -o "$TMP_ZIP"
            unzip -o "$TMP_ZIP" -d "$FONT_DIR"
            rm "$TMP_ZIP"
            fc-cache -f -v >/dev/null
        '
        log_ok "Installed JetBrainsMono Nerd Font"
    else
        log_skip "JetBrainsMono Nerd Font is already installed"
    fi
}

set_system_defaults() {
    log_step "Setting system-wide defaults"
    if have zsh; then chsh -s "$(command -v zsh)" "$TARGET_USER" && log_ok "Set Zsh as default shell"; else log_skip "Zsh not found"; fi
    if have nvim; then update-alternatives --install /usr/bin/editor editor "$(command -v nvim)" 60 && log_ok "Set Neovim as default editor"; else log_skip "Neovim not found"; fi
}

final_cleanup() {
    log_step "Finalizing and cleaning up"
    apt-get -yq upgrade
    apt-get -yq autoremove --purge
    apt-get -yq clean
    log_ok "System is up-to-date and cleaned"
}

print_summary() {
    printf "\n%s%s" "$C_BOLD" "$C_GREEN"
    echo "========================================="
    echo "      Setup Complete!"
    echo "========================================="
    printf "%s" "$C_RESET"
    echo "  ${S_TICK} Tasks Completed: $TASKS_COMPLETED"
    echo "  ${S_SKIP} Tasks Skipped:   $TASKS_SKIPPED"
    printf "\n%s%sACTION REQUIRED:%s A reboot is recommended for all changes to take effect (e.g., docker group membership).\n" "$C_BOLD" "$C_YELLOW" "$C_RESET"
    echo "    sudo reboot"
}

# ========== Main Execution ==========
main() {
    initialize_system
    install_apt_packages
    install_kitty
    configure_kitty_default
    install_standalone_tools
    configure_shell
    install_user_environment
    set_system_defaults
    final_cleanup
    print_summary
}

main "$@"
