#!/bin/bash

# GNTECH Jellyfin Guardian - GitHub Repository Setup
# This script prepares the repository for GitHub publication

set -euo pipefail

REPO_NAME="jellyfin-guardian"
GITHUB_ORG="gntech"  # Change this to your GitHub username/organization

echo "========================================"
echo "🛡️  GNTECH Jellyfin Guardian"
echo "GitHub Repository Setup"
echo "========================================"
echo

# Check if git is available
if ! command -v git >/dev/null 2>&1; then
    echo "[ERROR] Git is not installed. Please install git first."
    exit 1
fi

# Initialize git repository if not already initialized
if [ ! -d ".git" ]; then
    echo "[INFO] Initializing Git repository..."
    git init
    echo "[SUCCESS] Git repository initialized"
else
    echo "[INFO] Git repository already exists"
fi

# Create .gitkeep files for empty directories that should be tracked
echo "[INFO] Setting up directory structure..."
mkdir -p archive/old-versions archive/deprecated archive/test-scripts
touch archive/.gitkeep
touch archive/old-versions/.gitkeep
touch archive/deprecated/.gitkeep
touch archive/test-scripts/.gitkeep

# Move files to archive to clean up repository
echo "[INFO] Organizing repository structure..."

# Move old README to archive if it exists and is different from the GitHub version
if [ -f "README.md" ] && [ -f "README-GITHUB.md" ]; then
    if ! cmp -s "README.md" "README-GITHUB.md"; then
        mv "README.md" "archive/old-versions/README-local.md"
        echo "[INFO] Moved local README to archive"
    fi
fi

# Move the GitHub README to be the main README
if [ -f "README-GITHUB.md" ]; then
    mv "README-GITHUB.md" "README.md"
    echo "[INFO] Set GitHub README as main README"
fi

# Move old/test files to archive
if [ -f "simple-backup-test.sh" ]; then
    mv "simple-backup-test.sh" "archive/test-scripts/"
    echo "[INFO] Moved test script to archive"
fi

if [ -f "simple-test.sh" ]; then
    mv "simple-test.sh" "archive/test-scripts/"
    echo "[INFO] Moved simple test to archive"
fi

if [ -f "backup-monitor.sh" ]; then
    mv "backup-monitor.sh" "archive/deprecated/"
    echo "[INFO] Moved deprecated monitor script to archive"
fi

# Add all files to git
echo "[INFO] Adding files to git..."
git add .

# Check if there are any changes to commit
if git diff --staged --quiet; then
    echo "[INFO] No changes to commit"
else
    # Commit the initial version
    echo "[INFO] Creating initial commit..."
    git commit -m "🎉 Initial release: GNTECH Jellyfin Guardian v2.1

Features:
- 🔬 Pre-backup database verification
- ⚡ High-performance compression pipeline (239MiB/s)
- 🛡️ Safe container management (<10s downtime)
- 📊 Real-time progress tracking
- 🤖 Auto-prerequisite installation
- 📝 Comprehensive logging system
- 🚀 Remote deployment ready

Professional-grade backup solution for Jellyfin containers with enterprise features."

    echo "[SUCCESS] Initial commit created"
fi

# Set up remote origin (you'll need to create the repository on GitHub first)
echo
echo "========================================"
echo "🚀 Next Steps:"
echo "========================================"
echo
echo "1. Create a repository on GitHub:"
echo "   - Go to https://github.com/new"
echo "   - Repository name: $REPO_NAME"
echo "   - Description: Professional-grade backup guardian for Jellyfin containers"
echo "   - Make it public"
echo "   - Don't initialize with README (we already have one)"
echo
echo "2. Add the remote origin and push:"
echo "   git remote add origin https://github.com/$GITHUB_ORG/$REPO_NAME.git"
echo "   git branch -M main"
echo "   git push -u origin main"
echo
echo "3. Optional: Create a release tag:"
echo "   git tag -a v2.1.0 -m 'Release v2.1.0: Log Enhancement Release'"
echo "   git push origin v2.1.0"
echo
echo "4. Update the GitHub repository settings:"
echo "   - Add topics: jellyfin, backup, docker, containers, media-server"
echo "   - Set up GitHub Pages for documentation (optional)"
echo "   - Configure branch protection rules (optional)"
echo

echo "[SUCCESS] Repository is ready for GitHub! 🎉"
echo
echo "Repository structure:"
find . -type f -name "*.sh" -o -name "*.md" -o -name "*.conf" -o -name "*.txt" | grep -v ".git" | sort
