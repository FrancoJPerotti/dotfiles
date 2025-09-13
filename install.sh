#!/usr/bin/env bash
set -euo pipefail

# ========== helpers ==========
log() { printf "\n\033[1;36m==> %s\033[0m\n" "$*"; }
err() { printf "\n\033[1;31m[ERROR]\033[0m %s\n" "$*" >&2; }
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
apt install -y ca-certificates curl wget gnupg software-properties-common lsb-release apt-transport-https

# ========== APT: core repo installs ==========
APT_PKGS=(
    # your yes-list available via Ubuntu repos
    btop
    cliphist
    eog
    evince
    firefox
    git
    jq
    kitty
    neovim
    npm
    rofi
    stow
    tmux
    tree
    unzip
    vim
    zathura
    zathura-pdf-poppler
    zsh
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
    apt update
    apt install -y gh
else
    log "GitHub CLI already installed"
fi

# ========== VS Code (Microsoft repo) ==========
if ! have code; then
    log "Add Microsoft repo & install VS Code"
    curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor -o /usr/share/keyrings/packages.microsoft.gpg
    echo "deb [arch=amd64,arm64,armhf signed-by=/usr/share/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" \
        >/etc/apt/sources.list.d/vscode.list
    apt update
    apt install -y code
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
    apt update
    apt install -y vivaldi-stable
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

# ========== Docker Desktop (optional) ==========
if ! command -v com.docker.backend &>/dev/null; then
    log "Attempting Docker Desktop install (.deb)"
    TMP_DEB="/tmp/docker-desktop.deb"
    set +e
    wget -O "$TMP_DEB" "https://desktop.docker.com/linux/main/amd64/docker-desktop-latest-amd64.deb"
    if [ -s "$TMP_DEB" ]; then
        apt install -y "$TMP_DEB" || apt -f install -y
    else
        err "Could not fetch Docker Desktop .deb automatically. Install manually: https://docs.docker.com/desktop/install/linux/"
    fi
    set -e
else
    log "Docker Desktop already appears installed"
fi

# ========== Yazi (Snap fallback) ==========
if ! have yazi; then
    log "Install Yazi via Snap (classic confinement)"
    if ! have snap; then
        apt install -y snapd
    fi
    snap install yazi --classic || err "Snap install of yazi failed. Consider manual: https://yazi-rs.github.io/docs/installation/"
else
    log "Yazi already installed"
fi

# ========== Zed (download .deb) ==========
if ! have zed; then
    log "Install Zed editor (.deb)"
    ZED_DEB="/tmp/zed.deb"
    set +e
    wget -O "$ZED_DEB" "https://zed.dev/api/releases/latest/zed-linux-deb"
    if [ -s "$ZED_DEB" ]; then
        apt install -y "$ZED_DEB" || apt -f install -y
    else
        err "Could not fetch Zed .deb automatically. Download from https://zed.dev and install with: sudo apt install ./zed*.deb"
    fi
    set -e
else
    log "Zed already installed"
fi

# ========== satty ==========
if ! have satty; then
    log "Install satty (screenshot annotator) - trying snap first"
    if have snap; then
        snap install satty || err "Snap install of satty failed. Install manually: https://github.com/satty-io/satty/releases"
    else
        err "Snap not present; either install snapd or install satty manually from releases."
    fi
else
    log "satty already installed"
fi

# ========== Starship (official installer) ==========
if ! have starship; then
    log "Install Starship prompt"
    # -y to auto-confirm
    sudo -u "${SUDO_USER:-$USER}" sh -c 'curl -sS https://starship.rs/install.sh | sh -s -- -y'
else
    log "Starship already installed"
fi

# ========== Zellij (release binary) ==========
if ! have zellij; then
    log "Install Zellij (release binary)"
    curl -L "https://github.com/zellij-org/zellij/releases/latest/download/zellij-$(uname -m)-unknown-linux-musl.tar.gz" |
        tar xz -C /usr/local/bin || {
        # fallback to x86_64 filename if arch mapping differs
        curl -L "https://github.com/zellij-org/zellij/releases/latest/download/zellij-x86_64-unknown-linux-musl.tar.gz" |
            tar xz -C /usr/local/bin || err "Zellij install failed. See: https://github.com/zellij-org/zellij/releases"
    }
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

# ========== Final update ==========
log "Final apt update/upgrade and cleanup"
apt update
apt -y upgrade
apt -y autoremove

log "All done! Log out/in so group changes (docker) take effect."
