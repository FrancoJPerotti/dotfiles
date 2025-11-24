# TODO: Dotfiles Repository Improvements

This document tracks potential improvements, enhancements, and fixes for the dotfiles repository.

## 🔥 High Priority

### Documentation
- [x] Update README.md author information (replace placeholder `[Your Name]` with actual name) ✅ (2025-11-17)
- [x] Add troubleshooting section to README for common issues ✅ (2025-11-17)
- [ ] Document dependencies and prerequisites more clearly per profile
- [ ] Add screenshots/demos of the configured desktop environment

### Code Quality & Maintenance
- [x] Install and run shellcheck on all shell scripts to identify potential issues ✅ (2025-11-17)
  - Fixed stow-manager (now shellcheck-clean)
  - Generated SHELLCHECK_REPORT.md with findings
  - **ALL 31 ISSUES FIXED - 100% SHELLCHECK CLEAN!** 🎉
  - 14 files modified, 34/34 scripts now pass shellcheck
- [x] Make all `.sh` scripts executable (`chmod +x`) ✅ (2025-11-17)
  - All 32 active scripts are now executable
  - Removed obsolete hyde/stow-all.sh wrapper (was calling deleted script)
- [x] Decide on deprecation path: either remove `stow-all.sh` or `stow-manager` (they duplicate functionality) ✅ (2025-11-17)
  - Removed stow-all.sh in favor of stow-manager
- [x] Consolidate `install.sh` and `install_v2.sh` in ubuntu/ (having two install scripts is confusing) ✅ (2025-11-17)
  - Merged into single install.sh with best features of both
  - Added error handling, progress tracking, and repair functionality
  - Old version preserved as install_old.sh for reference
- [x] Add error handling and logging to installation scripts ✅ (2025-11-17)
  - Implemented err_trap for automatic error handling
  - Added modular logging functions (log_step, log_ok, log_skip, log_err)
- [x] Create unified logging function across all scripts ✅ (2025-11-17)
  - Consolidated install.sh now has consistent logging patterns

### Script Improvements
- [ ] Add rollback functionality to installation scripts in case of failure
- [ ] Implement idempotent installation (safe to run multiple times)
- [ ] Add version checking for installed tools to avoid reinstalling
- [x] Create uninstall/removal scripts for packages and configurations ✅ (2025-11-17)
  - Renamed install.sh to setup.sh
  - Added --install and --uninstall modes
  - Added --keep-configs option to preserve user configurations

## 📦 Medium Priority

### Repository Structure
- [ ] Consider adding a `docs/` directory for extended documentation
- [ ] Add `.editorconfig` file for consistent coding style
- [ ] Create a `bin/` or `scripts/` directory at root level for management scripts
- [ ] Consider splitting large configuration files into modular includes
- [ ] Evaluate if vivaldi configuration should remain in `.stow-exclude` or be documented

### Testing & CI/CD
- [ ] Add pre-commit hooks for bash script validation
- [ ] Extend GitHub Actions to test installation scripts in containers
- [ ] Add automated tests for custom scripts functionality
- [ ] Test stow operations across different directory structures
- [ ] Add linting for Lua files (nvim configuration)
- [ ] Test compatibility across different Ubuntu/Arch versions

### Profile Management
- [ ] Add support for custom/work profiles as documented but not implemented
- [ ] Create profile-specific documentation for each (arch/ubuntu/common)
- [ ] Document package lists (pkglist.txt, aurlist.txt) and their usage
- [ ] Add automated package list generation/update scripts
- [ ] Consider adding a Fedora/RHEL profile for broader support
- [ ] Add macOS support/profile (if applicable)

### Installation Scripts
- [ ] Add interactive mode to installation scripts (ask before each step)
- [ ] Implement dry-run mode for installation scripts
- [ ] Add progress indicators for long-running operations
- [ ] Check disk space before installing packages
- [ ] Add bandwidth checking/resumable downloads for large packages
- [ ] Implement better error messages with suggestions for fixes

## 🔧 Low Priority / Nice to Have

### Features
- [ ] Add automatic backup of existing configurations before stowing
- [ ] Create a dotfiles update script to pull latest configs and restow
- [ ] Add support for encrypted secrets management (e.g., using git-crypt)
- [ ] Create a bootstrap script that runs on fresh system install
- [ ] Add support for platform-specific overrides (laptop vs desktop configs)
- [ ] Implement configuration templating for user-specific values
- [ ] Add migration scripts for major configuration changes

### User Experience
- [ ] Add colored output consistently across all scripts
- [ ] Create interactive setup wizard for first-time users
- [ ] Add command completion for custom scripts (bash/zsh)
- [ ] Create man pages for custom scripts
- [ ] Add ASCII art banner to installation scripts
- [ ] Implement configuration validation before applying changes

### Script Organization
- [ ] Extract common functions into a shared library file
- [ ] Standardize script headers (description, usage, dependencies)
- [ ] Add usage examples to all scripts
- [ ] Create helper script to manage stow operations (already exists but could be enhanced)
- [ ] Document all environment variables used across scripts

### Specific Application Configs
- [ ] Review and optimize nvim configuration for performance
- [ ] Document custom nvim plugins and their purposes
- [ ] Add more rofi themes and document how to switch
- [ ] Create polybar theme variants
- [ ] Document i3/Hyprland keybindings in separate reference file
- [ ] Add picom configuration presets (performance vs eye-candy)

### Package Management
- [ ] Create script to diff package lists between two systems
- [ ] Add script to export currently installed packages
- [ ] Implement package groups (essential, optional, development, etc.)
- [ ] Add automatic cleanup of orphaned packages
- [ ] Document minimal vs full installation options

### Dependencies & Tools
- [ ] Evaluate replacing greenclip with cliphist consistently
- [ ] Document why both Docker Engine and Docker Desktop are installed
- [ ] Consider using chezmoi or dotbot as alternatives to stow
- [ ] Add support for Nix package manager
- [ ] Evaluate using asdf for version management instead of NVM

## 📝 Documentation Improvements

### README Enhancements
- [ ] Add table of contents with anchor links
- [ ] Create quick start guide (3-5 steps max)
- [ ] Add "Philosophy" or "Design Decisions" section
- [ ] Document backup and restore procedures
- [ ] Add FAQ section
- [ ] Create comparison table of arch vs ubuntu profiles
- [ ] Add badges for build status, license, version

### Code Documentation
- [ ] Add inline comments to complex script sections
- [ ] Document Python script in stow-manager (tree visualization)
- [ ] Create architecture diagram showing how components interact
- [ ] Document stow conflict resolution strategy
- [ ] Add examples of common use cases

### Video Tutorials
- [ ] Create screen recording of fresh installation
- [ ] Record walkthrough of stow process
- [ ] Demo custom scripts in action
- [ ] Show before/after of configuration application

## 🔐 Security & Best Practices

- [ ] Audit all curl/wget commands for security (use HTTPS, verify checksums)
- [ ] Pin specific versions for critical software instead of "latest"
- [ ] Add GPG signature verification where available
- [ ] Review file permissions set by scripts
- [ ] Audit sudo usage - minimize privileged operations
- [ ] Add warning when running scripts as root
- [ ] Implement sandboxing for untrusted operations
- [ ] Document security considerations in README

## 🐛 Known Issues & Bugs

- [ ] Investigate Docker Desktop download logic (uses -z flag but might not handle updates correctly)
- [ ] Fix potential race condition in NVM installation
- [ ] Review font installation - might fail if fc-cache is not available
- [ ] Check for conflicts between system packages and manual installs
- [ ] Test behavior when $SUDO_USER is not set
- [ ] Verify Oh-My-Zsh plugin paths are created before cloning
- [ ] Handle case where ~/.zshrc doesn't exist during plugin installation

## ♻️ Refactoring & Cleanup

- [ ] Remove duplicate code between install.sh and install_v2.sh
- [ ] Standardize variable naming conventions (snake_case vs UPPER_CASE)
- [ ] Use consistent quoting style throughout scripts
- [ ] Replace deprecated commands (update-alternatives usage)
- [ ] Modernize bash syntax (use [[ ]] instead of [ ])
- [ ] Remove unused scripts or move to archive/
- [ ] Clean up temporary files in all scripts
- [ ] Use trap for cleanup in all scripts that create temp files

## 🧪 Testing Checklist

- [ ] Test on fresh Ubuntu 24.04 LTS install
- [ ] Test on fresh Ubuntu 22.04 LTS install
- [ ] Test on Arch Linux
- [ ] Test on EndeavourOS
- [ ] Test with different users (non-root, root)
- [ ] Test with existing configurations (conflict handling)
- [ ] Test unstow operations
- [ ] Test with network failures (resume capability)
- [ ] Test with insufficient disk space
- [ ] Test with missing dependencies

## 🎯 Future Goals

- [ ] Create a web-based configuration generator
- [ ] Build a TUI (Terminal UI) for managing dotfiles
- [ ] Add support for cloud sync (Dropbox, NextCloud)
- [ ] Create Docker image with pre-configured environment
- [ ] Build a plugin system for extending functionality
- [ ] Add telemetry (opt-in) to understand usage patterns
- [ ] Create community repository of contributed configs
- [ ] Add A/B testing for different configuration approaches

## 📊 Metrics & Analytics

- [ ] Track installation success rate
- [ ] Measure average installation time
- [ ] Monitor which packages are most commonly excluded
- [ ] Track which profiles are most popular
- [ ] Measure configuration load times
- [ ] Collect feedback from users

---

## Notes

- Items can be moved between priority levels as needs change
- Check off items as they're completed
- Add new items as they're discovered
- Link related issues/PRs when addressing items
- Review and update this list regularly (monthly/quarterly)

**Last Updated:** 2025-01-16
