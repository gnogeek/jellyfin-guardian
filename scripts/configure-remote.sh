#!/bin/bash

# GNTECH Jellyfin Guardian - Remote Storage Configuration Wizard
# Interactive setup for remote backup storage

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/jellyfin-backup-remote.conf"
TEMP_CONFIG="/tmp/jellyfin-remote-config-$$.tmp"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

echo -e "${CYAN}========================================"
echo -e "🛡️  GNTECH Jellyfin Guardian"
echo -e "Remote Storage Configuration Wizard"
echo -e "========================================${NC}"
echo

# Check if config already exists
if [ -f "$CONFIG_FILE" ]; then
    echo -e "${YELLOW}⚠️  Remote storage configuration already exists.${NC}"
    echo -n "Do you want to reconfigure? (y/N): "
    read -r reconfigure
    if [[ ! "$reconfigure" =~ ^[Yy] ]]; then
        echo "Configuration cancelled."
        exit 0
    fi
    echo
fi

# Copy template
cp "$CONFIG_FILE" "$TEMP_CONFIG"

echo -e "${WHITE}Let's set up your remote backup storage!${NC}"
echo "This wizard will help you configure secure remote storage for your Jellyfin backups."
echo

# Enable remote storage
echo -e "${BLUE}=== Remote Storage Setup ===${NC}"
echo -n "Enable remote storage for backups? (Y/n): "
read -r enable_remote
if [[ "$enable_remote" =~ ^[Nn] ]]; then
    sed -i 's/REMOTE_STORAGE_ENABLED=.*/REMOTE_STORAGE_ENABLED=false/' "$TEMP_CONFIG"
    echo "Remote storage disabled. Local backups only."
    mv "$TEMP_CONFIG" "$CONFIG_FILE"
    exit 0
fi
sed -i 's/REMOTE_STORAGE_ENABLED=.*/REMOTE_STORAGE_ENABLED=true/' "$TEMP_CONFIG"

# Storage type selection
echo
echo -e "${BLUE}=== Storage Type Selection ===${NC}"
echo "Available remote storage options:"
echo "  1. SFTP/SSH Server (recommended - secure, reliable)"
echo "  2. S3-Compatible Storage (AWS S3, MinIO, DigitalOcean)"
echo "  3. Network File System (NFS)"
echo "  4. FTP/FTPS Server"
echo "  5. Cloud Storage via rclone (Google Drive, Dropbox, etc.)"
echo
echo -n "Select storage type (1-5): "
read -r storage_choice

case $storage_choice in
    1)
        STORAGE_TYPE="sftp"
        echo "Selected: SFTP/SSH Server"
        ;;
    2)
        STORAGE_TYPE="s3"
        echo "Selected: S3-Compatible Storage"
        ;;
    3)
        STORAGE_TYPE="nfs"
        echo "Selected: Network File System (NFS)"
        ;;
    4)
        STORAGE_TYPE="ftp"
        echo "Selected: FTP/FTPS Server"
        ;;
    5)
        STORAGE_TYPE="rclone"
        echo "Selected: Cloud Storage via rclone"
        ;;
    *)
        echo -e "${RED}Invalid selection. Defaulting to SFTP.${NC}"
        STORAGE_TYPE="sftp"
        ;;
esac

sed -i "s/REMOTE_STORAGE_TYPE=.*/REMOTE_STORAGE_TYPE=$STORAGE_TYPE/" "$TEMP_CONFIG"

# Configure based on storage type
configure_sftp() {
    echo
    echo -e "${BLUE}=== SFTP/SSH Configuration ===${NC}"
    
    echo -n "SFTP server hostname or IP: "
    read -r sftp_host
    sed -i "s/SFTP_HOST=.*/SFTP_HOST=$sftp_host/" "$TEMP_CONFIG"
    
    echo -n "SFTP port (default 22): "
    read -r sftp_port
    sftp_port=${sftp_port:-22}
    sed -i "s/SFTP_PORT=.*/SFTP_PORT=$sftp_port/" "$TEMP_CONFIG"
    
    echo -n "SFTP username: "
    read -r sftp_user
    sed -i "s/SFTP_USER=.*/SFTP_USER=$sftp_user/" "$TEMP_CONFIG"
    
    echo -n "Remote backup path (default /home/backups/jellyfin): "
    read -r sftp_path
    sftp_path=${sftp_path:-/home/backups/jellyfin}
    sed -i "s|SFTP_PATH=.*|SFTP_PATH=$sftp_path|" "$TEMP_CONFIG"
    
    echo -n "SSH private key file (default ~/.ssh/id_rsa): "
    read -r ssh_key
    ssh_key=${ssh_key:-$HOME/.ssh/id_rsa}
    sed -i "s|SFTP_KEY_FILE=.*|SFTP_KEY_FILE=$ssh_key|" "$TEMP_CONFIG"
    
    echo
    echo -e "${YELLOW}💡 Testing SFTP connection...${NC}"
    if ssh -i "$ssh_key" -p "$sftp_port" -o ConnectTimeout=10 "$sftp_user@$sftp_host" "mkdir -p $sftp_path" 2>/dev/null; then
        echo -e "${GREEN}✅ SFTP connection successful!${NC}"
    else
        echo -e "${RED}⚠️  SFTP connection test failed. Please verify settings.${NC}"
    fi
}

configure_s3() {
    echo
    echo -e "${BLUE}=== S3-Compatible Storage Configuration ===${NC}"
    
    echo -n "S3 endpoint URL (leave empty for AWS S3): "
    read -r s3_endpoint
    sed -i "s|S3_ENDPOINT=.*|S3_ENDPOINT=$s3_endpoint|" "$TEMP_CONFIG"
    
    echo -n "S3 bucket name: "
    read -r s3_bucket
    sed -i "s/S3_BUCKET=.*/S3_BUCKET=$s3_bucket/" "$TEMP_CONFIG"
    
    echo -n "S3 access key: "
    read -r s3_access_key
    sed -i "s/S3_ACCESS_KEY=.*/S3_ACCESS_KEY=$s3_access_key/" "$TEMP_CONFIG"
    
    echo -n "S3 secret key: "
    read -s s3_secret_key
    echo
    sed -i "s/S3_SECRET_KEY=.*/S3_SECRET_KEY=$s3_secret_key/" "$TEMP_CONFIG"
    
    echo -n "S3 region (default us-east-1): "
    read -r s3_region
    s3_region=${s3_region:-us-east-1}
    sed -i "s/S3_REGION=.*/S3_REGION=$s3_region/" "$TEMP_CONFIG"
    
    echo -n "S3 path prefix (default jellyfin-backups): "
    read -r s3_path
    s3_path=${s3_path:-jellyfin-backups}
    sed -i "s/S3_PATH=.*/S3_PATH=$s3_path/" "$TEMP_CONFIG"
}

configure_nfs() {
    echo
    echo -e "${BLUE}=== NFS Configuration ===${NC}"
    
    echo -n "NFS server hostname or IP: "
    read -r nfs_host
    sed -i "s/NFS_HOST=.*/NFS_HOST=$nfs_host/" "$TEMP_CONFIG"
    
    echo -n "NFS export path: "
    read -r nfs_path
    sed -i "s|NFS_PATH=.*|NFS_PATH=$nfs_path|" "$TEMP_CONFIG"
    
    echo -n "Local mount point (default /mnt/backup-storage): "
    read -r nfs_mount
    nfs_mount=${nfs_mount:-/mnt/backup-storage}
    sed -i "s|NFS_MOUNT_POINT=.*|NFS_MOUNT_POINT=$nfs_mount|" "$TEMP_CONFIG"
    
    echo -n "NFS mount options (default rw,sync,hard,intr): "
    read -r nfs_options
    nfs_options=${nfs_options:-rw,sync,hard,intr}
    sed -i "s/NFS_OPTIONS=.*/NFS_OPTIONS=$nfs_options/" "$TEMP_CONFIG"
}

configure_ftp() {
    echo
    echo -e "${BLUE}=== FTP/FTPS Configuration ===${NC}"
    
    echo -n "FTP server hostname or IP: "
    read -r ftp_host
    sed -i "s/FTP_HOST=.*/FTP_HOST=$ftp_host/" "$TEMP_CONFIG"
    
    echo -n "FTP port (default 21): "
    read -r ftp_port
    ftp_port=${ftp_port:-21}
    sed -i "s/FTP_PORT=.*/FTP_PORT=$ftp_port/" "$TEMP_CONFIG"
    
    echo -n "FTP username: "
    read -r ftp_user
    sed -i "s/FTP_USER=.*/FTP_USER=$ftp_user/" "$TEMP_CONFIG"
    
    echo -n "FTP password: "
    read -s ftp_pass
    echo
    sed -i "s/FTP_PASS=.*/FTP_PASS=$ftp_pass/" "$TEMP_CONFIG"
    
    echo -n "FTP backup path (default /backups/jellyfin): "
    read -r ftp_path
    ftp_path=${ftp_path:-/backups/jellyfin}
    sed -i "s|FTP_PATH=.*|FTP_PATH=$ftp_path|" "$TEMP_CONFIG"
}

configure_rclone() {
    echo
    echo -e "${BLUE}=== Rclone Cloud Storage Configuration ===${NC}"
    echo "📋 Note: You need to configure rclone first with 'rclone config'"
    echo
    
    echo -n "Rclone remote name (e.g., 'gdrive:', 'dropbox:'): "
    read -r rclone_remote
    sed -i "s/RCLONE_REMOTE=.*/RCLONE_REMOTE=$rclone_remote/" "$TEMP_CONFIG"
    
    echo -n "Remote path (default jellyfin-backups): "
    read -r rclone_path
    rclone_path=${rclone_path:-jellyfin-backups}
    sed -i "s/RCLONE_PATH=.*/RCLONE_PATH=$rclone_path/" "$TEMP_CONFIG"
    
    if command -v rclone >/dev/null 2>&1; then
        echo -e "${YELLOW}💡 Testing rclone connection...${NC}"
        if rclone lsd "$rclone_remote" >/dev/null 2>&1; then
            echo -e "${GREEN}✅ Rclone connection successful!${NC}"
        else
            echo -e "${RED}⚠️  Rclone connection test failed. Please verify configuration.${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️  Rclone not installed. Install with: sudo apt install rclone${NC}"
    fi
}

# Configure storage type
case $STORAGE_TYPE in
    sftp) configure_sftp ;;
    s3) configure_s3 ;;
    nfs) configure_nfs ;;
    ftp) configure_ftp ;;
    rclone) configure_rclone ;;
esac

# Retention policies
echo
echo -e "${BLUE}=== Retention Policies ===${NC}"

echo -n "Local retention (keep last N backups locally, default 1): "
read -r local_retention
local_retention=${local_retention:-1}
sed -i "s/LOCAL_RETENTION=.*/LOCAL_RETENTION=$local_retention/" "$TEMP_CONFIG"

echo -n "Remote retention (keep last N backups remotely, default 3): "
read -r remote_retention
remote_retention=${remote_retention:-3}
sed -i "s/REMOTE_RETENTION=.*/REMOTE_RETENTION=$remote_retention/" "$TEMP_CONFIG"

echo -n "Enable long-term archive (monthly backups)? (y/N): "
read -r longterm
if [[ "$longterm" =~ ^[Yy] ]]; then
    sed -i 's/LONGTERM_ARCHIVE=.*/LONGTERM_ARCHIVE=true/' "$TEMP_CONFIG"
    echo -n "Long-term retention (months, default 12): "
    read -r longterm_retention
    longterm_retention=${longterm_retention:-12}
    sed -i "s/LONGTERM_RETENTION=.*/LONGTERM_RETENTION=$longterm_retention/" "$TEMP_CONFIG"
fi

# Transfer settings
echo
echo -e "${BLUE}=== Transfer Settings ===${NC}"

echo -n "Auto-upload after successful backup? (Y/n): "
read -r auto_upload
if [[ ! "$auto_upload" =~ ^[Nn] ]]; then
    sed -i 's/AUTO_UPLOAD=.*/AUTO_UPLOAD=true/' "$TEMP_CONFIG"
fi

echo -n "Delete local backup after successful upload? (Y/n): "
read -r delete_local
if [[ ! "$delete_local" =~ ^[Nn] ]]; then
    sed -i 's/DELETE_LOCAL_AFTER_UPLOAD=.*/DELETE_LOCAL_AFTER_UPLOAD=true/' "$TEMP_CONFIG"
fi

echo -n "Verify remote upload integrity? (Y/n): "
read -r verify_upload
if [[ ! "$verify_upload" =~ ^[Nn] ]]; then
    sed -i 's/VERIFY_REMOTE_UPLOAD=.*/VERIFY_REMOTE_UPLOAD=true/' "$TEMP_CONFIG"
fi

# Optional features
echo
echo -e "${BLUE}=== Optional Features ===${NC}"

echo -n "Enable backup encryption? (y/N): "
read -r encrypt
if [[ "$encrypt" =~ ^[Yy] ]]; then
    sed -i 's/ENCRYPT_REMOTE_BACKUPS=.*/ENCRYPT_REMOTE_BACKUPS=true/' "$TEMP_CONFIG"
    echo -n "Encryption password (leave empty to prompt each time): "
    read -s encryption_password
    echo
    if [ -n "$encryption_password" ]; then
        sed -i "s/ENCRYPTION_PASSWORD=.*/ENCRYPTION_PASSWORD=$encryption_password/" "$TEMP_CONFIG"
    fi
fi

echo -n "Enable notifications? (y/N): "
read -r notifications
if [[ "$notifications" =~ ^[Yy] ]]; then
    sed -i 's/NOTIFICATIONS_ENABLED=.*/NOTIFICATIONS_ENABLED=true/' "$TEMP_CONFIG"
    echo "Notification method:"
    echo "  1. Email"
    echo "  2. Webhook"
    echo "  3. Slack"
    echo -n "Select method (1-3): "
    read -r notification_method
    
    case $notification_method in
        1)
            sed -i 's/NOTIFICATION_METHOD=.*/NOTIFICATION_METHOD=email/' "$TEMP_CONFIG"
            echo -n "Email to: "
            read -r email_to
            sed -i "s/EMAIL_TO=.*/EMAIL_TO=$email_to/" "$TEMP_CONFIG"
            ;;
        2)
            sed -i 's/NOTIFICATION_METHOD=.*/NOTIFICATION_METHOD=webhook/' "$TEMP_CONFIG"
            echo -n "Webhook URL: "
            read -r webhook_url
            sed -i "s|WEBHOOK_URL=.*|WEBHOOK_URL=$webhook_url|" "$TEMP_CONFIG"
            ;;
        3)
            sed -i 's/NOTIFICATION_METHOD=.*/NOTIFICATION_METHOD=slack/' "$TEMP_CONFIG"
            echo -n "Slack webhook URL: "
            read -r slack_webhook
            sed -i "s|SLACK_WEBHOOK=.*|SLACK_WEBHOOK=$slack_webhook|" "$TEMP_CONFIG"
            ;;
    esac
fi

# Save configuration
mv "$TEMP_CONFIG" "$CONFIG_FILE"

echo
echo -e "${GREEN}========================================"
echo -e "✅ Configuration Complete!"
echo -e "========================================${NC}"
echo
echo "Configuration saved to: $CONFIG_FILE"
echo
echo "Next steps:"
echo "1. Test your configuration: ./jellyfin-backup.sh --test-remote"
echo "2. Run a backup: ./jellyfin-backup.sh"
echo "3. Check remote storage for uploaded backups"
echo
echo -e "${YELLOW}💡 Tip: You can edit $CONFIG_FILE manually for advanced settings.${NC}"
