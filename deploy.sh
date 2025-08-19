#!/bin/bash

# GNTECH Solutions - Jellyfin Backup Script Deployment
# Version: 2.1 (Log Enhancement Release)
# Deploy script to remote servers

set -euo pipefail

SCRIPT_VERSION="2.1"
REMOTE_USER="gnolasco"
REMOTE_HOST="88.198.67.197"
REMOTE_PATH="/home/gnolasco"

echo "========================================"
echo "GNTECH Solutions - Deployment Script"
echo "Jellyfin Backup v$SCRIPT_VERSION"
echo "========================================"
echo

# Check if script exists
if [ ! -f "jellyfin-backup.sh" ]; then
    echo "[ERROR] jellyfin-backup.sh not found in current directory"
    exit 1
fi

echo "[INFO] Deploying to: $REMOTE_USER@$REMOTE_HOST:$REMOTE_PATH"
echo

# Deploy main script
echo "[INFO] Copying jellyfin-backup.sh..."
if scp jellyfin-backup.sh "$REMOTE_USER@$REMOTE_HOST:$REMOTE_PATH/"; then
    echo "[SUCCESS] Script deployed successfully"
else
    echo "[ERROR] Failed to deploy script"
    exit 1
fi

# Deploy configuration file if exists
if [ -f "jellyfin-backup.conf" ]; then
    echo "[INFO] Copying configuration file..."
    if scp jellyfin-backup.conf "$REMOTE_USER@$REMOTE_HOST:$REMOTE_PATH/"; then
        echo "[SUCCESS] Configuration deployed successfully"
    else
        echo "[WARNING] Failed to deploy configuration file"
    fi
fi

# Make script executable on remote server
echo "[INFO] Making script executable on remote server..."
if ssh "$REMOTE_USER@$REMOTE_HOST" "chmod +x $REMOTE_PATH/jellyfin-backup.sh"; then
    echo "[SUCCESS] Script permissions set"
else
    echo "[ERROR] Failed to set script permissions"
    exit 1
fi

# Test deployment
echo
echo "[INFO] Testing deployment..."
if ssh "$REMOTE_USER@$REMOTE_HOST" "$REMOTE_PATH/jellyfin-backup.sh --version"; then
    echo
    echo "[SUCCESS] Deployment completed successfully!"
    echo "[INFO] Script is ready to use on the remote server"
    echo
    echo "Usage on remote server:"
    echo "  ssh $REMOTE_USER@$REMOTE_HOST"
    echo "  ./jellyfin-backup.sh --help"
else
    echo "[ERROR] Deployment test failed"
    exit 1
fi
