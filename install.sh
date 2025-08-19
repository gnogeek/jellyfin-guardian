#!/bin/bash

#############################################################################
#                         GNTECH Solutions                                 #
#                      Installation Script                                 #
#                                                                           #
#  Description: Install and configure Jellyfin backup script              #
#  Author: GNTECH Solutions                                                 #
#############################################################################

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
INSTALL_DIR="/usr/local/bin"
CONFIG_DIR="/etc/gntech"
LOG_DIR="/var/log"
BACKUP_DIR="/backup/jellyfin"
SERVICE_NAME="gntech-jellyfin-backup"

show_banner() {
    clear
    echo -e "${CYAN}${BOLD}GNTECH Solutions${NC}"
    echo -e "${YELLOW}Jellyfin Backup Installer${NC}"
    echo
}

log_message() {
    local level=$1
    local message=$2
    
    case $level in
        "ERROR")   echo -e "${RED}[ERROR]${NC} $message" ;;
        "SUCCESS") echo -e "${GREEN}[SUCCESS]${NC} $message" ;;
        "WARNING") echo -e "${YELLOW}[WARNING]${NC} $message" ;;
        "INFO")    echo -e "${BLUE}[INFO]${NC} $message" ;;
    esac
}

check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_message "ERROR" "This script must be run as root or with sudo"
        exit 1
    fi
}

check_dependencies() {
    log_message "INFO" "Checking dependencies..."
    
    local deps=("docker" "rsync" "bash")
    local missing_deps=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing_deps+=("$dep")
        fi
    done
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        log_message "ERROR" "Missing dependencies: ${missing_deps[*]}"
        log_message "INFO" "Please install the missing dependencies and run the installer again"
        exit 1
    fi
    
    log_message "SUCCESS" "All dependencies are installed"
}

create_directories() {
    log_message "INFO" "Creating directories..."
    
    mkdir -p "$CONFIG_DIR"
    mkdir -p "$LOG_DIR"
    mkdir -p "$BACKUP_DIR"
    
    log_message "SUCCESS" "Directories created successfully"
}

install_script() {
    log_message "INFO" "Installing backup script..."
    
    if [ ! -f "jellyfin-backup.sh" ]; then
        log_message "ERROR" "jellyfin-backup.sh not found in current directory"
        exit 1
    fi
    
    cp jellyfin-backup.sh "$INSTALL_DIR/"
    chmod +x "$INSTALL_DIR/jellyfin-backup.sh"
    
    log_message "SUCCESS" "Backup script installed to $INSTALL_DIR/"
}

install_config() {
    log_message "INFO" "Installing configuration file..."
    
    if [ -f "jellyfin-backup.conf" ]; then
        cp jellyfin-backup.conf "$CONFIG_DIR/"
        log_message "SUCCESS" "Configuration file installed"
    else
        log_message "WARNING" "Configuration file not found, using defaults"
    fi
}

create_systemd_service() {
    log_message "INFO" "Creating systemd service..."
    
    cat > "/etc/systemd/system/${SERVICE_NAME}.service" << EOF
[Unit]
Description=GNTECH Jellyfin Backup Service
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
ExecStart=${INSTALL_DIR}/jellyfin-backup.sh --all
User=root
Group=root
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

    cat > "/etc/systemd/system/${SERVICE_NAME}.timer" << EOF
[Unit]
Description=GNTECH Jellyfin Backup Timer
Requires=${SERVICE_NAME}.service

[Timer]
OnCalendar=daily
Persistent=true

[Install]
WantedBy=timers.target
EOF

    systemctl daemon-reload
    log_message "SUCCESS" "Systemd service created"
}

setup_cron() {
    log_message "INFO" "Setting up cron job..."
    
    # Create cron job for daily backups at 2 AM
    echo "0 2 * * * root $INSTALL_DIR/jellyfin-backup.sh --all >> $LOG_DIR/gntech-jellyfin-backup-cron.log 2>&1" > /etc/cron.d/gntech-jellyfin-backup
    
    # Create cron job for cleanup of old backups (daily) - 3 day retention
    echo "0 3 * * * root find $BACKUP_DIR -type d -mtime +3 -exec rm -rf {} + 2>/dev/null" >> /etc/cron.d/gntech-jellyfin-backup
    
    log_message "SUCCESS" "Cron jobs configured with 3-day retention policy"
}

create_logrotate() {
    log_message "INFO" "Setting up log rotation..."
    
    cat > "/etc/logrotate.d/gntech-jellyfin-backup" << EOF
$LOG_DIR/gntech-jellyfin-backup.log {
    daily
    missingok
    rotate 7
    compress
    delaycompress
    notifempty
    create 644 root root
}

$LOG_DIR/gntech-jellyfin-backup-cron.log {
    weekly
    missingok
    rotate 4
    compress
    delaycompress
    notifempty
    create 644 root root
}
EOF

    log_message "SUCCESS" "Log rotation configured"
}

test_installation() {
    log_message "INFO" "Testing installation..."
    
    if "$INSTALL_DIR/jellyfin-backup.sh" --version &>/dev/null; then
        log_message "SUCCESS" "Installation test passed"
    else
        log_message "WARNING" "Installation test failed, but files are in place"
    fi
}

show_completion_message() {
    echo
    log_message "SUCCESS" "GNTECH Jellyfin Backup Script installation completed!"
    echo
    echo -e "${YELLOW}Installation Summary:${NC}"
    echo "  • Script installed to: $INSTALL_DIR/jellyfin-backup.sh"
    echo "  • Configuration: $CONFIG_DIR/jellyfin-backup.conf"
    echo "  • Log files: $LOG_DIR/gntech-jellyfin-backup.log"
    echo "  • Backup directory: $BACKUP_DIR"
    echo
    echo -e "${YELLOW}Usage:${NC}"
    echo "  • Run interactive mode: sudo jellyfin-backup.sh"
    echo "  • Backup all containers: sudo jellyfin-backup.sh --all"
    echo "  • Enable automated backups: sudo systemctl enable ${SERVICE_NAME}.timer"
    echo "  • Start automated backups: sudo systemctl start ${SERVICE_NAME}.timer"
    echo
    echo -e "${YELLOW}Next Steps:${NC}"
    echo "  1. Edit $CONFIG_DIR/jellyfin-backup.conf if needed"
    echo "  2. Test the script: sudo jellyfin-backup.sh"
    echo "  3. Enable automated backups if desired"
    echo
    echo -e "${GREEN}Thank you for choosing GNTECH Solutions!${NC}"
}

main() {
    show_banner
    
    log_message "INFO" "Starting GNTECH Jellyfin Backup Script installation..."
    
    check_root
    check_dependencies
    create_directories
    install_script
    install_config
    create_systemd_service
    setup_cron
    create_logrotate
    test_installation
    show_completion_message
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
