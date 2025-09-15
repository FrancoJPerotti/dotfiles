#!/usr/bin/env bash
set -euo pipefail

# ========== helpers ==========
log() { printf "\n\033[1;36m==> %s\033[0m\n" "$*"; }
err() { printf "\n\033[1;31m[ERROR]\033[0m %s\n" "$*" >&2; }
warn() { printf "\n\033[1;33m[WARN]\033[0m %s\n" "$*" >&2; }
have() { command -v "$1" >/dev/null 2>&1; }

require_root() {
    if [ "$EUID" -ne 0 ]; then
        err "Please run as root: sudo $0"
        exit 1
    fi
}

# ========== preflight ==========
require_root
export DEBIAN_FRONTEND=noninteractive

log "Enable Universe/Multiverse (if not already)"
add-apt-repository -y universe || true
add-apt-repository -y multiverse || true

log "Base update/upgrade + essentials"
apt update
apt install -y ca-certificates curl wget gnupg software-properties-common lsb-release apt-transport-https jq

# ========== APT: core repo installs ==========
APT_PKGS=(
    brightnessctl
    btop
    cliphist
    eog
    evince
    feh
    firefox
    fzf
    git
    kitty
    lxappearance
    maim
    picom
    playerctl
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
    xclip
    zathura
    zathura-pdf-poppler
    zsh
    build-essential
    python3
)

log "Install core APT packages"
apt install -y "${APT_PKGS[@]}"

# ========== GitHub CLI (official repo) ==========
if ! have gh; then
    log "Add GitHub CLI repo & install 'gh'"
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg |
        dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg 2>/dev/null
    chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
        >/etc/apt/sources.list.d/github-cli.list
    apt update && apt install -y gh
else
    log "GitHub CLI already installed"
fi

# ========== VS Code (Microsoft repo) ==========
if ! have code; then
    log "Add Microsoft repo & install VS Code"
    curl -fsSL https://packages.microsoft.com/keys/microsoft.asc |
        gpg --dearmor -o /usr/share/keyrings/packages.microsoft.gpg
    echo "deb [arch=amd64,arm64,armhf signed-by=/usr/share/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" \
        >/etc/apt/sources.list.d/vscode.list
    apt update && apt install -y code
else
    log "VS Code already installed"
fi

# ========== Vivaldi (official repo) ==========
if ! have vivaldi; then
    log "Add Vivaldi repo & install vivaldi-stable"
    curl -fsSL https://repo.vivaldi.com/archive/linux_signing_key.pub |
        gpg --dearmor -o /usr/share/keyrings/vivaldi-browser.gpg
    echo "deb [signed-by=/usr/share/keyrings/vivaldi-browser.gpg arch=amd64] https://repo.vivaldi.com/archive/deb/ stable main" \
        >/etc/apt/sources.list.d/vivaldi-archive.list
    apt update && apt install -y vivaldi-stable
else
    log "Vivaldi already installed"
fi

# ========== Docker Engine (official repo) ==========
if ! have docker; then
    log "Add Docker repo & install Docker Engine + plugins"
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg |
        gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg
    CODENAME="$(. /etc/os-release && echo "$UBUNTU_CODENAME")"
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu ${CODENAME} stable" \
        >/etc/apt/sources.list.d/docker.list
    apt update
    apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    usermod -aG docker "${SUDO_USER:-$USER}" || true
else
    log "Docker already installed"
fi

# ========== Docker Desktop (robust deb fetch) ==========
DOCKER_DESKTOP_URL="https://desktop.docker.com/linux/main/amd64/docker-desktop-amd64.deb"
TMP_DEB="/tmp/docker-desktop.deb"

if dpkg-query -W -f='${Status}' docker-desktop 2>/dev/null | grep -q "install ok installed"; then
    INST_VER="$(dpkg-query -W -f='${Version}\n' docker-desktop 2>/dev/null || true)"
    log "Docker Desktop already installed (version: ${INST_VER})"
else
    log "Fetching Docker Desktop .deb"
    set +e
    curl -fL -z "$TMP_DEB" -o "$TMP_DEB" "$DOCKER_DESKTOP_URL"
    if [ -s "$TMP_DEB" ]; then
        apt install -y "$TMP_DEB" || apt -f install -y
    else
        err "Docker Desktop download failed. Manual install: https://docs.docker.com/desktop/setup/install/linux/ubuntu/"
    fi
    set -e
fi

# ========== Neovim ==========
if ! have nvim; then
    log "Install Neovim via Snap"
    if ! have snap; then
        apt install -y snapd
    fi
    snap install nvim --classic || err "Snap install of neovim failed."
else
    log "Neovim already installed"
fi

# ========== Yazi (Snap) ==========
if ! have yazi; then
    log "Install Yazi via Snap"
    if ! have snap; then
        apt install -y snapd
    fi
    snap install yazi --classic || err "Snap install of yazi failed. Consider manual: https://yazi-rs.github.io/docs/installation/"
else
    log "Yazi already installed"
fi

# ========== Starship (official installer) ==========
if ! have starship; then
    log "Install Starship prompt"
    sudo -u "${SUDO_USER:-$USER}" sh -c 'curl -sS https://starship.rs/install.sh | sh -s -- -y'
else
    log "Starship already installed"
fi

# ========== Zellij (release binary) ==========
if ! have zellij; then
    log "Install Zellij (release binary)"
    ARCH="$(uname -m)"
    case "$ARCH" in
    x86_64 | amd64) ZJ_ARCH="x86_64" ;;
    aarch64 | arm64) ZJ_ARCH="aarch64" ;;
    *) ZJ_ARCH="x86_64" ;;
    esac
    curl -fL "https://github.com/zellij-org/zellij/releases/latest/download/zellij-${ZJ_ARCH}-unknown-linux-musl.tar.gz" |
        tar xz -C /usr/local/bin || err "Zellij install failed. See: https://zellij.dev/documentation/installation.html"
else
    log "Zellij already installed"
fi

# ========== Oh-My-Zsh ==========
if [ ! -d "/home/${SUDO_USER:-$USER}/.oh-my-zsh" ]; then
    log "Install Oh-My-Zsh (unattended)"
    sudo -u "${SUDO_USER:-$USER}" sh -c \
        'RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"'
else
    log "Oh-My-Zsh already present"
fi

# ========== Oh-My-Zsh plugins (autosuggestions + syntax-highlighting + 256color) ==========
USER_HOME="/home/${SUDO_USER:-$USER}"
ZSH_DIR="$USER_HOME/.oh-my-zsh"
ZSH_CUSTOM="$ZSH_DIR/custom"
ZSHRC="$USER_HOME/.zshrc"

if [ -d "$ZSH_DIR" ]; then
    log "Ensuring Oh-My-Zsh plugins are installed"
    install_plugin() {
        local name="$1"
        local repo="$2"
        local dest="$ZSH_CUSTOM/plugins/$name"

        if [ ! -d "$dest" ]; then
            log "Cloning $name"
            sudo -u "${SUDO_USER:-$USER}" mkdir -p "$ZSH_CUSTOM/plugins"
            sudo -u "${SUDO_USER:-$USER}" git clone --depth=1 "$repo" "$dest"
        else
            log "$name already installed"
        fi
    }
    install_plugin "zsh-autosuggestions" "https://github.com/zsh-users/zsh-autosuggestions"
    install_plugin "zsh-syntax-highlighting" "https://github.com/zsh-users/zsh-syntax-highlighting"
    install_plugin "zsh-256color" "https://github.com/chrissicool/zsh-256color"

    # Ensure ZSH_CUSTOM is exported in the user's shell (only if missing)
    if ! grep -q '^[[:space:]]*export[[:space:]]\+ZSH_CUSTOM=' "$ZSHRC" 2>/dev/null; then
        log "Declaring ZSH_CUSTOM in ~/.zshrc"
        echo 'export ZSH_CUSTOM="${ZSH_CUSTOM:-$ZSH/custom}"' >>"$ZSHRC"
        chown "${SUDO_USER:-$USER}":"${SUDO_USER:-$USER}" "$ZSHRC"
    fi

    # Desired plugins line (highlighting must be last)
    DESIRED_PLUGINS='plugins=(git sudo zsh-256color zsh-autosuggestions zsh-syntax-highlighting)'

    # Backup once if not yet backed up
    if [ -f "$ZSHRC" ] && ! grep -q "# backup by install script" "$ZSHRC"; then
        cp -a "$ZSHRC" "$ZSHRC.bak" && echo "# backup by install script" >>"$ZSHRC.bak"
        chown "${SUDO_USER:-$USER}":"${SUDO_USER:-$USER}" "$ZSHRC.bak"
        log "Backed up ~/.zshrc to ~/.zshrc.bak"
    fi

    if [ -f "$ZSHRC" ]; then
        if grep -q '^[[:space:]]*plugins=(' "$ZSHRC"; then
            log "Updating existing plugins= line in ~/.zshrc"
            sed -i -E "s|^[[:space:]]*plugins=\(.*\)|$DESIRED_PLUGINS|" "$ZSHRC"
        elif grep -q 'oh-my-zsh\.sh' "$ZSHRC"; then
            log "Inserting plugins= before \"oh-my-zsh.sh\" in ~/.zshrc"
            awk -v ins="$DESIRED_PLUGINS" '
                BEGIN{done=0}
                /oh-my-zsh\.sh/ && !done { print ins; done=1 }
                { print }
            ' "$ZSHRC" >"$ZSHRC.tmp" && mv "$ZSHRC.tmp" "$ZSHRC"
        else
            log "Appending managed plugin block to ~/.zshrc"
            cat >>"$ZSHRC" <<'EOF'
# >>> managed: oh-my-zsh plugins >>>
export ZSH="${ZSH:-$HOME/.oh-my-zsh}"
export ZSH_CUSTOM="${ZSH_CUSTOM:-$ZSH/custom}"
plugins=(git sudo zsh-256color zsh-autosuggestions zsh-syntax-highlighting)
# <<< managed: oh-my-zsh plugins <<<
EOF
        fi
        chown "${SUDO_USER:-$USER}":"${SUDO_USER:-$USER}" "$ZSHRC"
    else
        err "~/.zshrc not found; create one to load oh-my-zsh and plugins."
    fi
else
    warn "Oh-My-Zsh directory not found at $ZSH_DIR; skipping plugin install step."
fi

# ========== Powerlevel10k theme ==========
ZSH_CUSTOM="/home/${SUDO_USER:-$USER}/.oh-my-zsh/custom"
if [ ! -d "$ZSH_CUSTOM/themes/powerlevel10k" ]; then
    log "Install Powerlevel10k (theme)"
    sudo -u "${SUDO_USER:-$USER}" git clone --depth=1 https://github.com/romkatv/powerlevel10k.git \
        "$ZSH_CUSTOM/themes/powerlevel10k"
    log 'Remember to set ZSH_THEME="powerlevel10k/powerlevel10k" in your ~/.zshrc'
else
    log "Powerlevel10k already present"
fi

# ========== NVM / Node.js (per-user, latest) ==========
TARGET_USER="${SUDO_USER:-$USER}"

# Remove conflicting system Node (APT/Snap) so PATH resolves to NVM's Node
if dpkg -l | grep -qE '^ii\s+nodejs\b' || dpkg -l | grep -qE '^ii\s+npm\b'; then
    log "Removing system nodejs/npm from APT to avoid conflicts with NVM"
    apt remove -y --purge nodejs npm || true
fi
if command -v snap >/dev/null 2>&1 && snap list 2>/dev/null | grep -qE '^node\s'; then
    log "Removing Snap 'node' to avoid PATH conflicts with NVM"
    snap remove node || true
fi

# Install NVM for the target user if missing
if ! sudo -u "$TARGET_USER" bash -lc 'command -v nvm >/dev/null 2>&1'; then
    log "Installing NVM for $TARGET_USER"
    sudo -u "$TARGET_USER" bash -lc '
        export NVM_DIR="$HOME/.nvm"
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
    '
else
    log "NVM already installed for $TARGET_USER"
fi

# Load NVM and install latest Node; set as default
log "Installing latest Node.js via NVM for $TARGET_USER"
sudo -u "$TARGET_USER" bash -lc '
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
    nvm install node
    nvm alias default node
    nvm use default
    corepack enable >/dev/null 2>&1 || true  # yarn/pnpm shims if needed
    echo "Node: $(node -v) | npm: $(npm -v)"
'

# ========== Greenclip (Rofi clipboard manager) ==========
TARGET_USER="${SUDO_USER:-$USER}"
USER_HOME="/home/$TARGET_USER"
GC_BIN="/usr/local/bin/greenclip"
GC_CFG_DIR="$USER_HOME/.config"
GC_CFG_FILE="$GC_CFG_DIR/greenclip.toml"
USR_SD_UNIT="$USER_HOME/.config/systemd/user/greenclip.service"

# 1) Install binary (pinned version, adjust if you want newer)
if ! have greenclip; then
    log "Install Greenclip (latest release binary)"
    TMP_DIR="$(mktemp -d)"
    curl -fL "https://github.com/erebe/greenclip/releases/download/v4.2/greenclip" -o "$TMP_DIR/greenclip"
    install -m 0755 "$TMP_DIR/greenclip" "$GC_BIN"
    rm -rf "$TMP_DIR"
else
    log "Greenclip already installed"
fi

# 2) Minimal config
if [ ! -f "$GC_CFG_FILE" ]; then
    log "Creating ~/.config/greenclip.toml with sane defaults"
    sudo -u "$TARGET_USER" mkdir -p "$GC_CFG_DIR"
    cat >"$GC_CFG_FILE" <<'EOF'
max_history_length = 200
history_file = "~/.cache/greenclip.history"
use_primary_selection_as_input = true
trim_space_from_selection = true
image_support = true
static_history = []
enable_blacklist = false
blacklisted_applications = []
EOF
    chown "$TARGET_USER":"$TARGET_USER" "$GC_CFG_FILE"
else
    log "Greenclip config already present"
fi

# ========== Nerd Fonts: JetBrainsMono (latest, ALL styles/weights) ==========
TARGET_USER="${SUDO_USER:-$USER}"
USER_HOME="/home/$TARGET_USER"
DEST="$USER_HOME/.local/share/fonts/JetBrainsMonoNF"

if ! fc-list | grep -qi 'JetBrainsMono Nerd Font'; then
    log "Install JetBrainsMono Nerd Font (latest, all TTFs)"
    mkdir -p "$DEST"

    # Find latest tag and JetBrainsMono asset (prefer .tar.xz, fallback to .zip)
    VER="$(curl -s https://api.github.com/repos/ryanoasis/nerd-fonts/releases/latest | jq -r '.tag_name')"
    ASSETS_JSON="$(curl -s "https://api.github.com/repos/ryanoasis/nerd-fonts/releases/tags/${VER}")"

    URL="$(echo "$ASSETS_JSON" | jq -r '.assets[] | select(.name=="JetBrainsMono.tar.xz") | .browser_download_url')"
    ARCHIVE_TYPE="txz"
    if [ -z "$URL" ] || [ "$URL" = "null" ]; then
        URL="$(echo "$ASSETS_JSON" | jq -r '.assets[] | select(.name=="JetBrainsMono.zip") | .browser_download_url')"
        ARCHIVE_TYPE="zip"
    fi
    [ -n "$URL" ] || { err "Could not find JetBrainsMono asset in Nerd Fonts ${VER}"; }

    TMP="$(mktemp -d)"
    trap 'rm -rf "$TMP"' EXIT

    log "Downloading JetBrainsMono (${VER})"
    curl -fL "$URL" -o "$TMP/pkg"

    log "Extracting all TTFs to $DEST"
    case "$ARCHIVE_TYPE" in
    txz)
        # extract only *.ttf files (keeps things clean)
        tar -tf "$TMP/pkg" | grep -Ei '\.ttf$' | while read -r path; do
            tar -xJf "$TMP/pkg" -C "$TMP" "$path"
            install -m 0644 "$TMP/$path" "$DEST/"
        done
        ;;
    zip)
        unzip -j "$TMP/pkg" '*.ttf' -d "$DEST"
        ;;
    esac

    chown -R "$TARGET_USER:$TARGET_USER" "$DEST"
    fc-cache -fv "$DEST"
    log "JetBrainsMono Nerd Font installed."
else
    log "JetBrainsMono Nerd Font already installed"
fi

# ========== Defaults ==========
# Default shell: Zsh
if [ "$SHELL" != "$(command -v zsh)" ]; then
    log "Setting Zsh as default shell for ${SUDO_USER:-$USER}"
    chsh -s "$(command -v zsh)" "${SUDO_USER:-$USER}" ||
        err "Failed to set zsh as default shell. You may need: chsh -s $(command -v zsh)"
else
    log "Zsh is already the default shell"
fi

# Default editor: Neovim
if command -v nvim >/dev/null; then
    log "Setting Neovim as default editor"
    update-alternatives --install /usr/bin/editor editor "$(command -v nvim)" 60
    update-alternatives --set editor "$(command -v nvim)"
    ZSHRC="/home/${SUDO_USER:-$USER}/.zshrc"
    grep -q 'EDITOR=' "$ZSHRC" 2>/dev/null ||
        echo 'export EDITOR="nvim"; export VISUAL="nvim"' >>"$ZSHRC"
else
    log "Neovim not found, skipping default editor setup"
fi

# Default terminal emulator: Kitty
if command -v kitty >/dev/null; then
    log "Registering Kitty as default terminal emulator"
    update-alternatives --install /usr/bin/x-terminal-emulator x-terminal-emulator "$(command -v kitty)" 50
    update-alternatives --set x-terminal-emulator "$(command -v kitty)"
else
    log "Kitty not found, skipping default terminal setup"
fi

log "Browser default not set automatically. To set Vivaldi as default later:"
log "    xdg-settings set default-web-browser vivaldi-stable.desktop"

# ========== Final update ==========
log "Final apt update/upgrade and cleanup"
apt update
apt -y upgrade
apt -y autoremove

log "All done! Log out/in so group changes (docker) take effect."
