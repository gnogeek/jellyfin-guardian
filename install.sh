#!/bin/bash

# GNTECH Jellyfin Guardian - Enhanced Local Installation Script
# Version: 2.2 (Remote Storage & User Automation Release)

set -euo pipefail

SCRIPT_VERSION="2.2"
INSTALL_DIR="/usr/local/bin"
CONFIG_DIR="$HOME/.config/gntech"
LOG_DIR="$HOME/.local/log"

echo "========================================"
echo "🛡️  GNTECH Jellyfin Guardian"
echo "Local Installation Script v$SCRIPT_VERSION"
echo "========================================"
echo

# Check if running as root for system installation
if [[ $EUID -eq 0 ]]; then
    echo "[INFO] Installing system-wide (running as root)"
    INSTALL_TYPE="system"
    CONFIG_DIR="/etc/gntech"
    LOG_DIR="/var/log"
else
    echo "[INFO] Installing for current user"
    INSTALL_DIR="$HOME/.local/bin"
    INSTALL_TYPE="user"
fi

# Create necessary directories
echo "[INFO] Creating directories..."
mkdir -p "$INSTALL_DIR" "$CONFIG_DIR" "$LOG_DIR"

# Check if script exists
if [ ! -f "jellyfin-backup.sh" ]; then
    echo "[ERROR] jellyfin-backup.sh not found in current directory"
    echo "[INFO] Please run this script from the jellyfin-guardian directory"
    exit 1
fi

# Install main script
echo "[INFO] Installing jellyfin-backup.sh to $INSTALL_DIR..."
cp jellyfin-backup.sh "$INSTALL_DIR/jellyfin-guardian"
chmod +x "$INSTALL_DIR/jellyfin-guardian"

# Install configuration file
if [ -f "config/jellyfin-backup.conf" ]; then
    echo "[INFO] Installing configuration template..."
    cp config/jellyfin-backup.conf "$CONFIG_DIR/"
fi

# Install remote configuration file
if [ -f "config/jellyfin-backup-remote.conf" ]; then
    echo "[INFO] Installing remote storage configuration template..."
    cp config/jellyfin-backup-remote.conf "$CONFIG_DIR/"
fi

# Install configuration script
if [ -f "scripts/configure-remote.sh" ]; then
    echo "[INFO] Installing remote configuration script..."
    cp scripts/configure-remote.sh "$INSTALL_DIR/jellyfin-guardian-configure"
    chmod +x "$INSTALL_DIR/jellyfin-guardian-configure"
fi

# Install deployment script
if [ -f "scripts/deploy.sh" ]; then
    echo "[INFO] Installing deployment script..."
    cp scripts/deploy.sh "$INSTALL_DIR/jellyfin-guardian-deploy"
    chmod +x "$INSTALL_DIR/jellyfin-guardian-deploy"
fi

# User automation functions
setup_user_automation() {
    echo "[INFO] Setting up user-level automation..."
    echo
    read -p "Would you like to set up automatic daily backups? (y/N): " setup_auto
    
    if [[ "$setup_auto" =~ ^[Yy]$ ]]; then
        echo "Choose automation method:"
        echo "1. User crontab (recommended)"
        echo "2. Systemd user service"  
        echo "3. Both"
        echo "4. Skip automation"
        read -p "Enter choice (1-4): " auto_choice
        
        case $auto_choice in
            1) setup_user_cron ;;
            2) setup_user_systemd ;;
            3) setup_user_cron && setup_user_systemd ;;
            *) echo "[INFO] Skipping automation setup" ;;
        esac
    else
        echo "[INFO] Skipping automation setup"
        echo "[INFO] You can set up automation later:"
        echo "  • Manual cron: crontab -e"
        echo "  • Systemd user: systemctl --user enable jellyfin-guardian.timer"
    fi
}

setup_user_cron() {
    echo "[INFO] Setting up user crontab..."
    
    # Backup existing crontab
    if crontab -l >/dev/null 2>&1; then
        echo "[INFO] Backing up existing crontab"
        crontab -l > "$HOME/.crontab.backup.$(date +%Y%m%d_%H%M%S)"
    fi
    
    # Add backup job (2 AM daily)
    echo "[INFO] Adding daily backup job (2 AM)..."
    (crontab -l 2>/dev/null || echo "# GNTECH Jellyfin Guardian - User Crontab") | \
    { cat; echo "0 2 * * * $INSTALL_DIR/jellyfin-guardian --all >> $LOG_DIR/jellyfin-guardian-cron.log 2>&1"; } | \
    crontab -
    
    echo "[SUCCESS] User crontab configured successfully"
    echo "[INFO] View crontab: crontab -l"
    echo "[INFO] Edit crontab: crontab -e"
}

setup_user_systemd() {
    echo "[INFO] Setting up systemd user service..."
    
    # Create user systemd directory
    local user_systemd_dir="$HOME/.config/systemd/user"
    mkdir -p "$user_systemd_dir"
    
    # Create service file
    cat > "$user_systemd_dir/jellyfin-guardian.service" << EOF
[Unit]
Description=GNTECH Jellyfin Guardian Backup Service
After=docker.service

[Service]
Type=oneshot
ExecStart=$INSTALL_DIR/jellyfin-guardian --all
StandardOutput=journal
StandardError=journal
Environment=HOME=$HOME
Environment=PATH=$PATH

[Install]
WantedBy=default.target
EOF

    # Create timer file  
    cat > "$user_systemd_dir/jellyfin-guardian.timer" << EOF
[Unit]
Description=GNTECH Jellyfin Guardian Backup Timer
Requires=jellyfin-guardian.service

[Timer]
OnCalendar=daily
Persistent=true

[Install]
WantedBy=timers.target
EOF

    # Reload user systemd
    systemctl --user daemon-reload
    
    echo "[SUCCESS] Systemd user service created"
    echo "[INFO] Enable: systemctl --user enable jellyfin-guardian.timer"
    echo "[INFO] Start: systemctl --user start jellyfin-guardian.timer"
    echo "[INFO] Status: systemctl --user status jellyfin-guardian.timer"
}

# Handle user vs system installation
if [ "$INSTALL_TYPE" = "user" ]; then
    # Add to PATH for user installation
    if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
        echo "[INFO] Adding $HOME/.local/bin to PATH..."
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
        echo "[INFO] Please run: source ~/.bashrc or start a new terminal session"
    fi
    
    # Setup user automation
    setup_user_automation
    
else
    # System installation - add system-wide automation
    echo "[INFO] System installation detected - would setup system services here"
    echo "[INFO] For system automation, use: sudo systemctl enable jellyfin-guardian.timer"
fi

# Test installation
echo
echo "[INFO] Testing installation..."
if "$INSTALL_DIR/jellyfin-guardian" --version >/dev/null 2>&1; then
    echo "[SUCCESS] Installation completed successfully!"
else
    echo "[ERROR] Installation test failed"
    exit 1
fi

# Show completion message
echo
echo "========================================"
echo "🎉 Installation Complete!"
echo "========================================"
echo

if [ "$INSTALL_TYPE" = "user" ]; then
    echo "✅ User Installation Summary:"
    echo "  • Main script: $INSTALL_DIR/jellyfin-guardian"
    echo "  • Deploy script: $INSTALL_DIR/jellyfin-guardian-deploy"
    echo "  • Configure script: $INSTALL_DIR/jellyfin-guardian-configure"
    echo "  • Configuration: $CONFIG_DIR/"
    echo "  • Logs: $LOG_DIR/"
    echo
    echo "🚀 Quick Start:"
    echo "  source ~/.bashrc                    # Reload PATH"
    echo "  jellyfin-guardian --version         # Test installation"
    echo "  jellyfin-guardian                   # Interactive mode"
    echo "  jellyfin-guardian --all             # Backup all containers"
    echo "  jellyfin-guardian --cleanup         # Clean old backups"
    echo "  jellyfin-guardian-configure         # Setup remote storage"
    echo
    echo "⏰ Automation (if configured):"
    echo "  crontab -l                          # View cron jobs"
    echo "  systemctl --user status jellyfin-guardian.timer   # Check systemd timer"
else
    echo "✅ System Installation Summary:"
    echo "  • Script installed to: $INSTALL_DIR/jellyfin-guardian"
    echo "  • Configuration: $CONFIG_DIR/"
    echo "  • Logs: $LOG_DIR/"
    echo
    echo "🚀 Quick Start:"
    echo "  jellyfin-guardian --version         # Test installation"
    echo "  sudo jellyfin-guardian              # Interactive mode"  
    echo "  sudo jellyfin-guardian --all        # Backup all containers"
fi

echo
echo -e "🎯 Next Steps:"
echo "  1. Configure remote storage if needed"
echo "  2. Test the backup functionality"
echo "  3. Set up automated backups if desired"
echo
echo "Thank you for choosing GNTECH Solutions! 🛡️"
