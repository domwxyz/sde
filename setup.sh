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
)

# Window manager and compositor packages (easily removable)
WM_PACKAGES=(
    "feh"           # wallpaper setter
    "picom"         # compositor
)

# Audio packages (remove if you don't want audio)
AUDIO_PACKAGES=(
    "pulseaudio"
    "alsa-utils"
)

# Network packages (remove if using different network setup)
NETWORK_PACKAGES=(
    "network-manager"
)

# Application packages (add/remove as desired)
# Common additions: emacs, vim, git-gui, etc.
APP_PACKAGES=(
    "firefox-esr"
    "nano"
    "imagemagick"
)

# Suckless tools to install from source
SUCKLESS_TOOLS=(
    "dwm"
    "st" 
    "dmenu"
    "slock"
    "slstatus"
)

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
WALLPAPER_COLOR="#2e2e2e"

# Enable/disable features (1 = enable, 0 = disable)
INSTALL_GPU_DRIVERS=1
INSTALL_AUDIO=1
INSTALL_NETWORK=1
INSTALL_APPS=1
AUTO_START_X=1

#
# DOTFILE TEMPLATES - Customize as needed
#

generate_xinitrc() {
    cat > "$HOME/.xinitrc" << 'EOF'
# Set wallpaper
feh --bg-scale ~/.wallpaper &

# Start compositor
picom -b &

# Start status bar
slstatus &

# Start window manager (this should be last)
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
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'
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

detect_and_install_gpu_drivers() {
    [ "$INSTALL_GPU_DRIVERS" != "1" ] && return
    
    if lspci | grep -qi nvidia; then
        msg "Installing NVIDIA drivers"
        sudo apt install -y "${NVIDIA_PACKAGES[@]}"
    elif lspci | grep -qi amd; then
        msg "Installing AMD drivers" 
        sudo apt install -y "${AMD_PACKAGES[@]}"
    elif lspci | grep -qi intel; then
        msg "Installing Intel drivers"
        sudo apt install -y "${INTEL_PACKAGES[@]}"
    else
        msg "No specific GPU drivers detected"
    fi
}

install_package_groups() {
    msg "Updating package database"
    sudo apt update
    
    msg "Installing essential packages"
    sudo apt install -y "${ESSENTIAL_PACKAGES[@]}"
    
    msg "Installing window manager packages"
    sudo apt install -y "${WM_PACKAGES[@]}"
    
    if [ "$INSTALL_AUDIO" = "1" ]; then
        msg "Installing audio packages"
        sudo apt install -y "${AUDIO_PACKAGES[@]}"
    fi
    
    if [ "$INSTALL_NETWORK" = "1" ]; then
        msg "Installing network packages"
        sudo apt install -y "${NETWORK_PACKAGES[@]}"
    fi
    
    if [ "$INSTALL_APPS" = "1" ]; then
        msg "Installing application packages"
        sudo apt install -y "${APP_PACKAGES[@]}"
    fi
    
    detect_and_install_gpu_drivers
}

setup_system_services() {
    if [ "$INSTALL_NETWORK" = "1" ]; then
        msg "Enabling NetworkManager"
        sudo systemctl enable NetworkManager
    fi
    
    if [ "$INSTALL_AUDIO" = "1" ]; then
        msg "Adding user to audio group"
        sudo usermod -a -G audio "$USER"
    fi
}

install_suckless_tools() {
    msg "Installing suckless tools"
    
    mkdir -p "$SUCKLESS_DIR"
    cd "$SUCKLESS_DIR"
    
    for tool in "${SUCKLESS_TOOLS[@]}"; do
        if [ ! -d "$tool" ]; then
            msg "Cloning $tool"
            git clone "https://git.suckless.org/$tool"
        else
            msg "Updating $tool"
            cd "$tool" && git pull && cd ..
        fi
        
        msg "Building and installing $tool"
        cd "$tool"
        sudo make clean install
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
    msg "Creating default wallpaper"
    convert -size "$WALLPAPER_SIZE" "xc:$WALLPAPER_COLOR" "$WALLPAPER_PATH"
}

show_completion_message() {
    msg "Setup complete!"
    echo
    echo "What was installed:"
    echo "  - Suckless tools: ${SUCKLESS_TOOLS[*]}"
    echo "  - Dotfiles: .xinitrc, .profile, .bashrc"
    echo "  - Default wallpaper: $WALLPAPER_PATH"
    echo
    echo "Next steps:"
    echo "  1. Reboot or run 'source ~/.profile' to apply changes"
    [ "$AUTO_START_X" = "1" ] && echo "  2. X will start automatically on tty1"
    echo "  3. Customize your dotfiles and suckless configs as needed"
    echo "  4. Edit suckless tool configs in $SUCKLESS_DIR/[tool]/config.h"
}

main() {
    install_package_groups
    setup_system_services
    install_suckless_tools
    create_dotfiles
    show_completion_message
}

# Run the setup
main "$@"
