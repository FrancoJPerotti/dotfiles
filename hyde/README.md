# 🛠️ My Dotfiles

These are my personal dotfiles, managed with [GNU Stow](https://www.gnu.org/software/stow/). This setup allows me to symlink configuration files and folders into my home directory in a modular and scalable way.

---

## 📦 Structure

Each configuration is placed in its own directory following this structure:

```
dotfiles/
├── zsh/
│   └── .zshrc
├── nvim/
│   └── .config/nvim/...
├── kitty/
│   └── .config/kitty/...
├── Code/
│   └── .config/Code/User/...
├── zed/
│   └── .config/zed/...
└── ...
```

Each of these is a standalone [GNU Stow](https://www.gnu.org/software/stow/manual/stow.html) "package".

---

## ⚙️ Requirements

* [GNU Stow](https://www.gnu.org/software/stow/)
* A Unix-like environment (Linux/macOS)

Install Stow (if not already):

```bash
# On Arch
sudo pacman -S stow

# On Debian/Ubuntu
sudo apt install stow
```

---

## 🚀 Usage

Clone the repo:

```bash
git clone git@github.com:yourusername/dotfiles.git ~/dotfiles
cd ~/dotfiles
```

Then use the included script to stow all packages:

```bash
./stow-all.sh
```

### 🧪 Dry Run

To preview the symlinks that would be created:

```bash
./stow-all.sh --dry-run
```

---

## 🪚 Unstowing (removing symlinks)

To remove a stowed package (e.g., `nvim`):

```bash
cd ~/dotfiles/nvim
stow -D -t ~ .
```

This safely removes the symlinks created by Stow.

---

## 📁 Installing Packages

This repo includes two lists of packages:

* `pkglist.txt` → Official packages (from the Arch \[extra]/\[community]/\[core] repos)
* `aurlist.txt` → AUR packages (community-contributed packages)

### 🛠️ Install Official Packages (pacman)

```bash
sudo pacman -S --needed - < pkglist.txt
```

* `--needed`: skips packages that are already installed
* `- < pkglist.txt`: reads package names from the file

### 🧪 Install AUR Packages (yay)

Make sure you have [yay](https://github.com/Jguer/yay) installed.

```bash
yay -S --needed - < aurlist.txt
```

Or, if that doesn’t work (due to shell behavior), use:

```bash
xargs -a aurlist.txt yay -S --needed
```

### 📌 Tip

After cloning and stowing dotfiles, you can quickly bootstrap your system like this:

```bash
cd ~/dotfiles
./stow-all.sh
sudo pacman -S --needed - < pkglist.txt
xargs -a aurlist.txt yay -S --needed
```

---

## 🧠 Philosophy

* ✅ Keep each config isolated in its own folder
* ✅ Symlink only what you need
* ✅ Make onboarding and restoration simple

