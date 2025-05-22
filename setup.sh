#!/bin/bash
# Suckless Desktop Environment Setup Script
# Edit the configuration section below to customize your setup

set -e

#
# CONFIGURATION - Edit these arrays to customize your setup
#

# Essential X11 and build packages (required - don't remove)
ESSENTIAL_PACKAGES=(
    "build-essential"
    "git" 
    "libx11-dev"
    "libxft-dev"
    "libxinerama-dev" 
    "libxrandr-dev"
    "libimlib2-dev"
    "xorg"
    "xinit"
    "pkg-config"
)

# Window manager and compositor packages (easily removable)
WM_PACKAGES=(
    "feh"           # wallpaper setter
    "picom"         # compositor
)

# Audio packages (empty array = no audio support)
AUDIO_PACKAGES=(
    "pulseaudio"
    "alsa-utils"
)

# Network packages (empty array = no network tools)
NETWORK_PACKAGES=(
    "network-manager"
)

# Application packages (empty array = no additional apps)
# Common additions: emacs, vim, git-gui, etc.
APP_PACKAGES=(
    "firefox-esr"
    "nano"
)

# Suckless tools to install from source
SUCKLESS_TOOLS=(
    "dwm"
    "st" 
    "dmenu"
    "slock"
    "slstatus"
)

# GPU driver configuration
# Options: "auto", "nvidia", "amd", "intel", or "" (empty for no drivers)
GPU_DRIVER="auto"

# GPU driver packages
NVIDIA_PACKAGES=("nvidia-driver" "firmware-misc-nonfree")
AMD_PACKAGES=("firmware-amd-graphics" "libgl1-mesa-dri") 
INTEL_PACKAGES=("intel-media-va-driver" "mesa-va-drivers")

# Directories and paths
SUCKLESS_DIR="$HOME/.local/src"
WALLPAPER_PATH="$HOME/.wallpaper"

# Default applications (change to your preference)
DEFAULT_EDITOR="nano"
DEFAULT_BROWSER="firefox"
DEFAULT_TERMINAL="st"

# Wallpaper configuration
WALLPAPER_SIZE="1920x1080"

# Enable auto-start X on tty1 (1 = enable, 0 = disable)
AUTO_START_X=1

#
# DOTFILE TEMPLATES - Customize as needed
#

generate_xinitrc() {
    cat > "$HOME/.xinitrc" << 'EOF'
#!/bin/sh
# Set wallpaper
feh --bg-scale ~/.wallpaper 2>/dev/null &

# Start compositor  
picom -b 2>/dev/null &

# Start status bar
slstatus 2>/dev/null &

# Start window manager
exec dwm
EOF
    chmod +x "$HOME/.xinitrc"
}

generate_profile() {
    cat > "$HOME/.profile" << EOF
# Local binaries
export PATH="\$HOME/.local/bin:\$PATH"

# Default applications
export EDITOR=$DEFAULT_EDITOR
export BROWSER=$DEFAULT_BROWSER
export TERMINAL=$DEFAULT_TERMINAL

# Auto-start X on tty1 (comment out if you don't want this)
EOF
    
    if [ "$AUTO_START_X" = "1" ]; then
        echo '[ -z "$DISPLAY" ] && [ "$XDG_VTNR" = 1 ] && exec startx' >> "$HOME/.profile"
    fi
}

generate_bashrc() {
    cat > "$HOME/.bashrc" << 'EOF'
# Source system bashrc
[ -f /etc/bashrc ] && . /etc/bashrc

# Source profile
[ -f ~/.profile ] && . ~/.profile

# Prompt
PS1='\u@\h:\w$ '

# History
HISTSIZE=1000
HISTCONTROL=ignoreboth

# Aliases
alias ls='ls --color=auto'
alias ll='ls -la'
alias la='ls -A'
alias l='ls -CF'
alias grep='grep --color=auto'
alias ..='cd ..'
alias ...='cd ../..'

# Custom aliases - add your own below
# alias open='xdg-open'
# alias battery='cat /sys/class/power_supply/BAT0/capacity'
EOF
}

#
# FUNCTIONS - Generally no need to edit below this line
#

msg() { 
    echo "==> $*" 
}

create_simple_wallpaper() {
    msg "Creating default wallpaper"
    # Create a simple 1x1 black pixel that feh can scale
    printf '\x00\x00\x00' > "$WALLPAPER_PATH"
}

detect_and_install_gpu_drivers() {
    [ -z "$GPU_DRIVER" ] && return
    
    case "$GPU_DRIVER" in
        "auto")
            if lspci | grep -qi nvidia; then
                msg "Auto-detected NVIDIA GPU, installing drivers"
                sudo apt install -y "${NVIDIA_PACKAGES[@]}"
            elif lspci | grep -qi amd; then
                msg "Auto-detected AMD GPU, installing drivers" 
                sudo apt install -y "${AMD_PACKAGES[@]}"
            elif lspci | grep -qi intel; then
                msg "Auto-detected Intel GPU, installing drivers"
                sudo apt install -y "${INTEL_PACKAGES[@]}"
            else
                msg "No specific GPU detected for auto-install"
            fi
            ;;
        "nvidia")
            msg "Installing NVIDIA drivers"
            sudo apt install -y "${NVIDIA_PACKAGES[@]}"
            ;;
        "amd")
            msg "Installing AMD drivers"
            sudo apt install -y "${AMD_PACKAGES[@]}"
            ;;
        "intel")
            msg "Installing Intel drivers"
            sudo apt install -y "${INTEL_PACKAGES[@]}"
            ;;
        *)
            msg "Unknown GPU driver option: $GPU_DRIVER"
            ;;
    esac
}

install_package_groups() {
    msg "Updating package database"
    sudo apt update
    
    msg "Installing essential packages"
    sudo apt install -y "${ESSENTIAL_PACKAGES[@]}"
    
    msg "Installing window manager packages"
    sudo apt install -y "${WM_PACKAGES[@]}"
    
    if [ ${#AUDIO_PACKAGES[@]} -gt 0 ]; then
        msg "Installing audio packages"
        sudo apt install -y "${AUDIO_PACKAGES[@]}"
    fi
    
    if [ ${#NETWORK_PACKAGES[@]} -gt 0 ]; then
        msg "Installing network packages"
        sudo apt install -y "${NETWORK_PACKAGES[@]}"
    fi
    
    if [ ${#APP_PACKAGES[@]} -gt 0 ]; then
        msg "Installing application packages"
        sudo apt install -y "${APP_PACKAGES[@]}"
    fi
    
    detect_and_install_gpu_drivers
}

setup_system_services() {
    if [ ${#NETWORK_PACKAGES[@]} -gt 0 ] && systemctl list-unit-files | grep -q NetworkManager; then
        msg "Enabling NetworkManager"
        sudo systemctl enable NetworkManager 2>/dev/null || true
    fi
    
    if [ ${#AUDIO_PACKAGES[@]} -gt 0 ]; then
        msg "Adding user to audio group"
        sudo usermod -a -G audio "$USER" 2>/dev/null || true
    fi
}

setup_config_dirs() {
    msg "Setting up configuration directories"
    mkdir -p "$HOME/.config/suckless"/{dwm,st,dmenu,slock,slstatus}
    mkdir -p "$HOME/.local/bin"
}

install_suckless_tools() {
    msg "Installing suckless tools"
    
    mkdir -p "$SUCKLESS_DIR"
    cd "$SUCKLESS_DIR"
    
    for tool in "${SUCKLESS_TOOLS[@]}"; do
        if [ ! -d "$tool" ]; then
            msg "Cloning $tool"
            git clone "https://git.suckless.org/$tool" || {
                msg "Failed to clone $tool, skipping"
                continue
            }
        else
            msg "Updating $tool"
            cd "$tool" && git pull && cd ..
        fi
        
        msg "Building and installing $tool"
        cd "$tool"
        
        # Check for user config.h
        if [ -f "$HOME/.config/suckless/$tool/config.h" ]; then
            msg "Using custom config for $tool"
            cp "$HOME/.config/suckless/$tool/config.h" .
        fi
        
        sudo make clean install || msg "Warning: $tool installation may have failed"
        cd ..
    done
}

create_dotfiles() {
    msg "Creating dotfiles"
    
    # Create configuration files
    generate_xinitrc
    generate_profile  
    generate_bashrc
    
    # Create wallpaper
    create_simple_wallpaper
}

show_completion_message() {
    msg "Setup complete!"
    echo
    echo "What was installed:"
    echo "  - Suckless tools: ${SUCKLESS_TOOLS[*]}"
    [ ${#APP_PACKAGES[@]} -gt 0 ] && echo "  - Applications: ${APP_PACKAGES[*]}"
    [ ${#AUDIO_PACKAGES[@]} -gt 0 ] && echo "  - Audio support: enabled"
    [ ${#NETWORK_PACKAGES[@]} -gt 0 ] && echo "  - Network tools: enabled"
    [ -n "$GPU_DRIVER" ] && echo "  - GPU drivers: $GPU_DRIVER"
    echo "  - Dotfiles: .xinitrc, .profile, .bashrc"
    echo "  - Default wallpaper: $WALLPAPER_PATH"
    echo "  - Config directories: ~/.config/suckless/"
    echo
    echo "Next steps:"
    echo "  - Reboot or run 'source ~/.profile' to apply changes"
    [ "$AUTO_START_X" = "1" ] && echo "  - X will start automatically on tty1"
    echo "  - Customize your dotfiles and suckless configs as needed"
    echo "  - Edit suckless tool configs in $SUCKLESS_DIR/[tool]/config.h"
    echo "  - Or place custom configs in ~/.config/suckless/[tool]/config.h"
}

main() {
    install_package_groups
    setup_system_services
    setup_config_dirs
    install_suckless_tools
    create_dotfiles
    show_completion_message
}

# Run the setup
main "$@"
