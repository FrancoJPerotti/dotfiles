# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# --- Oh My Zsh ---
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"
plugins=(git sudo zsh-256color zsh-autosuggestions zsh-syntax-highlighting)
source "$ZSH/oh-my-zsh.sh"

# --- Command-not-found (Ubuntu way) ---
if [[ -r /etc/zsh_command_not_found ]]; then
  source /etc/zsh_command_not_found
else
  function command_not_found_handler {
    local purple='\e[1;35m' bright='\e[0;1m' green='\e[1;32m' reset='\e[0m'
    printf 'zsh: command not found: %s\n' "$1"
    if command -v /usr/lib/command-not-found >/dev/null 2>&1; then
      /usr/lib/command-not-found "$1"; return 127
    elif command -v apt-file >/dev/null 2>&1; then
      local hits
      hits="$(apt-file search -x "(^|/)bin/${1}$" 2>/dev/null)"
      if [[ -n "$hits" ]]; then
        printf "${bright}%s${reset} may be found in the following packages:\n" "$1"
        echo "$hits" | awk -F: -v p="$purple" -v b="$bright" -v g="$green" -v r="$reset" \
          '{ pkg=$1; path=$2; printf "%s%s %s%s\n    %s\n", p, pkg, g, "(apt)", r, path }'
      else
        printf "Tip: install ${bright}apt-file${reset} and run ${green}sudo apt-file update${reset}.\n"
      fi
    else
      printf "Install ${bright}command-not-found${reset} or ${bright}apt-file${reset} for suggestions.\n"
    fi
    return 127
  }
fi

# --- Package install helper (Ubuntu) ---
function in {
  if [[ $# -eq 0 ]]; then echo "Usage: in <pkg> [pkg2 ...]"; return 1; fi
  local -a apt_pkgs=() unknown=()
  for pkg in "$@"; do
    if apt-cache show "$pkg" >/dev/null 2>&1; then
      apt_pkgs+=("$pkg")
    else
      unknown+=("$pkg")
    fi
  done
  if (( ${#apt_pkgs[@]} )); then
    sudo apt update && sudo apt install -y "${apt_pkgs[@]}"
  fi
  if (( ${#unknown[@]} )); then
    echo "Trying apt for: ${unknown[*]} (use snap/flatpak if needed)"
    sudo apt install -y "${unknown[@]}" 2>/dev/null || true
  fi
}

# --- Helpful aliases ---
alias  c='clear'
alias  l='eza -lh  --icons=auto'
alias ls='eza -1   --icons=auto'
alias ll='eza -lha --icons=auto --sort=name --group-directories-first'
alias ld='eza -lhD --icons=auto'
alias lt='eza --icons=auto --tree'

alias un='sudo apt remove --purge'
alias up='sudo apt update && sudo apt -y full-upgrade'
alias pl='dpkg -l | grep -i'
alias pa='apt search'
alias pc='sudo apt -y autoremove --purge && sudo apt clean'
alias po='sudo apt -y autoremove'

alias vc='code'
alias h='cd ~'

# --- cd shortcuts ---
alias ..='cd ..'
alias ...='cd ../..'
alias .3='cd ../../..'
alias .4='cd ../../../..'
alias .5='cd ../../../../..'

alias mkdir='mkdir -p'

# Powerlevel10k prompt
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# PATHs
export PATH="$PATH:$HOME/.local/bin"
export PATH="$HOME/.cargo/bin:$PATH"
export EDITOR='nvim'

# --- Yazi integration ---
function y() {
  local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
  yazi "$@" --cwd-file="$tmp"
  IFS= read -r -d '' cwd < "$tmp"
  [[ -n "$cwd" && "$cwd" != "$PWD" ]] && builtin cd -- "$cwd"
  rm -f -- "$tmp"
}

# --- NVM ---
export NVM_DIR="$HOME/.nvm"
[[ -s "$NVM_DIR/nvm.sh" ]] && . "$NVM_DIR/nvm.sh"
[[ -s "$NVM_DIR/bash_completion" ]] && . "$NVM_DIR/bash_completion"

function nvim() {
    local dest_dir=$PWD
    if (( $# )); then
        for arg in "$@"; do
            [[ "$arg" == [+-]* ]] && continue
            local abs=${arg:A}
            if [[ -d $abs ]]; then
                dest_dir=$abs
            else
                dest_dir=${abs:h}
            fi
            break
        done
    fi
    local short=${dest_dir/#$HOME/~}

    # Build the kitty command safely
    local -a cmd=(
        kitty --single-instance
        --class nvim
        --title "nvim:${short}"
        --working-directory "${dest_dir}"
        nvim "$@"
    )

    # Launch via i3 (note: --no-startup-id, not --)
    i3-msg -q "exec --no-startup-id $(printf '%q ' "${cmd[@]}")"
}

# --- Google Meet launcher ---
function meet() {
  if [ $# -lt 2 ]; then echo "Usage: meet <college|work> <link|code>"; return 1; fi
  local profile="$1" link="$2" code
  case "$link" in
    https://meet.google.com/*) code="${link##*/}"; code="${code%%\?*}" ;;
    *) code="$link" ;;
  esac
  local url="https://meet.google.com/$code"
  case "$profile" in
    college) url="$url?authuser=1" ;;
    work)    url="$url?authuser=2" ;;
    *) echo "Invalid profile. Use 'college' or 'work'."; return 1 ;;
  esac

  if command -v vivaldi-stable >/dev/null 2>&1; then
    vivaldi-stable --app="$url" &
  elif [[ -x /opt/vivaldi/vivaldi ]]; then
    /opt/vivaldi/vivaldi --app="$url" &
  elif command -v xdg-open >/dev/null 2>&1; then
    xdg-open "$url" >/dev/null 2>&1 &
  else
    echo "Open this URL: $url"
  fi
}
export ZSH_CUSTOM="${ZSH_CUSTOM:-$ZSH/custom}"
# backup by install script
