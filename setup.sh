#!/bin/bash
# Suckless Desktop Environment Setup Script
# Dynamic configuration - edit the arrays below to customize your setup
# Everything is configurable - the script adapts to your choices
#
# Usage: Edit the package arrays below, then run: bash setup.sh
# - Remove packages/tools you don't want
# - Add new packages to any array
# - Set GPU_DRIVER to your needs (or leave as "auto")

set -e

#
# CONFIGURATION - Edit these to customize
#

# Essential packages (required)
ESSENTIAL_PACKAGES=(
    build-essential git libx11-dev libxft-dev libxinerama-dev 
    libxrandr-dev libimlib2-dev xorg xinit pkg-config
)

# Desktop packages
WM_PACKAGES=(feh picom)
AUDIO_PACKAGES=(pulseaudio alsa-utils)
NETWORK_PACKAGES=(network-manager)
DEV_PACKAGES=(make gcc)
APP_PACKAGES=(firefox-esr nano)
# Example additions: vim htop neofetch chromium vlc

# Suckless tools
SUCKLESS_TOOLS=(dwm st dmenu slock slstatus)
# Can remove/add: surf tabbed sent

# Patches (format: "tool:patch_url")
PATCHES=(
    #"dwm:https://dwm.suckless.org/patches/systray/dwm-systray-6.4.diff"
    #"st:https://st.suckless.org/patches/scrollback/st-scrollback-0.8.5.diff"
)

# GPU driver: auto, nvidia, amd, intel, or empty
GPU_DRIVER="auto"

# Directories
SUCKLESS_DIR="$HOME/.local/src"

#
# FUNCTIONS
#

msg() { echo "==> $*"; }
die() { echo "Error: $*" >&2; exit 1; }

detect_gpu() {
    if lspci | grep -qi nvidia; then echo "nvidia"
    elif lspci | grep -qi amd; then echo "amd"
    elif lspci | grep -qi intel; then echo "intel"
    else echo "none"
    fi
}

check_system() {
    msg "Checking system"
    command -v apt >/dev/null || die "This script requires Debian/Ubuntu"
    sudo true || die "This script requires sudo access"
    
    # Ensure dwm is in the tools list
    [[ " ${SUCKLESS_TOOLS[@]} " =~ " dwm " ]] || die "dwm must be in SUCKLESS_TOOLS array"
    
    ping -c 1 git.suckless.org >/dev/null 2>&1 || {
        echo "Warning: Cannot reach git.suckless.org"
        read -p "Continue anyway? (y/N): " -r
        [[ $REPLY =~ ^[Yy]$ ]] || exit 1
    }
}

install_packages() {
    msg "Installing packages"
    sudo apt update || die "apt update failed"
    
    # Build package list from non-empty arrays
    local all_packages=("${ESSENTIAL_PACKAGES[@]}")
    [ ${#WM_PACKAGES[@]} -gt 0 ] && all_packages+=("${WM_PACKAGES[@]}")
    [ ${#AUDIO_PACKAGES[@]} -gt 0 ] && all_packages+=("${AUDIO_PACKAGES[@]}")
    [ ${#NETWORK_PACKAGES[@]} -gt 0 ] && all_packages+=("${NETWORK_PACKAGES[@]}")
    [ ${#DEV_PACKAGES[@]} -gt 0 ] && all_packages+=("${DEV_PACKAGES[@]}")
    [ ${#APP_PACKAGES[@]} -gt 0 ] && all_packages+=("${APP_PACKAGES[@]}")
    
    # Install all packages at once
    sudo apt install -y "${all_packages[@]}" || die "Package installation failed"
    
    # GPU drivers
    case "$GPU_DRIVER" in
        auto)
            local detected_gpu=$(detect_gpu)
            case "$detected_gpu" in
                nvidia)
                    msg "Detected NVIDIA GPU"
                    sudo apt install -y nvidia-driver firmware-misc-nonfree
                    ;;
                amd)
                    msg "Detected AMD GPU"
                    sudo apt install -y firmware-amd-graphics libgl1-mesa-dri
                    ;;
                intel)
                    msg "Detected Intel GPU"
                    sudo apt install -y intel-media-va-driver mesa-va-drivers
                    ;;
            esac
            ;;
        nvidia) sudo apt install -y nvidia-driver firmware-misc-nonfree ;;
        amd)    sudo apt install -y firmware-amd-graphics libgl1-mesa-dri ;;
        intel)  sudo apt install -y intel-media-va-driver mesa-va-drivers ;;
    esac
}

setup_directories() {
    msg "Creating directories"
    mkdir -p "$SUCKLESS_DIR"
    mkdir -p "$HOME/.config/suckless"/{dwm,st,dmenu,slock,slstatus}
    mkdir -p "$HOME/.local/bin"
}

install_suckless() {
    msg "Installing suckless tools"
    cd "$SUCKLESS_DIR"
    
    for tool in "${SUCKLESS_TOOLS[@]}"; do
        if [ ! -d "$tool" ]; then
            msg "Cloning $tool"
            git clone "https://git.suckless.org/$tool" || die "Failed to clone $tool"
        fi
        
        msg "Building $tool"
        cd "$tool"

        # Apply patches (if any)
        for patch_entry in "${PATCHES[@]}"; do
            IFS=':' read -r patch_tool patch_url <<< "$patch_entry"
            if [ "$tool" = "$patch_tool" ] && [ -n "$patch_url" ]; then
                msg "Applying patch to $tool"
                curl -s "$patch_url" | patch -p1 || echo "Warning: Patch failed"
            fi
        done
        
        # Check for custom config
        if [ -f "$HOME/.config/suckless/$tool/config.h" ]; then
            cp "$HOME/.config/suckless/$tool/config.h" .
        fi
        
        sudo make clean install || die "Failed to build $tool"
        cd ..
    done
}

configure_system() {
    msg "Configuring system"

    # Backup existing configs (if existing)
    [ -f ~/.xinitrc ] && cp ~/.xinitrc ~/.xinitrc.bak
    [ -f ~/.bashrc ] && cp ~/.bashrc ~/.bashrc.bak
    
    # Enable services based on what was installed
    if [[ " ${NETWORK_PACKAGES[@]} " =~ " network-manager " ]]; then
        sudo systemctl enable NetworkManager 2>/dev/null || true
    fi
    
    if [ ${#AUDIO_PACKAGES[@]} -gt 0 ]; then
        sudo usermod -a -G audio "$USER" 2>/dev/null || true
    fi
    
    # Create xinitrc dynamically based on installed packages
    cat > ~/.xinitrc << 'EOF'
#!/bin/sh
EOF
    
    # Add wallpaper setter if feh is installed
    [[ " ${WM_PACKAGES[@]} " =~ " feh " ]] && \
        echo 'feh --bg-scale ~/.wallpaper 2>/dev/null &' >> ~/.xinitrc
    
    # Add compositor if picom is installed
    [[ " ${WM_PACKAGES[@]} " =~ " picom " ]] && \
        echo 'picom -b 2>/dev/null &' >> ~/.xinitrc
    
    # Add status bar if slstatus is in tools
    [[ " ${SUCKLESS_TOOLS[@]} " =~ " slstatus " ]] && \
        echo 'slstatus 2>/dev/null &' >> ~/.xinitrc
    
    # Always add dwm at the end
    echo 'exec dwm' >> ~/.xinitrc
    chmod +x ~/.xinitrc
    
    # Detect installed programs for environment variables
    local default_browser=""
    local default_editor=""
    
    # Check what was actually installed
    for app in "${APP_PACKAGES[@]}"; do
        case "$app" in
            firefox*) default_browser="firefox" ;;
            chromium*) default_browser="chromium" ;;
            nano) default_editor="nano" ;;
            vim) default_editor="vim" ;;
            emacs) default_editor="emacs" ;;
        esac
    done
    
    # Create bashrc
    cat > ~/.bashrc << EOF
# Source system bashrc
[ -f /etc/bashrc ] && . /etc/bashrc

# Environment
export PATH="\$HOME/.local/bin:\$PATH"
${default_editor:+export EDITOR=$default_editor}
${default_browser:+export BROWSER=$default_browser}
export TERMINAL=st

# Prompt
PS1='\u@\h:\w\$ '

# Aliases
alias ls='ls --color=auto'
alias ll='ls -la'
alias la='ls -A'
alias grep='grep --color=auto'
alias ..='cd ..'
EOF
    
    # Auto-start X
    echo '[ -z "$DISPLAY" ] && [ "$XDG_VTNR" = 1 ] && exec startx' >> ~/.profile
    
    # Create wallpaper only if feh is installed
    if [[ " ${WM_PACKAGES[@]} " =~ " feh " ]]; then
        # Create minimal black wallpaper (1x1 pixel PPM image)
        printf "P3\n1 1\n255\n0 0 0\n" > ~/.wallpaper
    fi
}

show_complete() {
    msg "Setup complete!"
    echo
    echo "Installed components:"
    echo "  - Suckless tools: ${SUCKLESS_TOOLS[*]}"
    
    # Display what was actually installed from each category
    [ ${#WM_PACKAGES[@]} -gt 0 ] && echo "  - Window manager extras: ${WM_PACKAGES[*]}"
    [ ${#AUDIO_PACKAGES[@]} -gt 0 ] && echo "  - Audio support: ${AUDIO_PACKAGES[*]}"
    [ ${#NETWORK_PACKAGES[@]} -gt 0 ] && echo "  - Network tools: ${NETWORK_PACKAGES[*]}"
    [ ${#DEV_PACKAGES[@]} -gt 0 ] && echo "  - Development tools: ${DEV_PACKAGES[*]}"
    [ ${#APP_PACKAGES[@]} -gt 0 ] && echo "  - Applications: ${APP_PACKAGES[*]}"
    
    # Show GPU driver if installed
    if [ -n "$GPU_DRIVER" ]; then
        local gpu_msg="$GPU_DRIVER"
        if [ "$GPU_DRIVER" = "auto" ]; then
            local detected=$(detect_gpu)
            gpu_msg="auto-detected $detected"
        fi
        echo "  - GPU driver: $gpu_msg"
    fi
    
    echo
    echo "Config locations:"
    echo "  - Suckless sources: $SUCKLESS_DIR"
    echo "  - Custom configs: ~/.config/suckless/[tool]/config.h"
    echo "  - Dotfiles: ~/.xinitrc, ~/.bashrc, ~/.profile"
    echo
    echo "Next: Reboot to auto-start X on tty1"
}

#
# MAIN
#

check_system
install_packages
setup_directories
install_suckless
configure_system
show_complete
