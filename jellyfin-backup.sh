#!/bin/bash

# GNTECH Solutions - Jellyfin Container Backup Script (Final Version)
# Interactive backup script for Jellyfin containers on remote servers
# Version: 2.2 (Remote Storage Release)
# 
# Features:
# - Pre-backup database integrity verification
# - Real-time progress tracking with pv
# - Direct compression with pigz/gzip
# - Safe container stop/start management
# - Automatic prerequisite installation
# - Interactive container selection
# - Comprehensive backup-specific log files
# - Remote storage with multiple providers (SFTP, S3, NFS, FTP, rclone)
# - Intelligent retention policies (local + remote)
# - Automatic cleanup and space management
# 
# Copyright (c) 2024 GNTECH Solutions
# Licensed under MIT License

set -euo pipefail

# Script metadata
SCRIPT_NAME="GNTECH Jellyfin Backup"
SCRIPT_VERSION="2.2"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output (simplified)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Simple icons
CHECK_MARK="✓"
CROSS_MARK="✗"
WARNING_SIGN="⚠"
INFO_ICON="ℹ"

# Default configuration
BACKUP_BASE_DIR="$HOME/jellyfin-backups"
LOG_DIR="$HOME/.local/log"
CONFIG_DIR="$HOME/.config/gntech"
STOP_CONTAINER_FOR_BACKUP=true
CONTAINER_STOP_TIMEOUT=30
METADATA_INTEGRITY_CHECK=true
BACKUP_RETENTION_DAYS=3
ENABLE_COMPRESSION=true
COMPRESSION_LEVEL=6
AUTO_REMOVE_UNCOMPRESSED=false

# Remote storage defaults
REMOTE_STORAGE_ENABLED=false

# Determine remote config file location based on installation type
if [ -f "$SCRIPT_DIR/config/jellyfin-backup-remote.conf" ]; then
    # Running from git repository
    REMOTE_CONFIG_FILE="$SCRIPT_DIR/config/jellyfin-backup-remote.conf"
elif [ -f "$HOME/.config/gntech/jellyfin-backup-remote.conf" ]; then
    # User installation
    REMOTE_CONFIG_FILE="$HOME/.config/gntech/jellyfin-backup-remote.conf"
elif [ -f "/etc/gntech/jellyfin-backup-remote.conf" ]; then
    # System installation
    REMOTE_CONFIG_FILE="/etc/gntech/jellyfin-backup-remote.conf"
else
    # Default fallback (will be checked in load_remote_config)
    REMOTE_CONFIG_FILE="$SCRIPT_DIR/config/jellyfin-backup-remote.conf"
fi

# Load remote storage configuration if exists
load_remote_config() {
    if [ -f "$REMOTE_CONFIG_FILE" ]; then
        log_message "INFO" "Loading remote storage configuration"
        source "$REMOTE_CONFIG_FILE"
        
        if [ "$REMOTE_STORAGE_ENABLED" = "true" ]; then
            log_message "INFO" "Remote storage enabled: $REMOTE_STORAGE_TYPE"
        fi
    fi
}

# Ensure directories exist
ensure_directories() {
    mkdir -p "$BACKUP_BASE_DIR" "$LOG_DIR" "$CONFIG_DIR"
}

# Install prerequisites if missing
install_prerequisites() {
    echo "[INFO] Checking and installing prerequisites..."
    
    local missing_tools=()
    local install_needed=false
    
    # Check for required tools
    if ! command -v sqlite3 >/dev/null 2>&1; then
        missing_tools+=("sqlite3")
        install_needed=true
    fi
    
    if ! command -v pv >/dev/null 2>&1; then
        missing_tools+=("pv")
        install_needed=true
    fi
    
    if ! command -v pigz >/dev/null 2>&1; then
        missing_tools+=("pigz")
        install_needed=true
    fi
    
    if ! command -v rsync >/dev/null 2>&1; then
        missing_tools+=("rsync")
        install_needed=true
    fi
    
    if [ "$install_needed" = "true" ]; then
        echo "[INFO] Missing tools detected: ${missing_tools[*]}"
        echo "[INFO] Attempting to install prerequisites..."
        
        # Detect package manager and install
        if command -v apt-get >/dev/null 2>&1; then
            echo "[INFO] Using apt-get to install packages..."
            if [ ${#missing_tools[@]} -gt 0 ]; then
                sudo apt-get update -qq
                for tool in "${missing_tools[@]}"; do
                    case $tool in
                        "sqlite3") sudo apt-get install -y sqlite3 ;;
                        "pv") sudo apt-get install -y pv ;;
                        "pigz") sudo apt-get install -y pigz ;;
                        "rsync") sudo apt-get install -y rsync ;;
                    esac
                done
            fi
        elif command -v yum >/dev/null 2>&1; then
            echo "[INFO] Using yum to install packages..."
            for tool in "${missing_tools[@]}"; do
                case $tool in
                    "sqlite3") sudo yum install -y sqlite ;;
                    "pv") sudo yum install -y pv ;;
                    "pigz") sudo yum install -y pigz ;;
                    "rsync") sudo yum install -y rsync ;;
                esac
            done
        elif command -v dnf >/dev/null 2>&1; then
            echo "[INFO] Using dnf to install packages..."
            for tool in "${missing_tools[@]}"; do
                case $tool in
                    "sqlite3") sudo dnf install -y sqlite ;;
                    "pv") sudo dnf install -y pv ;;
                    "pigz") sudo dnf install -y pigz ;;
                    "rsync") sudo dnf install -y rsync ;;
                esac
            done
        else
            echo "[WARNING] No supported package manager found (apt-get/yum/dnf)"
            echo "[WARNING] Please install manually: ${missing_tools[*]}"
            echo "[INFO] Continuing with available tools..."
        fi
        
        # Verify installation
        echo "[INFO] Verifying installed tools..."
        for tool in "${missing_tools[@]}"; do
            if command -v "$tool" >/dev/null 2>&1; then
                echo "[SUCCESS] $tool is now available"
            else
                echo "[WARNING] $tool installation may have failed"
            fi
        done
    else
        echo "[SUCCESS] All prerequisites are already installed"
    fi
}

# Logging function (simplified to prevent interference)
log_message() {
    local level=$1
    local message=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Only log to file, avoid console output during critical operations
    echo "[$timestamp] [$level] $message" >> "$LOG_DIR/gntech-jellyfin-backup.log" 2>/dev/null || true
    
    # Simple console output without ANSI codes that can interfere
    case $level in
        "ERROR") echo "[ERROR] $message" ;;
        "WARNING") echo "[WARNING] $message" ;;
        "SUCCESS") echo "[SUCCESS] $message" ;;
        "INFO") echo "[INFO] $message" ;;
        "PROGRESS") echo "[PROGRESS] $message" ;;
    esac
}

# Database verification function (checks source before backup)
verify_jellyfin_databases() {
    local source_dir=$1
    local db_errors=0
    
    echo "[INFO] Verifying Jellyfin database integrity before backup..."
    
    # Find all SQLite database files in source
    local db_files
    db_files=$(find "$source_dir" -name "*.db" -type f 2>/dev/null || true)
    
    if [ -z "$db_files" ]; then
        echo "[WARNING] No database files found for verification in $source_dir"
        return 0
    fi
    
    while IFS= read -r db_file; do
        if [ -f "$db_file" ]; then
            echo "[INFO] Checking database: $(basename "$db_file")"
            
            # Check if sqlite3 is available
            if command -v sqlite3 >/dev/null 2>&1; then
                if sqlite3 "$db_file" "PRAGMA integrity_check;" 2>/dev/null | grep -q "ok"; then
                    echo "[SUCCESS] Database integrity OK: $(basename "$db_file")"
                else
                    echo "[ERROR] Database integrity FAILED: $(basename "$db_file")"
                    ((db_errors++))
                fi
            else
                echo "[WARNING] sqlite3 not available, skipping integrity check for $(basename "$db_file")"
            fi
        fi
    done <<< "$db_files"
    
    if [ $db_errors -gt 0 ]; then
        echo "[ERROR] Found $db_errors database(s) with integrity issues"
        echo "[ERROR] Backup aborted to prevent backing up corrupted data"
        return 1
    else
        echo "[SUCCESS] All databases passed integrity checks"
        return 0
    fi
}

# Direct compression backup function
create_compressed_backup() {
    local container_name=$1
    local backup_dir=$2
    local source_dir="/opt/$container_name"
    
    echo "[INFO] Creating compressed backup directly from source..."
    
    local timestamp=$(date '+%Y%m%d_%H%M%S')
    local compressed_file="${backup_dir}/${container_name}_${timestamp}.tar.gz"
    
    # Check available compression tools and use the best one
    if command -v pigz >/dev/null 2>&1; then
        echo "[INFO] Using pigz (parallel gzip) for faster compression..."
        echo "[INFO] Source: $source_dir"
        echo "[INFO] Target: $compressed_file"
        echo "[INFO] Starting compressed backup with progress..."
        
        # Use tar with pigz and show progress using pv if available
        if command -v pv >/dev/null 2>&1; then
            echo "[INFO] Using pv for progress display"
            local source_size=$(du -sb "$source_dir" 2>/dev/null | cut -f1 || echo "0")
            if [ "$source_size" -gt 0 ]; then
                echo "[INFO] Estimated source size: $(du -sh "$source_dir" | cut -f1)"
                echo "[INFO] Starting compression with live progress..."
                echo "Progress format: [Data rate] [Progress] [Time elapsed] [ETA]"
                echo
                tar -C "$(dirname "$source_dir")" \
                    --exclude='logs/*' \
                    --exclude='cache/*' \
                    --exclude='transcodes/*' \
                    --exclude='temp/*' \
                    --exclude='tmp/*' \
                    --exclude='*.log' \
                    --exclude='*.tmp' \
                    -cf - "$(basename "$source_dir")" \
                    | pv -f -p -t -e -r -b -s "$source_size" \
                    | pigz -6 > "$compressed_file"
                echo
                echo "[INFO] Compression completed"
            else
                echo "[WARNING] Could not determine source size, using basic progress"
                echo "[INFO] Starting compression (progress without percentage)..."
                echo
                tar -C "$(dirname "$source_dir")" \
                    --exclude='logs/*' \
                    --exclude='cache/*' \
                    --exclude='transcodes/*' \
                    --exclude='temp/*' \
                    --exclude='tmp/*' \
                    --exclude='*.log' \
                    --exclude='*.tmp' \
                    -cf - "$(basename "$source_dir")" \
                    | pv -f -t -e -r -b \
                    | pigz -6 > "$compressed_file"
                echo
                echo "[INFO] Compression completed"
            fi
        else
            # Fallback without pv - try to install it first
            echo "[INFO] pv not available - attempting to install for progress display..."
            if command -v apt-get >/dev/null 2>&1; then
                echo "[INFO] Installing pv..."
                sudo apt-get update -qq && sudo apt-get install -y pv >/dev/null 2>&1 || true
                if command -v pv >/dev/null 2>&1; then
                    echo "[SUCCESS] pv installed! Restarting compression with progress..."
                    local source_size=$(du -sb "$source_dir" 2>/dev/null | cut -f1 || echo "0")
                    echo "[INFO] Estimated source size: $(du -sh "$source_dir" | cut -f1)"
                    echo "[INFO] Compressing with progress bar..."
                    echo
                    tar -C "$(dirname "$source_dir")" \
                        --exclude='logs/*' \
                        --exclude='cache/*' \
                        --exclude='transcodes/*' \
                        --exclude='temp/*' \
                        --exclude='tmp/*' \
                        --exclude='*.log' \
                        --exclude='*.tmp' \
                        -cf - "$(basename "$source_dir")" \
                        | pv -p -t -e -r -b -s "$source_size" -N "Compressing" \
                        | pigz -6 > "$compressed_file"
                    echo
                else
                    echo "[WARNING] Failed to install pv, using basic compression"
                    echo "[INFO] Compressing without progress display..."
                    tar -C "$(dirname "$source_dir")" \
                        --exclude='logs/*' \
                        --exclude='cache/*' \
                        --exclude='transcodes/*' \
                        --exclude='temp/*' \
                        --exclude='tmp/*' \
                        --exclude='*.log' \
                        --exclude='*.tmp' \
                        -cf - "$(basename "$source_dir")" \
                        | pigz -6 > "$compressed_file"
                fi
            else
                echo "[WARNING] Cannot install pv (unsupported package manager)"
                echo "[INFO] Compressing without progress display..."
                tar -C "$(dirname "$source_dir")" \
                    --exclude='logs/*' \
                    --exclude='cache/*' \
                    --exclude='transcodes/*' \
                    --exclude='temp/*' \
                    --exclude='tmp/*' \
                    --exclude='*.log' \
                    --exclude='*.tmp' \
                    -cf - "$(basename "$source_dir")" \
                    | pigz -6 > "$compressed_file"
            fi
        fi
    elif command -v gzip >/dev/null 2>&1; then
        echo "[INFO] Using standard gzip compression..."
        echo "[INFO] Source: $source_dir"
        echo "[INFO] Target: $compressed_file"
        
        # Use tar with progress indication if pv is available
        if command -v pv >/dev/null 2>&1; then
            local source_size=$(du -sb "$source_dir" 2>/dev/null | cut -f1 || echo "0")
            echo "[INFO] Estimated source size: $(du -sh "$source_dir" | cut -f1)"
            echo "[INFO] Compressing with progress bar..."
            echo
            tar -C "$(dirname "$source_dir")" \
                --exclude='logs/*' \
                --exclude='cache/*' \
                --exclude='transcodes/*' \
                --exclude='temp/*' \
                --exclude='tmp/*' \
                --exclude='*.log' \
                --exclude='*.tmp' \
                -cf - "$(basename "$source_dir")" \
                | pv -p -t -e -r -b -s "$source_size" -N "Compressing" \
                | gzip -6 > "$compressed_file"
            echo
        else
            echo "[INFO] Compressing with verbose output for progress indication..."
            tar -C "$(dirname "$source_dir")" \
                --exclude='logs/*' \
                --exclude='cache/*' \
                --exclude='transcodes/*' \
                --exclude='temp/*' \
                --exclude='tmp/*' \
                --exclude='*.log' \
                --exclude='*.tmp' \
                --verbose \
                -czf "$compressed_file" \
                "$(basename "$source_dir")"
        fi
    else
        echo "[ERROR] No compression tools available (gzip/pigz not found)"
        return 1
    fi
    
    if [ $? -eq 0 ] && [ -f "$compressed_file" ]; then
        local compressed_size=$(du -sh "$compressed_file" | cut -f1)
        local original_size=$(du -sh "$source_dir" | cut -f1)
        echo "[SUCCESS] Compressed backup created successfully"
        echo "[INFO] Original size: $original_size | Compressed size: $compressed_size"
        echo "[INFO] Backup file: $compressed_file"
        echo "$compressed_file"  # Return the path for further processing
        return 0
    else
        echo "[ERROR] Backup compression failed"
        return 1
    fi
}

# Show banner
show_banner() {
    clear
    echo -e "${CYAN}================================================${NC}"
    echo -e "${WHITE}GNTECH Solutions${NC}"
    echo -e "${WHITE}Jellyfin Container Backup Script${NC}"
    echo -e "${WHITE}Version $SCRIPT_VERSION${NC}"
    echo
    echo -e "${CYAN}Professional Container Backup Solution${NC}"
    echo -e "${CYAN}Enterprise-grade data protection for Jellyfin servers${NC}"
    echo
    echo -e "${YELLOW}$(date) | Server: $(hostname) | User: $(whoami)${NC}"
    echo
}

# Check if Docker is available
check_docker() {
    if ! command -v docker >/dev/null 2>&1; then
        log_message "ERROR" "Docker is not installed or not in PATH"
        return 1
    fi
    
    if ! docker info >/dev/null 2>&1; then
        log_message "ERROR" "Docker daemon is not running or not accessible"
        return 1
    fi
    
    log_message "SUCCESS" "Docker is available and running"
    return 0
}

# Check user permissions for backup operations
check_permissions() {
    log_message "INFO" "Checking user permissions for backup operations"
    
    local current_user=$(whoami)
    local user_id=$(id -u)
    
    echo "[INFO] Current user: $current_user (UID: $user_id)"
    
    # Check if user is root
    if [ "$user_id" -eq 0 ]; then
        echo "[SUCCESS] Running as root - all permissions available"
        log_message "SUCCESS" "Running as root user"
        return 0
    fi
    
    # Check Docker group membership
    echo "[INFO] Checking Docker group membership..."
    if groups "$current_user" | grep -q docker; then
        echo "[SUCCESS] User is member of docker group"
        log_message "SUCCESS" "User has docker group membership"
    else
        echo "[ERROR] User is not member of docker group"
        echo "[SOLUTION] Add user to docker group with: sudo usermod -aG docker $current_user"
        echo "[NOTE] You'll need to log out and back in for group changes to take effect"
        log_message "ERROR" "User lacks docker group membership"
        return 1
    fi
    
    # Check Docker socket access
    echo "[INFO] Testing Docker socket access..."
    if docker ps >/dev/null 2>&1; then
        echo "[SUCCESS] Docker socket accessible"
        log_message "SUCCESS" "Docker socket access verified"
    else
        echo "[ERROR] Cannot access Docker socket"
        echo "[SOLUTION] Ensure Docker daemon is running and user has docker group access"
        log_message "ERROR" "Docker socket access denied"
        return 1
    fi
    
    # Check container data directories access
    echo "[INFO] Checking container data directory access..."
    local jellyfin_dirs_found=false
    local accessible_dirs=0
    local total_dirs=0
    
    # Check common Jellyfin container data locations
    local common_paths=(
        "/opt"
        "/var/lib/docker/volumes"
        "/home/*/jellyfin"
        "/docker/jellyfin"
        "/data/jellyfin"
    )
    
    for path_pattern in "${common_paths[@]}"; do
        for path in $path_pattern; do
            if [ -d "$path" ]; then
                total_dirs=$((total_dirs + 1))
                if [ -r "$path" ]; then
                    accessible_dirs=$((accessible_dirs + 1))
                    if find "$path" -maxdepth 2 -name "*jellyfin*" -type d >/dev/null 2>&1; then
                        jellyfin_dirs_found=true
                        echo "[SUCCESS] Found readable Jellyfin directory: $path"
                        log_message "SUCCESS" "Accessible Jellyfin directory found: $path"
                    fi
                else
                    echo "[WARNING] Directory exists but not readable: $path"
                    log_message "WARNING" "Directory not readable: $path"
                fi
            fi
        done
    done
    
    # Check /opt specifically (common location)
    if [ -d "/opt" ]; then
        if [ -r "/opt" ]; then
            echo "[SUCCESS] /opt directory is readable"
            log_message "SUCCESS" "/opt directory accessible"
        else
            echo "[ERROR] /opt directory is not readable"
            echo "[SOLUTION] May need: sudo chmod +r /opt or sudo chown -R $current_user:$current_user /opt"
            log_message "ERROR" "/opt directory not accessible"
        fi
    fi
    
    # Summary
    echo
    echo "[INFO] Permission Check Summary:"
    echo "  - User: $current_user (UID: $user_id)"
    echo "  - Docker access: $(docker info >/dev/null 2>&1 && echo 'OK' || echo 'FAILED')"
    echo "  - Accessible directories: $accessible_dirs/$total_dirs"
    echo "  - Jellyfin directories found: $jellyfin_dirs_found"
    
    if [ "$jellyfin_dirs_found" = true ]; then
        echo "[SUCCESS] User has sufficient permissions for backup operations"
        log_message "SUCCESS" "Permission checks passed"
        return 0
    else
        echo "[WARNING] No accessible Jellyfin directories found"
        echo "[INFO] You may need to adjust file permissions or run as root for some containers"
        echo
        echo "Common solutions:"
        echo "1. Add user to docker group: sudo usermod -aG docker $current_user"
        echo "2. Fix directory permissions: sudo chmod -R +r /opt"
        echo "3. Change directory ownership: sudo chown -R $current_user:$current_user /opt"
        echo "4. Run script as root: sudo ./jellyfin-backup.sh"
        
        log_message "WARNING" "Limited permissions - manual intervention may be needed"
        
        echo
        echo -n "Continue anyway? Some containers may not be accessible (y/N): "
        read -r continue_choice
        if [[ "$continue_choice" =~ ^[Yy] ]]; then
            return 0
        else
            return 1
        fi
    fi
}

# Health checks
perform_health_checks() {
    log_message "INFO" "Performing pre-backup health checks"
    
    # Check user permissions
    if ! check_permissions; then
        log_message "ERROR" "Permission checks failed"
        return 1
    fi
    
    # Check disk space
    local available_space=$(df -BG "$BACKUP_BASE_DIR" | tail -1 | awk '{print $4}' | sed 's/G//')
    if [ "$available_space" -lt 10 ]; then
        log_message "ERROR" "Insufficient disk space: ${available_space}GB available"
        return 1
    fi
    log_message "SUCCESS" "Sufficient disk space: ${available_space}GB available"
    
    log_message "SUCCESS" "All pre-backup health checks passed"
    return 0
}

# Discover Jellyfin containers
discover_jellyfin_containers() {
    echo -e "${BLUE}${INFO_ICON} Discovering Jellyfin containers...${NC}"
    
    # Search for containers with jellyfin in name OR jellyfin-related images
    local all_containers=$(docker ps -a --format "{{.Names}}\t{{.Image}}\t{{.State}}\t{{.CreatedAt}}" 2>/dev/null)
    local jellyfin_containers=""
    
    while IFS=$'\t' read -r name image status created; do
        if [[ "$name" =~ jellyfin ]] || [[ "$image" =~ jellyfin ]]; then
            if [ -z "$jellyfin_containers" ]; then
                jellyfin_containers="$name\t$image\t$status\t$created"
            else
                jellyfin_containers="$jellyfin_containers\n$name\t$image\t$status\t$created"
            fi
        fi
    done <<< "$all_containers"
    
    if [ -z "$jellyfin_containers" ]; then
        echo -e "${YELLOW}${WARNING_SIGN} No Jellyfin containers found${NC}"
        echo
        echo -e "${CYAN}Would you like to see all available containers? (y/n):${NC} "
        read -r show_all
        if [[ "$show_all" =~ ^[Yy] ]]; then
            list_all_containers
        fi
        return 1
    fi
    
    echo -e "${GREEN}${CHECK_MARK} Found Jellyfin containers:${NC}"
    echo
    echo -e "NAMES\tIMAGE\tSTATUS\tCREATED AT"
    echo -e "$jellyfin_containers" | column -t -s $'\t'
    echo
    
    local container_count=$(echo -e "$jellyfin_containers" | wc -l)
    log_message "SUCCESS" "Discovery complete: $container_count containers found"
}

# List all containers
list_all_containers() {
    echo -e "${CYAN}All Available Containers:${NC}"
    echo
    
    local all_containers=$(docker ps -a --format "{{.Names}}\t{{.Image}}\t{{.State}}\t{{.CreatedAt}}" 2>/dev/null)
    
    if [ -z "$all_containers" ]; then
        echo -e "${YELLOW}No containers found on this system${NC}"
        return 1
    fi
    
    echo -e "NAMES\tIMAGE\tSTATUS\tCREATED AT"
    echo -e "$all_containers" | column -t -s $'\t'
    echo
}

# Interactive container selection
select_container_interactive() {
    echo -e "${CYAN}Interactive Container Selection${NC}"
    echo
    
    echo -e "${CYAN}Fetching all containers...${NC}"
    local all_containers=$(timeout 10 docker ps -a --format "{{.Names}}\t{{.Image}}\t{{.State}}" 2>/dev/null || true)
    local docker_exit_code=$?
    
    if [ $docker_exit_code -ne 0 ]; then
        echo -e "${RED}Error: Docker command timed out or failed${NC}"
        return 1
    fi
    
    if [ -z "$all_containers" ]; then
        echo -e "${RED}${CROSS_MARK} No containers found on this system${NC}"
        return 1
    fi
    
    # Create numbered list
    local container_array=()
    local counter=1
    
    echo -e "${CYAN}Available Containers:${NC}"
    echo
    
    while IFS=$'\t' read -r name image status; do
        container_array+=("$name")
        local status_color="${RED}"
        if [[ "$status" == "running" ]]; then
            status_color="${GREEN}"
        elif [[ "$status" == "exited" ]]; then
            status_color="${YELLOW}"
        fi
        
        echo -e "$counter) ${BLUE}$name${NC} ($image) [${status_color}$status${NC}]"
        ((counter++))
    done <<< "$all_containers"
    
    echo
    echo -e "${CYAN}Enter container number (1-$((counter-1))) or 'q' to quit:${NC} "
    read -r selection
    
    if [[ "$selection" =~ ^[Qq] ]]; then
        echo -e "${YELLOW}Selection cancelled${NC}"
        return 1
    fi
    
    if [[ "$selection" =~ ^[0-9]+$ ]] && [ "$selection" -ge 1 ] && [ "$selection" -le $((counter-1)) ]; then
        local selected_container="${container_array[$((selection-1))]}"
        echo -e "${GREEN}${CHECK_MARK} Selected container: ${BLUE}$selected_container${NC}"
        echo "$selected_container"
        return 0
    else
        echo -e "${RED}${CROSS_MARK} Invalid selection${NC}"
        return 1
    fi
}

# Smart container selection
select_container() {
    echo -e "${CYAN}Container Selection${NC}"
    echo
    
    # First try to find Jellyfin containers automatically (with timeout)
    echo -e "${CYAN}Searching for Jellyfin containers...${NC}"
    local docker_output=$(timeout 10 docker ps -a --format "{{.Names}}\t{{.Image}}\t{{.State}}" 2>/dev/null)
    local docker_exit_code=$?
    
    if [ $docker_exit_code -ne 0 ]; then
        echo -e "${RED}Error: Docker command timed out or failed${NC}"
        return 1
    fi
    
    local jellyfin_containers=$(echo "$docker_output" | grep -i jellyfin || true)
    
    echo -e "${CYAN}Debug: jellyfin_containers result: '$jellyfin_containers'${NC}"
    
    if [ ! -z "$jellyfin_containers" ]; then
        echo -e "${GREEN}${CHECK_MARK} Found Jellyfin containers:${NC}"
        echo
        
        local container_array=()
        local counter=1
        
        while IFS=$'\t' read -r name image status; do
            container_array+=("$name")
            local status_color="${RED}"
            if [[ "$status" == "running" ]]; then
                status_color="${GREEN}"
            elif [[ "$status" == "exited" ]]; then
                status_color="${YELLOW}"
            fi
            
            echo -e "$counter) ${BLUE}$name${NC} ($image) [${status_color}$status${NC}]"
            ((counter++))
        done <<< "$jellyfin_containers"
        
        echo
        echo -e "${CYAN}Enter container number (1-$((counter-1))), 'a' to see all containers, or 'q' to quit:${NC} "
        read -r selection
        
        if [[ "$selection" =~ ^[Qq] ]]; then
            echo -e "${YELLOW}Selection cancelled${NC}"
            return 1
        elif [[ "$selection" =~ ^[Aa] ]]; then
            echo
            select_container_interactive
            return $?
        elif [[ "$selection" =~ ^[0-9]+$ ]] && [ "$selection" -ge 1 ] && [ "$selection" -le $((counter-1)) ]; then
            local selected_container="${container_array[$((selection-1))]}"
            echo -e "${GREEN}${CHECK_MARK} Selected container: ${BLUE}$selected_container${NC}"
            echo "$selected_container"
            return 0
        else
            echo -e "${RED}${CROSS_MARK} Invalid selection${NC}"
            return 1
        fi
    else
        echo -e "${YELLOW}${WARNING_SIGN} No Jellyfin containers found automatically${NC}"
        echo -e "${CYAN}Showing all available containers...${NC}"
        echo
        select_container_interactive
        return $?
    fi
}

# === REMOTE STORAGE FUNCTIONS ===

# Upload backup to remote storage
upload_to_remote() {
    local backup_file=$1
    local container_name=$2
    
    if [ "$REMOTE_STORAGE_ENABLED" != "true" ]; then
        return 0
    fi
    
    log_message "INFO" "Starting remote upload for: $backup_file"
    echo
    echo "========================================"
    echo "Uploading to Remote Storage"
    echo "========================================"
    echo "[INFO] Storage type: $REMOTE_STORAGE_TYPE"
    echo "[INFO] File: $(basename "$backup_file")"
    
    case $REMOTE_STORAGE_TYPE in
        sftp)
            upload_sftp "$backup_file" "$container_name"
            ;;
        s3)
            upload_s3 "$backup_file" "$container_name"
            ;;
        nfs)
            upload_nfs "$backup_file" "$container_name"
            ;;
        ftp)
            upload_ftp "$backup_file" "$container_name"
            ;;
        rclone)
            upload_rclone "$backup_file" "$container_name"
            ;;
        *)
            echo "[ERROR] Unknown storage type: $REMOTE_STORAGE_TYPE"
            return 1
            ;;
    esac
    
    local upload_result=$?
    
    if [ $upload_result -eq 0 ]; then
        echo "[SUCCESS] Remote upload completed"
        log_message "SUCCESS" "Remote upload successful: $backup_file"
        
        # Verify upload if enabled
        if [ "$VERIFY_REMOTE_UPLOAD" = "true" ]; then
            verify_remote_backup "$backup_file" "$container_name"
        fi
        
        # Clean up old remote backups
        cleanup_remote_backups "$container_name"
        
        # Delete local backup if configured
        if [ "$DELETE_LOCAL_AFTER_UPLOAD" = "true" ]; then
            echo "[INFO] Deleting local backup after successful upload..."
            rm -f "$backup_file"
            log_message "INFO" "Local backup deleted: $backup_file"
        fi
        
        return 0
    else
        echo "[ERROR] Remote upload failed"
        log_message "ERROR" "Remote upload failed: $backup_file"
        return 1
    fi
}

# SFTP upload function
upload_sftp() {
    local backup_file=$1
    local container_name=$2
    local remote_file="$SFTP_PATH/$(basename "$backup_file")"
    
    echo "[INFO] Uploading via SFTP to $SFTP_HOST:$remote_file"
    
    # Ensure remote directory exists
    ssh -i "$SFTP_KEY_FILE" -p "$SFTP_PORT" "$SFTP_USER@$SFTP_HOST" "mkdir -p $SFTP_PATH" 2>/dev/null
    
    # Upload with progress
    if command -v pv >/dev/null 2>&1; then
        pv "$backup_file" | ssh -i "$SFTP_KEY_FILE" -p "$SFTP_PORT" "$SFTP_USER@$SFTP_HOST" "cat > $remote_file"
    else
        scp -i "$SFTP_KEY_FILE" -P "$SFTP_PORT" "$backup_file" "$SFTP_USER@$SFTP_HOST:$remote_file"
    fi
}

# S3 upload function
upload_s3() {
    local backup_file=$1
    local container_name=$2
    local s3_key="$S3_PATH/$(basename "$backup_file")"
    
    echo "[INFO] Uploading to S3: s3://$S3_BUCKET/$s3_key"
    
    # Check if aws cli is available
    if ! command -v aws >/dev/null 2>&1; then
        echo "[ERROR] AWS CLI not installed. Install with: sudo apt install awscli"
        return 1
    fi
    
    # Set AWS credentials if provided
    if [ -n "$S3_ACCESS_KEY" ] && [ -n "$S3_SECRET_KEY" ]; then
        export AWS_ACCESS_KEY_ID="$S3_ACCESS_KEY"
        export AWS_SECRET_ACCESS_KEY="$S3_SECRET_KEY"
        export AWS_DEFAULT_REGION="$S3_REGION"
    fi
    
    # Set endpoint if not AWS
    local endpoint_option=""
    if [ -n "$S3_ENDPOINT" ]; then
        endpoint_option="--endpoint-url $S3_ENDPOINT"
    fi
    
    # Upload with progress
    aws s3 cp "$backup_file" "s3://$S3_BUCKET/$s3_key" $endpoint_option --region "$S3_REGION"
}

# NFS upload function
upload_nfs() {
    local backup_file=$1
    local container_name=$2
    local mount_point="$NFS_MOUNT_POINT"
    
    echo "[INFO] Copying to NFS mount: $mount_point"
    
    # Check if already mounted
    if ! mountpoint -q "$mount_point"; then
        echo "[INFO] Mounting NFS share..."
        sudo mkdir -p "$mount_point"
        sudo mount -t nfs -o "$NFS_OPTIONS" "$NFS_HOST:$NFS_PATH" "$mount_point"
        
        if [ $? -ne 0 ]; then
            echo "[ERROR] Failed to mount NFS share"
            return 1
        fi
    fi
    
    # Copy with progress
    local dest_dir="$mount_point/jellyfin-backups"
    sudo mkdir -p "$dest_dir"
    
    if command -v pv >/dev/null 2>&1; then
        pv "$backup_file" | sudo tee "$dest_dir/$(basename "$backup_file")" >/dev/null
    else
        sudo cp "$backup_file" "$dest_dir/"
    fi
}

# FTP upload function
upload_ftp() {
    local backup_file=$1
    local container_name=$2
    
    echo "[INFO] Uploading via FTP to $FTP_HOST:$FTP_PATH"
    
    # Check if lftp is available
    if ! command -v lftp >/dev/null 2>&1; then
        echo "[ERROR] lftp not installed. Install with: sudo apt install lftp"
        return 1
    fi
    
    # Upload using lftp
    lftp -c "
    set ftp:passive-mode $FTP_PASSIVE
    connect ftp://$FTP_USER:$FTP_PASS@$FTP_HOST:$FTP_PORT
    mkdir -p $FTP_PATH
    cd $FTP_PATH
    put $backup_file
    bye
    "
}

# Rclone upload function
upload_rclone() {
    local backup_file=$1
    local container_name=$2
    local remote_path="$RCLONE_REMOTE$RCLONE_PATH/$(basename "$backup_file")"
    
    echo "[INFO] Uploading via rclone to: $remote_path"
    
    # Check if rclone is available
    if ! command -v rclone >/dev/null 2>&1; then
        echo "[ERROR] rclone not installed. Install with: sudo apt install rclone"
        return 1
    fi
    
    # Upload with progress
    rclone copy "$backup_file" "$RCLONE_REMOTE$RCLONE_PATH" --progress --stats 5s
}

# Verify remote backup
verify_remote_backup() {
    local backup_file=$1
    local container_name=$2
    
    echo "[INFO] Verifying remote backup integrity..."
    
    local local_size=$(stat -c%s "$backup_file" 2>/dev/null || echo "0")
    local remote_size=""
    
    case $REMOTE_STORAGE_TYPE in
        sftp)
            remote_size=$(ssh -i "$SFTP_KEY_FILE" -p "$SFTP_PORT" "$SFTP_USER@$SFTP_HOST" \
                "stat -c%s $SFTP_PATH/$(basename "$backup_file")" 2>/dev/null || echo "0")
            ;;
        s3)
            remote_size=$(aws s3api head-object --bucket "$S3_BUCKET" --key "$S3_PATH/$(basename "$backup_file")" \
                --query 'ContentLength' --output text 2>/dev/null || echo "0")
            ;;
        # Add other verification methods as needed
    esac
    
    if [ "$local_size" = "$remote_size" ] && [ "$local_size" != "0" ]; then
        echo "[SUCCESS] Remote backup verification passed"
        log_message "SUCCESS" "Remote backup verified: $backup_file"
        return 0
    else
        echo "[WARNING] Remote backup verification failed (size mismatch)"
        log_message "WARNING" "Remote backup verification failed: $backup_file"
        return 1
    fi
}

# Clean up old remote backups
cleanup_remote_backups() {
    local container_name=$1
    
    if [ "$REMOTE_RETENTION" -le 0 ]; then
        return 0
    fi
    
    echo "[INFO] Cleaning up old remote backups (keeping last $REMOTE_RETENTION)"
    log_message "INFO" "Starting remote backup cleanup for: $container_name"
    
    case $REMOTE_STORAGE_TYPE in
        sftp)
            ssh -i "$SFTP_KEY_FILE" -p "$SFTP_PORT" "$SFTP_USER@$SFTP_HOST" \
                "cd $SFTP_PATH && ls -t ${container_name}_*.tar.gz | tail -n +$((REMOTE_RETENTION + 1)) | xargs -r rm -f"
            ;;
        s3)
            # List and delete old S3 objects
            aws s3api list-objects-v2 --bucket "$S3_BUCKET" --prefix "$S3_PATH/${container_name}_" \
                --query 'sort_by(Contents, &LastModified)[:-'$REMOTE_RETENTION'].Key' --output text | \
                xargs -r -I {} aws s3 rm "s3://$S3_BUCKET/{}"
            ;;
        # Add other cleanup methods as needed
    esac
    
    log_message "INFO" "Remote backup cleanup completed"
}

# Test remote storage connection
test_remote_storage() {
    if [ "$REMOTE_STORAGE_ENABLED" != "true" ]; then
        echo "[INFO] Remote storage is disabled"
        return 0
    fi
    
    echo "========================================"
    echo "Testing Remote Storage Connection"
    echo "========================================"
    echo "[INFO] Storage type: $REMOTE_STORAGE_TYPE"
    
    case $REMOTE_STORAGE_TYPE in
        sftp)
            echo "[INFO] Testing SFTP connection to $SFTP_HOST..."
            if ssh -i "$SFTP_KEY_FILE" -p "$SFTP_PORT" -o ConnectTimeout=10 "$SFTP_USER@$SFTP_HOST" "echo 'Connection test successful'" 2>/dev/null; then
                echo "[SUCCESS] SFTP connection test passed"
                return 0
            else
                echo "[ERROR] SFTP connection test failed"
                return 1
            fi
            ;;
        s3)
            echo "[INFO] Testing S3 connection..."
            if aws s3 ls "s3://$S3_BUCKET" >/dev/null 2>&1; then
                echo "[SUCCESS] S3 connection test passed"
                return 0
            else
                echo "[ERROR] S3 connection test failed"
                return 1
            fi
            ;;
        rclone)
            echo "[INFO] Testing rclone connection..."
            if rclone lsd "$RCLONE_REMOTE" >/dev/null 2>&1; then
                echo "[SUCCESS] Rclone connection test passed"
                return 0
            else
                echo "[ERROR] Rclone connection test failed"
                return 1
            fi
            ;;
        *)
            echo "[WARNING] Connection test not implemented for: $REMOTE_STORAGE_TYPE"
            return 0
            ;;
    esac
}

# Clean up local backups based on retention policy
cleanup_local_backups() {
    local container_name=$1
    
    if [ "$LOCAL_RETENTION" -le 0 ]; then
        return 0
    fi
    
    echo "[INFO] Cleaning up old local backups (keeping last $LOCAL_RETENTION)"
    log_message "INFO" "Starting local backup cleanup for: $container_name"
    
    local backup_pattern="$BACKUP_BASE_DIR/*/${container_name}_*.tar.gz"
    local backups_to_delete=$(find $BACKUP_BASE_DIR -name "${container_name}_*.tar.gz" -type f -printf '%T@ %p\n' | \
                             sort -nr | tail -n +$((LOCAL_RETENTION + 1)) | cut -d' ' -f2-)
    
    if [ -n "$backups_to_delete" ]; then
        echo "$backups_to_delete" | while read -r backup_file; do
            echo "[INFO] Removing old backup: $(basename "$backup_file")"
            rm -f "$backup_file"
            # Also remove corresponding log file
            local log_file="${backup_file%.tar.gz}.log"
            if [ -f "$log_file" ]; then
                rm -f "$log_file"
            fi
        done
        log_message "INFO" "Local backup cleanup completed"
    else
        echo "[INFO] No old backups to clean up"
    fi
}

# Get container mounts
get_container_mounts() {
    local container_name=$1
    log_message "INFO" "Getting mount points for container: $container_name"
    docker inspect "$container_name" --format '{{range .Mounts}}{{.Source}}:{{.Destination}}:{{.Type}}{{"\n"}}{{end}}' 2>/dev/null
}

# Create backup directory structure
create_backup_structure() {
    local timestamp=$(date '+%Y%m%d_%H%M%S')
    local backup_dir="$BACKUP_BASE_DIR/$timestamp"
    
    # Create the backup directory silently
    mkdir -p "$backup_dir"
    if [ $? -eq 0 ]; then
        # Output success message to stderr so it doesn't interfere with return value
        echo "[SUCCESS] Backup directory created: $backup_dir" >&2
        # Return only the directory path
        echo "$backup_dir"
    else
        echo "[ERROR] Failed to create backup directory: $backup_dir" >&2
        return 1
    fi
}

# Backup container data (optimized: verify first, then compress directly)
backup_container_data() {
    local container_name=$1
    local backup_path=$2
    
    # Log backup start
    log_message "INFO" "Starting backup process for container: $container_name"
    log_message "INFO" "Backup destination: $backup_path"
    
    echo "========================================"
    echo "Starting Backup Process for $container_name"
    echo "========================================"
    echo
    
    # Define source directory
    local source_dir="/opt/$container_name"
    
    # Verify source directory exists
    if [ ! -d "$source_dir" ]; then
        echo "[ERROR] Source directory not found: $source_dir"
        return 1
    fi
    
    # Check container status
    local container_status=$(docker inspect "$container_name" --format '{{.State.Status}}' 2>/dev/null || echo "not_found")
    
    if [ "$container_status" = "not_found" ]; then
        echo "[ERROR] Container $container_name not found"
        return 1
    fi
    
    echo "Container Status: $container_status"
    
    # Stop container if running and configured to do so
    local was_running=false
    if [ "$container_status" = "running" ] && [ "$STOP_CONTAINER_FOR_BACKUP" = "true" ]; then
        was_running=true
        echo "[WARNING] ⚠️  SAFETY NOTICE: Container is RUNNING and will be STOPPED"
        echo "           This prevents database corruption during backup"
        echo "           Container will be automatically restarted after backup"
        echo
        echo -n "Continue with container stop? (y/N): "
        read -r confirm
        
        if [[ ! "$confirm" =~ ^[Yy] ]]; then
            echo "[INFO] Backup cancelled by user"
            return 1
        fi
        
        echo "[INFO] Stopping container $container_name safely..."
        if docker stop "$container_name" >/dev/null 2>&1; then
            echo "[SUCCESS] ✓ Container $container_name stopped gracefully"
            sleep 2
        else
            echo "[ERROR] ✗ Failed to stop container $container_name"
            return 1
        fi
    elif [ "$container_status" = "running" ] && [ "$STOP_CONTAINER_FOR_BACKUP" = "false" ]; then
        echo "[WARNING] ⚠️  Container is RUNNING but auto-stop is DISABLED"
        echo "           This may result in inconsistent backup data"
        echo "           Consider stopping the container manually or enabling auto-stop"
        echo
        echo -n "Continue backup with running container? (y/N): "
        read -r confirm
        
        if [[ ! "$confirm" =~ ^[Yy] ]]; then
            echo "[INFO] Backup cancelled by user"
            return 1
        fi
    elif [ "$container_status" = "exited" ]; then
        echo "[SUCCESS] ✓ Container is already stopped - safe to backup"
    else
        echo "[INFO] Container status: $container_status"
    fi
    
    # Step 1: Verify database integrity BEFORE backup
    echo
    echo "========================================"
    echo "Pre-Backup Database Verification"
    echo "========================================"
    
    if [ "$METADATA_INTEGRITY_CHECK" = "true" ]; then
        if ! verify_jellyfin_databases "$source_dir"; then
            echo "[ERROR] Database verification failed - aborting backup"
            
            # Restart container if it was running
            if [ "$was_running" = "true" ]; then
                echo "Restarting container..."
                docker start "$container_name" >/dev/null 2>&1
            fi
            return 1
        fi
    else
        echo "[INFO] Database verification skipped (disabled)"
    fi
    
    # Step 2: Create compressed backup directly
    echo
    echo "========================================"
    echo "Creating Compressed Backup"
    echo "========================================"
    
    local backup_file
    if [ "$ENABLE_COMPRESSION" = "true" ]; then
        backup_file=$(create_compressed_backup "$container_name" "$backup_path")
        if [ $? -ne 0 ]; then
            echo "[ERROR] Compressed backup failed"
            
            # Restart container if it was running
            if [ "$was_running" = "true" ]; then
                echo "Restarting container..."
                docker start "$container_name" >/dev/null 2>&1
            fi
            return 1
        fi
    else
        echo "[INFO] Compression disabled - creating uncompressed backup with progress..."
        local container_backup_dir="$backup_path/$container_name"
        mkdir -p "$container_backup_dir"
        
        # Use rsync with progress if available
        if command -v rsync >/dev/null 2>&1; then
            echo "[INFO] Using rsync for backup with progress..."
            rsync -avh --progress \
                --exclude='logs/*' \
                --exclude='cache/*' \
                --exclude='transcodes/*' \
                --exclude='temp/*' \
                --exclude='tmp/*' \
                --exclude='*.log' \
                --exclude='*.tmp' \
                "$source_dir/" "$container_backup_dir/"
            
            if [ $? -eq 0 ]; then
                local backup_size=$(du -sh "$container_backup_dir" | cut -f1)
                local file_count=$(find "$container_backup_dir" -type f | wc -l)
                echo "[SUCCESS] Uncompressed backup completed: $backup_size ($file_count files)"
                backup_file="$container_backup_dir"
            else
                echo "[ERROR] Backup failed"
                
                # Restart container if it was running
                if [ "$was_running" = "true" ]; then
                    echo "Restarting container..."
                    docker start "$container_name" >/dev/null 2>&1
                fi
                return 1
            fi
        else
            echo "[ERROR] rsync not available for uncompressed backup"
            return 1
        fi
    fi
    
    # Restart container if it was running
    if [ "$was_running" = "true" ]; then
        echo
        echo "Restarting container..."
        if docker start "$container_name" >/dev/null 2>&1; then
            sleep 3
            local new_status=$(docker inspect "$container_name" --format '{{.State.Status}}' 2>/dev/null)
            if [ "$new_status" = "running" ]; then
                echo "[SUCCESS] Container restarted successfully"
            else
                echo "[WARNING] Container may not have started properly (status: $new_status)"
            fi
        else
            echo "[ERROR] Failed to restart container"
        fi
    fi
    
    # Create log file alongside the backup
    if [ -n "$backup_file" ]; then
        local log_file
        if [ "$ENABLE_COMPRESSION" = "true" ]; then
            # For compressed backups, create log file with same name but .log extension
            log_file="${backup_file%.tar.gz}.log"
        else
            # For uncompressed backups, create log file in the backup directory
            log_file="$backup_file/backup.log"
        fi
        
        echo
        echo "[INFO] Creating backup log file..."
        
        # Create detailed backup log
        {
            echo "GNTECH Solutions - Jellyfin Backup Log"
            echo "======================================="
            echo
            echo "Backup Date: $(date)"
            echo "Server: $(hostname)"
            echo "User: $(whoami)"
            echo "Script Version: $SCRIPT_VERSION"
            echo
            echo "Container Information:"
            echo "- Container Name: $container_name"
            echo "- Container Status (at backup): $container_status"
            echo "- Was Running: $was_running"
            echo "- Source Directory: $source_dir"
            echo
            echo "Backup Configuration:"
            echo "- Stop Container: $STOP_CONTAINER_FOR_BACKUP"
            echo "- Database Verification: $METADATA_INTEGRITY_CHECK"
            echo "- Compression Enabled: $ENABLE_COMPRESSION"
            echo "- Compression Level: $COMPRESSION_LEVEL"
            echo "- Backup Directory: $backup_path"
            echo
            echo "Backup Results:"
            echo "- Backup File: $backup_file"
            if [ "$ENABLE_COMPRESSION" = "true" ] && [ -f "$backup_file" ]; then
                echo "- Backup Size: $(du -sh "$backup_file" | cut -f1)"
                echo "- Original Size: $(du -sh "$source_dir" | cut -f1)"
            elif [ -d "$backup_file" ]; then
                echo "- Backup Size: $(du -sh "$backup_file" | cut -f1)"
                echo "- File Count: $(find "$backup_file" -type f | wc -l)"
            fi
            echo "- Backup Status: SUCCESS"
            echo
            echo "System Information:"
            echo "- Available Disk Space: $(df -h "$backup_path" | tail -1 | awk '{print $4}' || echo 'Unknown')"
            echo "- System Load: $(uptime)"
            echo
            echo "Session Log Entries:"
            echo "==================="
            # Include recent session log entries from the main log file
            if [ -f "$LOG_DIR/gntech-jellyfin-backup.log" ]; then
                echo "Recent session entries (last 50 lines):"
                tail -50 "$LOG_DIR/gntech-jellyfin-backup.log" 2>/dev/null || echo "Unable to read session log"
            else
                echo "No session log file found"
            fi
            echo
            echo "Log created at: $(date)"
        } > "$log_file" 2>/dev/null
        
        if [ -f "$log_file" ]; then
            echo "[SUCCESS] Backup log created: $log_file"
            log_message "SUCCESS" "Backup log file created: $log_file"
        else
            echo "[WARNING] Failed to create backup log file"
            log_message "WARNING" "Failed to create backup log file at: $log_file"
        fi
    fi

    # Upload to remote storage if enabled
    if [ "$REMOTE_STORAGE_ENABLED" = "true" ] && [ "$AUTO_UPLOAD" = "true" ]; then
        if upload_to_remote "$backup_file" "$container_name"; then
            echo "[SUCCESS] Remote upload completed successfully"
        else
            echo "[WARNING] Remote upload failed, backup remains local"
        fi
    fi

    # Clean up local backups based on retention policy
    if [ "$LOCAL_RETENTION" -gt 0 ]; then
        cleanup_local_backups "$container_name"
    fi

    # Log successful completion
    log_message "SUCCESS" "Backup process completed successfully for container: $container_name"
    log_message "INFO" "Final backup location: $backup_file"

    echo
    echo "[SUCCESS] Backup process completed for $container_name"
    echo "Backup location: $backup_file"
    if [ "$REMOTE_STORAGE_ENABLED" = "true" ]; then
        echo "Remote storage: $REMOTE_STORAGE_TYPE"
    fi
    return 0
}

# Show menu
show_menu() {
    echo -e "${CYAN}=== GNTECH Solutions - Backup Operations Menu ===${NC}"
    echo
    echo -e " ${BLUE}1.${NC} Discover and list Jellyfin containers"
    echo -e " ${BLUE}2.${NC} List all available containers"
    echo -e " ${BLUE}3.${NC} Backup specific container"
    echo -e " ${BLUE}4.${NC} Backup all Jellyfin containers"
    echo -e " ${BLUE}5.${NC} View container mounts"
    echo -e " ${BLUE}6.${NC} Configure backup settings"
    echo -e " ${BLUE}7.${NC} Configure remote storage"
    echo -e " ${BLUE}8.${NC} Test remote storage connection"
    echo -e " ${BLUE}9.${NC} View backup history"
    echo -e " ${BLUE}10.${NC} Clean up all backups"
    echo -e " ${BLUE}11.${NC} Exit"
    echo
}

# Get menu choice
get_menu_choice() {
    local choice
    while true; do
        echo -n -e "${WHITE}Enter your choice (1-11): ${NC}" >&2
        read -r choice
        
        # Validate input
        if [[ "$choice" =~ ^[1-9]$|^1[01]$ ]]; then
            echo "$choice"
            return 0
        elif [[ "$choice" =~ ^[Qq]$ ]]; then
            echo "11"  # Treat 'q' as exit
            return 0
        else
            echo -e "${RED}Invalid choice. Please enter 1-11 or 'q' to quit.${NC}" >&2
        fi
    done
}

# Configure settings
configure_settings() {
    echo -e "${YELLOW}Configure Backup Settings${NC}"
    echo "Current backup directory: $BACKUP_BASE_DIR"
    read -p "Enter new backup directory (or press Enter to keep current): " new_dir
    
    if [ ! -z "$new_dir" ]; then
        BACKUP_BASE_DIR="$new_dir"
        log_message "INFO" "Backup directory changed to: $BACKUP_BASE_DIR"
    fi
    
    echo
    echo "Container Management Settings:"
    echo "Stop container for backup: $STOP_CONTAINER_FOR_BACKUP"
    echo "Container stop timeout: ${CONTAINER_STOP_TIMEOUT}s"
    echo
    read -p "Stop containers during backup to prevent corruption? (y/n) [current: $STOP_CONTAINER_FOR_BACKUP]: " stop_choice
    
    case "$stop_choice" in
        [Yy]|[Yy][Ee][Ss])
            STOP_CONTAINER_FOR_BACKUP=true
            log_message "INFO" "Container stopping enabled for safe backups"
            ;;
        [Nn]|[Nn][Oo])
            STOP_CONTAINER_FOR_BACKUP=false
            log_message "INFO" "Container stopping disabled - backup during runtime"
            ;;
    esac
}

# View backup history
view_backup_history() {
    echo -e "${CYAN}Backup History${NC}"
    echo
    
    if [ -d "$BACKUP_BASE_DIR" ]; then
        echo "Recent backups in $BACKUP_BASE_DIR:"
        ls -la "$BACKUP_BASE_DIR" | grep "^d" | tail -10
        echo
        
        echo "Backup sizes:"
        for backup_dir in "$BACKUP_BASE_DIR"/*/; do
            if [ -d "$backup_dir" ]; then
                local size=$(du -sh "$backup_dir" 2>/dev/null | cut -f1)
                local name=$(basename "$backup_dir")
                echo "  $name: $size"
            fi
        done | tail -10
    else
        echo "No backup directory found at $BACKUP_BASE_DIR"
    fi
}

# Clean up all previous backups
cleanup_all_backups() {
    echo -e "${CYAN}Backup Cleanup Utility${NC}"
    echo
    
    if [ ! -d "$BACKUP_BASE_DIR" ]; then
        echo "[INFO] No backup directory found at $BACKUP_BASE_DIR"
        return 0
    fi
    
    echo "[INFO] Scanning for backups in: $BACKUP_BASE_DIR"
    
    local backup_count=0
    local total_size=0
    
    # Count and size backups
    while IFS= read -r -d '' backup_dir; do
        if [ -d "$backup_dir" ]; then
            backup_count=$((backup_count + 1))
            local size=$(du -sm "$backup_dir" 2>/dev/null | cut -f1)
            total_size=$((total_size + size))
        fi
    done < <(find "$BACKUP_BASE_DIR" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null)
    
    # Count individual backup files
    local file_count=0
    while IFS= read -r -d '' backup_file; do
        file_count=$((file_count + 1))
        local size=$(du -sm "$backup_file" 2>/dev/null | cut -f1)
        total_size=$((total_size + size))
    done < <(find "$BACKUP_BASE_DIR" -name "*.tar.gz" -type f -print0 2>/dev/null)
    
    if [ $backup_count -eq 0 ] && [ $file_count -eq 0 ]; then
        echo "[INFO] No backups found to clean up"
        return 0
    fi
    
    echo "[INFO] Found backups:"
    echo "  - Backup directories: $backup_count"
    echo "  - Backup files: $file_count"
    echo "  - Total size: ${total_size}MB"
    echo
    
    # Show recent backups
    echo "[INFO] Recent backup directories:"
    find "$BACKUP_BASE_DIR" -mindepth 1 -maxdepth 1 -type d -printf '%T@ %p\n' 2>/dev/null | \
        sort -nr | head -5 | while read -r timestamp path; do
        local date=$(date -d "@$timestamp" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "Unknown")
        local size=$(du -sh "$path" 2>/dev/null | cut -f1)
        echo "  $(basename "$path") - $date - $size"
    done
    
    echo
    echo "[INFO] Recent backup files:"
    find "$BACKUP_BASE_DIR" -name "*.tar.gz" -type f -printf '%T@ %p\n' 2>/dev/null | \
        sort -nr | head -5 | while read -r timestamp path; do
        local date=$(date -d "@$timestamp" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "Unknown")
        local size=$(du -sh "$path" 2>/dev/null | cut -f1)
        echo "  $(basename "$path") - $date - $size"
    done
    
    echo
    echo -e "${YELLOW}⚠️  WARNING: This will delete ALL existing backups!${NC}"
    echo "This action cannot be undone. Make sure you have copies elsewhere if needed."
    echo
    echo -n "Are you sure you want to delete all backups? Type 'DELETE ALL' to confirm: "
    read -r confirmation
    
    if [ "$confirmation" = "DELETE ALL" ]; then
        echo
        echo "[INFO] Deleting all backups..."
        log_message "WARNING" "User initiated full backup cleanup"
        
        local deleted_dirs=0
        local deleted_files=0
        local errors=0
        
        # Delete backup directories
        while IFS= read -r -d '' backup_dir; do
            if [ -d "$backup_dir" ]; then
                echo "[INFO] Deleting directory: $(basename "$backup_dir")"
                if rm -rf "$backup_dir" 2>/dev/null; then
                    deleted_dirs=$((deleted_dirs + 1))
                    log_message "INFO" "Deleted backup directory: $backup_dir"
                else
                    echo "[ERROR] Failed to delete: $(basename "$backup_dir")"
                    errors=$((errors + 1))
                    log_message "ERROR" "Failed to delete backup directory: $backup_dir"
                fi
            fi
        done < <(find "$BACKUP_BASE_DIR" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null)
        
        # Delete backup files
        while IFS= read -r -d '' backup_file; do
            echo "[INFO] Deleting file: $(basename "$backup_file")"
            if rm -f "$backup_file" 2>/dev/null; then
                deleted_files=$((deleted_files + 1))
                log_message "INFO" "Deleted backup file: $backup_file"
                # Also delete corresponding log file
                local log_file="${backup_file%.tar.gz}.log"
                if [ -f "$log_file" ]; then
                    rm -f "$log_file" 2>/dev/null
                    log_message "INFO" "Deleted backup log: $log_file"
                fi
            else
                echo "[ERROR] Failed to delete: $(basename "$backup_file")"
                errors=$((errors + 1))
                log_message "ERROR" "Failed to delete backup file: $backup_file"
            fi
        done < <(find "$BACKUP_BASE_DIR" -name "*.tar.gz" -type f -print0 2>/dev/null)
        
        echo
        echo "[SUCCESS] Cleanup completed:"
        echo "  - Deleted directories: $deleted_dirs"
        echo "  - Deleted files: $deleted_files"
        echo "  - Errors: $errors"
        echo "  - Freed space: ${total_size}MB"
        
        if [ $errors -eq 0 ]; then
            echo -e "${GREEN}✓ All backups cleaned successfully${NC}"
            log_message "SUCCESS" "Full backup cleanup completed successfully"
        else
            echo -e "${YELLOW}⚠ Cleanup completed with some errors${NC}"
            log_message "WARNING" "Backup cleanup completed with $errors errors"
        fi
        
    else
        echo "[INFO] Cleanup cancelled"
        log_message "INFO" "Backup cleanup cancelled by user"
    fi
}

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -c|--container)
                TARGET_CONTAINER="$2"
                BACKUP_MODE="single"
                shift 2
                ;;
            -a|--all)
                BACKUP_MODE="all"
                shift
                ;;
            -l|--list)
                BACKUP_MODE="list"
                shift
                ;;
            -n|--no-stop)
                STOP_CONTAINER_FOR_BACKUP=false
                shift
                ;;
            -d|--backup-dir)
                BACKUP_BASE_DIR="$2"
                shift 2
                ;;
            --no-compress)
                ENABLE_COMPRESSION=false
                shift
                ;;
            --no-verify)
                METADATA_INTEGRITY_CHECK=false
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --configure-remote)
                # Try different locations for the configure script
                if [ -f "$SCRIPT_DIR/scripts/configure-remote.sh" ]; then
                    # Running from git repository
                    "$SCRIPT_DIR/scripts/configure-remote.sh"
                    exit 0
                elif [ -f "$SCRIPT_DIR/jellyfin-guardian-configure" ]; then
                    # Installed version - script is in same directory
                    "$SCRIPT_DIR/jellyfin-guardian-configure"
                    exit 0
                elif command -v jellyfin-guardian-configure >/dev/null 2>&1; then
                    # Installed version - script is in PATH
                    jellyfin-guardian-configure
                    exit 0
                else
                    echo "[ERROR] Remote configuration script not found"
                    echo "[INFO] Please ensure jellyfin-guardian is properly installed"
                    exit 1
                fi
                ;;
            --test-remote)
                load_remote_config
                test_remote_storage
                exit $?
                ;;
            --no-remote)
                REMOTE_STORAGE_ENABLED=false
                shift
                ;;
            --local-only)
                DELETE_LOCAL_AFTER_UPLOAD=false
                shift
                ;;
            --cleanup)
                BACKUP_MODE="cleanup"
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            -v|--version)
                echo "$SCRIPT_NAME v$SCRIPT_VERSION"
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# Show help
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "$SCRIPT_NAME v$SCRIPT_VERSION"
    echo
    echo "Options:"
    echo "  -c, --container NAME      Backup specific container"
    echo "  -a, --all                 Backup all Jellyfin containers"
    echo "  -l, --list                List discovered containers only"
    echo "  -n, --no-stop             Don't stop containers during backup"
    echo "  -d, --backup-dir DIR      Override backup directory"
    echo "  --no-compress             Skip compression of backup"
    echo "  --no-verify               Skip database integrity verification"
    echo "  --configure-remote        Run interactive remote storage setup"
    echo "  --test-remote             Test remote storage connection"
    echo "  --no-remote               Disable remote storage for this run"
    echo "  --local-only              Keep local backups (don't delete after upload)"
    echo "  --cleanup                 Clean up all existing backups"
    echo "  -v, --version             Show version information"
    echo "  -h, --help                Show this help message"
    echo "  --dry-run                 Show what would be backed up without doing it"
    echo
    echo "Features:"
    echo "  • Database integrity verification using SQLite PRAGMA checks"
    echo "  • Intelligent compression with pigz (parallel) or gzip fallback"
    echo "  • Safe container stopping to prevent database corruption"
    echo "  • Interactive container selection and confirmation prompts"
    echo "  • Automatic log file generation alongside backups"
    echo "  • Comprehensive backup reports with system information"
    echo
    echo "Log Files:"
    echo "  • Session logs stored in: $LOG_DIR/gntech-jellyfin-backup.log"
    echo "  • Backup-specific logs created alongside compressed files (.log extension)"
    echo "  • Logs include container info, backup size, and session details"
    echo
    echo "Examples:"
    echo "  $0                        Interactive mode with full verification"
    echo "  $0 --all                  Backup all containers with compression"
    echo "  $0 -c jellyfin_main       Backup specific container"
    echo "  $0 --list                 List containers only"
    echo "  $0 --dry-run --all        Show backup plan without executing"
    echo "  $0 -c vfx --no-compress   Backup without compression"
}

# Perform dry run
perform_dry_run() {
    local container_name=$1
    
    echo -e "${CYAN}=== DRY RUN MODE - No actual backup will be performed ===${NC}"
    echo
    
    log_message "INFO" "DRY RUN: Analyzing container: $container_name"
    
    local container_status=$(docker inspect "$container_name" --format '{{.State.Status}}' 2>/dev/null || echo "not_found")
    
    if [ "$container_status" = "not_found" ]; then
        echo -e "${RED}Container $container_name not found${NC}"
        return 1
    fi
    
    echo "Container Status: $container_status"
    
    if [ "$STOP_CONTAINER_FOR_BACKUP" = "true" ] && [ "$container_status" = "running" ]; then
        echo -e "${YELLOW}⚠️  Container would be STOPPED for backup${NC}"
    else
        echo -e "${BLUE}ℹ️  Container would remain running during backup${NC}"
    fi
    
    echo
    echo "Mount points that would be backed up:"
    
    local source_dir="/opt/$container_name"
    if [ -d "$source_dir" ]; then
        local source_size=$(du -sh "$source_dir" 2>/dev/null | cut -f1 || echo "Unknown")
        echo -e "  ${CHECK_MARK} $source_dir → config ($source_size)"
    fi
    
    # Check for additional common mounts
    for mount_dir in "/opt/scripts" "/dev/shm"; do
        if [ -d "$mount_dir" ]; then
            local mount_size=$(du -sh "$mount_dir" 2>/dev/null | cut -f1 || echo "0")
            local mount_name=$(basename "$mount_dir")
            echo -e "  ${CHECK_MARK} $mount_dir → $mount_name ($mount_size)"
        fi
    done
    
    echo
    echo "Estimated backup size: $(du -sh "$source_dir" 2>/dev/null | cut -f1 || echo "Unknown")"
    echo
    echo "Patterns that would be excluded:"
    echo "  */logs/*"
    echo "  */cache/*"
    echo "  */transcodes/*"
    echo "  */temp/*"
    echo "  */tmp/*"
    echo "  /mnt/*"
    echo "  *.log"
    echo "  *.tmp"
    echo
    
    local timestamp=$(date '+%Y%m%d_%H%M%S')
    echo "Backup destination would be: $BACKUP_BASE_DIR/$timestamp/$container_name/"
}

# Main function
main() {
    # Initialize variables
    BACKUP_MODE="interactive"
    TARGET_CONTAINER=""
    DRY_RUN=false
    
    # Parse command line arguments
    parse_arguments "$@"
    
    # Ensure all required directories exist
    ensure_directories
    
    # Load remote storage configuration
    load_remote_config

    # Install prerequisites if missing
    install_prerequisites
    
    # Start logging
    log_message "INFO" "Starting $SCRIPT_NAME v$SCRIPT_VERSION"
    
    # Perform health checks
    if ! perform_health_checks; then
        log_message "ERROR" "Health checks failed, aborting backup"
        exit 1
    fi
    
    # Check prerequisites
    if ! check_docker; then
        exit 1
    fi
    
    # Create backup base directory
    mkdir -p "$BACKUP_BASE_DIR"
    
    # Handle non-interactive modes
    case "$BACKUP_MODE" in
        "list")
            echo -e "${YELLOW}Discovered Jellyfin containers:${NC}"
            discover_jellyfin_containers
            exit 0
            ;;
        "single")
            if [ -z "$TARGET_CONTAINER" ]; then
                log_message "ERROR" "No container specified"
                exit 1
            fi
            
            if [ "$DRY_RUN" = "true" ]; then
                perform_dry_run "$TARGET_CONTAINER"
                exit $?
            fi
            
            backup_path=$(create_backup_structure)
            if [ $? -eq 0 ]; then
                if backup_container_data "$TARGET_CONTAINER" "$backup_path"; then
                    echo -e "${GREEN}${CHECK_MARK} Backup completed successfully${NC}"
                    exit 0
                else
                    echo -e "${RED}${CROSS_MARK} Backup failed${NC}"
                    exit 1
                fi
            fi
            exit 1
            ;;
        "all")
            # Get all Jellyfin containers
            local containers=$(docker ps -a --format "{{.Names}}" | grep -i jellyfin || true)
            if [ -z "$containers" ]; then
                log_message "ERROR" "No Jellyfin containers found"
                exit 1
            fi
            
            if [ "$DRY_RUN" = "true" ]; then
                echo -e "${CYAN}=== DRY RUN: All Containers ===${NC}"
                while IFS= read -r container; do
                    echo
                    perform_dry_run "$container"
                done <<< "$containers"
                exit 0
            fi
            
            backup_path=$(create_backup_structure)
            if [ $? -eq 0 ]; then
                local success_count=0
                local total_count=0
                
                while IFS= read -r container; do
                    ((total_count++))
                    if backup_container_data "$container" "$backup_path"; then
                        ((success_count++))
                    fi
                done <<< "$containers"
                
                echo
                echo -e "${CYAN}=== Backup Summary ===${NC}"
                echo -e "Total containers: $total_count"
                echo -e "Successful backups: $success_count"
                
                if [ $success_count -eq $total_count ]; then
                    echo -e "${GREEN}${CHECK_MARK} All containers backed up successfully${NC}"
                    exit 0
                else
                    echo -e "${YELLOW}${WARNING_SIGN} Some backups failed${NC}"
                    exit 1
                fi
            fi
            exit 1
            ;;
        "cleanup")
            cleanup_all_backups
            exit $?
            ;;
    esac
    
    # Main interactive loop
    while true; do
        show_banner
        show_menu
        choice=$(get_menu_choice)
        
        case $choice in
            1)
                echo -e "${YELLOW}Discovering Jellyfin containers...${NC}"
                discover_jellyfin_containers
                read -p "Press Enter to continue..."
                ;;
            2)
                echo -e "${YELLOW}Listing all available containers...${NC}"
                list_all_containers
                read -p "Press Enter to continue..."
                ;;
            3)
                echo -e "${YELLOW}Starting container backup process...${NC}"
                
                # Debug: Check if Docker is available
                if ! command -v docker >/dev/null 2>&1; then
                    echo -e "${RED}Error: Docker is not installed or not in PATH${NC}"
                    read -p "Press Enter to continue..."
                    continue
                fi
                
                # Debug: Check if Docker daemon is running (with timeout)
                echo -e "${CYAN}Checking Docker daemon status...${NC}"
                if ! timeout 5 docker info >/dev/null 2>&1; then
                    echo -e "${RED}Error: Docker daemon is not running or not responding${NC}"
                    read -p "Press Enter to continue..."
                    continue
                fi
                
                echo -e "${GREEN}Docker is available and running${NC}"
                echo -e "${CYAN}Calling select_container function...${NC}"
                
                container_name=$(select_container)
                select_result=$?
                
                echo -e "${CYAN}Debug: select_container returned code: $select_result${NC}"
                echo -e "${CYAN}Debug: container_name: '$container_name'${NC}"
                
                if [ $select_result -eq 0 ] && [ ! -z "$container_name" ]; then
                    echo -e "${GREEN}Container selected: $container_name${NC}"
                    backup_path=$(create_backup_structure)
                    if [ $? -eq 0 ]; then
                        backup_container_data "$container_name" "$backup_path"
                    else
                        echo -e "${RED}Failed to create backup structure${NC}"
                    fi
                else
                    echo -e "${YELLOW}Container backup cancelled or failed (exit code: $select_result)${NC}"
                fi
                read -p "Press Enter to continue..."
                ;;
            4)
                echo -e "${YELLOW}Starting backup of all Jellyfin containers...${NC}"
                local containers=$(docker ps -a --format "{{.Names}}" | grep -i jellyfin || true)
                if [ ! -z "$containers" ]; then
                    backup_path=$(create_backup_structure)
                    if [ $? -eq 0 ]; then
                        while IFS= read -r container; do
                            backup_container_data "$container" "$backup_path"
                        done <<< "$containers"
                    fi
                else
                    echo -e "${YELLOW}No Jellyfin containers found${NC}"
                fi
                read -p "Press Enter to continue..."
                ;;
            5)
                container_name=$(select_container)
                if [ ! -z "$container_name" ]; then
                    echo -e "${YELLOW}Mount points for $container_name:${NC}"
                    get_container_mounts "$container_name"
                fi
                read -p "Press Enter to continue..."
                ;;
            6)
                configure_settings
                read -p "Press Enter to continue..."
                ;;
            7)
                echo -e "${YELLOW}Configuring remote storage...${NC}"
                # Try different locations for the configure script
                if [ -f "$SCRIPT_DIR/scripts/configure-remote.sh" ]; then
                    # Running from git repository
                    "$SCRIPT_DIR/scripts/configure-remote.sh"
                elif [ -f "$SCRIPT_DIR/jellyfin-guardian-configure" ]; then
                    # Installed version - script is in same directory
                    "$SCRIPT_DIR/jellyfin-guardian-configure"
                elif command -v jellyfin-guardian-configure >/dev/null 2>&1; then
                    # Installed version - script is in PATH
                    jellyfin-guardian-configure
                else
                    echo -e "${RED}Remote configuration script not found${NC}"
                    echo -e "${YELLOW}Please ensure jellyfin-guardian is properly installed${NC}"
                fi
                read -p "Press Enter to continue..."
                ;;
            8)
                echo -e "${YELLOW}Testing remote storage connection...${NC}"
                load_remote_config
                test_remote_storage
                read -p "Press Enter to continue..."
                ;;
            9)
                view_backup_history
                read -p "Press Enter to continue..."
                ;;
            10)
                cleanup_all_backups
                read -p "Press Enter to continue..."
                ;;
            11)
                log_message "INFO" "Backup script terminated by user"
                echo -e "${GREEN}Thank you for using GNTECH Solutions Backup Script!${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid option. Please try again.${NC}"
                sleep 2
                ;;
        esac
    done
}

# Script entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
