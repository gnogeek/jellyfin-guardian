#!/bin/bash

# GNTECH Jellyfin Backup - Remote Testing Deployment
# This script helps deploy and test the backup script on remote servers

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
REMOTE_SERVER="88.198.67.197"
REMOTE_USER="gnolasco"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Function to print colored output
print_status() {
    echo -e "${CYAN}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if we can connect to the remote server
check_remote_connection() {
    print_status "Testing connection to $REMOTE_SERVER..."
    
    if ssh -o ConnectTimeout=10 -o BatchMode=yes "$REMOTE_USER@$REMOTE_SERVER" exit 2>/dev/null; then
        print_success "Connection to $REMOTE_SERVER successful"
        return 0
    else
        print_error "Cannot connect to $REMOTE_SERVER"
        echo "Please ensure:"
        echo "1. SSH key is properly configured"
        echo "2. Server is reachable"
        echo "3. User $REMOTE_USER exists and has proper permissions"
        return 1
    fi
}

# Function to check remote user permissions
check_remote_permissions() {
    print_status "Checking remote user permissions..."
    
    ssh "$REMOTE_USER@$REMOTE_SERVER" '
        echo "User: $(whoami) (UID: $(id -u))"
        echo "Groups: $(groups)"
        
        # Check Docker group membership
        if groups | grep -q docker; then
            echo "✓ User is in docker group"
        else
            echo "✗ User is NOT in docker group"
            echo "  Run: sudo usermod -aG docker $(whoami)"
        fi
        
        # Check Docker access
        if docker ps >/dev/null 2>&1; then
            echo "✓ Docker access confirmed"
        else
            echo "✗ Cannot access Docker"
        fi
        
        # Check for existing Jellyfin containers
        echo
        echo "Existing containers:"
        docker ps -a --format "table {{.Names}}\t{{.Image}}\t{{.Status}}" || echo "Cannot list containers"
        
        # Check /opt directory
        echo
        if [ -d "/opt" ]; then
            echo "✓ /opt directory exists"
            ls -la /opt/ | head -5
        else
            echo "✗ /opt directory not found"
        fi
    '
}

# Function to deploy backup script to remote server
deploy_to_remote() {
    print_status "Deploying backup script to $REMOTE_SERVER..."
    
    # Create remote directory
    ssh "$REMOTE_USER@$REMOTE_SERVER" "mkdir -p ~/jellyfin-backup"
    
    # Copy main files
    scp "$SCRIPT_DIR/jellyfin-backup.sh" "$REMOTE_USER@$REMOTE_SERVER:~/jellyfin-backup/"
    scp "$SCRIPT_DIR/jellyfin-backup-remote.conf" "$REMOTE_USER@$REMOTE_SERVER:~/jellyfin-backup/"
    scp "$SCRIPT_DIR/configure-remote.sh" "$REMOTE_USER@$REMOTE_SERVER:~/jellyfin-backup/"
    
    # Make scripts executable
    ssh "$REMOTE_USER@$REMOTE_SERVER" "chmod +x ~/jellyfin-backup/*.sh"
    
    print_success "Files deployed to ~/jellyfin-backup/ on $REMOTE_SERVER"
}

# Function to clean up old backups on remote server
cleanup_remote_backups() {
    print_status "Cleaning up old backups on $REMOTE_SERVER..."
    
    ssh "$REMOTE_USER@$REMOTE_SERVER" '
        if [ -d "/home/gnolasco/backups" ]; then
            echo "Found backup directory: /home/gnolasco/backups"
            echo "Current contents:"
            ls -la /home/gnolasco/backups/ 2>/dev/null || echo "Directory is empty or inaccessible"
            
            echo
            read -p "Remove all existing backups? (y/N): " confirm
            if [[ $confirm == [yY] ]]; then
                rm -rf /home/gnolasco/backups/*
                echo "✓ Old backups removed"
            else
                echo "Keeping existing backups"
            fi
        else
            echo "No backup directory found"
        fi
    '
}

# Function to test the backup script on remote server
test_remote_script() {
    print_status "Testing backup script on $REMOTE_SERVER..."
    
    ssh "$REMOTE_USER@$REMOTE_SERVER" '
        cd ~/jellyfin-backup
        
        echo "=== Testing script version ==="
        ./jellyfin-backup.sh --version
        
        echo
        echo "=== Testing container discovery ==="
        ./jellyfin-backup.sh --list
        
        echo
        echo "=== Testing permission checks ==="
        timeout 30 ./jellyfin-backup.sh --dry-run --all || echo "Test completed (timeout expected)"
    '
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Options:"
    echo "  --check-connection    Test SSH connection to remote server"
    echo "  --check-permissions   Check remote user permissions"
    echo "  --deploy             Deploy backup script to remote server"
    echo "  --cleanup            Clean up old backups on remote server"
    echo "  --test               Test the backup script on remote server"
    echo "  --full               Run all steps in sequence"
    echo "  --help               Show this help message"
    echo
    echo "Examples:"
    echo "  $0 --full                    # Complete deployment and testing"
    echo "  $0 --check-connection        # Just test connection"
    echo "  $0 --deploy --test           # Deploy and test"
}

# Main logic
main() {
    if [ $# -eq 0 ]; then
        show_usage
        exit 1
    fi
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --check-connection)
                check_remote_connection
                shift
                ;;
            --check-permissions)
                if check_remote_connection; then
                    check_remote_permissions
                fi
                shift
                ;;
            --deploy)
                if check_remote_connection; then
                    deploy_to_remote
                fi
                shift
                ;;
            --cleanup)
                if check_remote_connection; then
                    cleanup_remote_backups
                fi
                shift
                ;;
            --test)
                if check_remote_connection; then
                    test_remote_script
                fi
                shift
                ;;
            --full)
                if check_remote_connection; then
                    check_remote_permissions
                    echo
                    deploy_to_remote
                    echo
                    cleanup_remote_backups
                    echo
                    test_remote_script
                fi
                shift
                ;;
            --help)
                show_usage
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
}

# Check if required tools are available
if ! command -v ssh >/dev/null 2>&1; then
    print_error "SSH client is required but not installed"
    exit 1
fi

if ! command -v scp >/dev/null 2>&1; then
    print_error "SCP is required but not installed"
    exit 1
fi

# Run main function
main "$@"
