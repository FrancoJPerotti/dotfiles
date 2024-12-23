# My Dotfiles

This directory contains my dotfiles that are located in my $HOME directory and in .config/ directory. 

I use [GNU Stow](https://www.gnu.org/software/stow/) to manage them.

## Requirements

Ensure that the following packages are installed on your system:

### Git

```bash
sudo pacman -S git
```
### Stow

```bash
sudo pacman -S stow
```

## Installation

First, clone the dotfiles repo in your $HOME directory using git:

```bash
$ git clone git@github.com:FrancoPerotti/dotfiles.git
$ cd dotfiles
```
Back up your existing dotfiles by moving them to a different directory:

```bash
$ mkdir ~/dotfiles_backup
$ mv {EXISTING_DOTFILE} ~/dotfiles_backup
```

Then, use GNU stow to create the symlinks:

```bash
$ stow .
```

If everything went well, you should see the symlinks in your $HOME directory and in .config/ directory.

Now you can delete the backup directory, if you want:

```bash
$ rm -rf ~/dotfiles_backup
```
This is a useful YouTube video that explains the whole process:

[Stow has forever changed the way I manage my dotfiles](https://www.youtube.com/watch?v=y6XCebnB9gs)
