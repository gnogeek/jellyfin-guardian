# Changelog

All notable changes to the GNTECH Jellyfin Guardian will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.2.0] - 2025-08-19 - Remote Storage Release

### 🚀 Major Features Added
- **Multi-Provider Remote Storage**: Support for SFTP, S3, NFS, FTP, and rclone
- **Interactive Configuration Wizard**: Guided setup for remote storage providers
- **Intelligent Retention Policies**: Separate local (default: 1) and remote (default: 3) retention
- **Automatic Upload & Cleanup**: Upload after backup with automatic old backup cleanup
- **Remote Backup Verification**: Integrity checks for uploaded backups

### 🎯 Remote Storage Providers
- **SFTP/SSH**: Secure, reliable, recommended for most users
- **S3-Compatible**: AWS S3, MinIO, DigitalOcean Spaces, etc.
- **Network File System**: NFS mounts for local network storage
- **FTP/FTPS**: Traditional file transfer (less secure)
- **Cloud Storage**: Google Drive, Dropbox, OneDrive via rclone

### 🔧 New CLI Options
- `--configure-remote`: Launch interactive remote storage setup
- `--test-remote`: Test remote storage connection
- `--no-remote`: Disable remote storage for current run
- `--local-only`: Keep local backups (don't delete after upload)

### 🏗️ Architecture Improvements
- **Local Space Management**: Keep only latest backup locally by default
- **Remote Redundancy**: Store multiple backups remotely for safety
- **Progress Tracking**: Upload progress with pv integration
- **Error Handling**: Comprehensive retry and fallback mechanisms

### 📋 New Configuration Features
- **Interactive Setup**: Guided configuration on first run
- **Connection Testing**: Verify settings before backup
- **Advanced Options**: Encryption, notifications, bandwidth limits
- **Multi-server Support**: Different storage for different servers

## [2.1.0] - 2025-08-19 - Log Enhancement Release

### 🆕 New Features
- **Backup-Specific Log Files**: Automatic creation of detailed log files alongside each backup
- **Comprehensive Backup Reports**: Each backup now includes a detailed .log file with:
  - Container information and configuration
  - Backup size statistics and compression ratios
  - System information (disk space, load averages)
  - Complete session log entries for troubleshooting
  - Error details and recovery information

### 🔧 Improvements
- **Enhanced Help Documentation**: Updated help text to document log file locations and contents
- **Session Logging**: Improved session log entries for better backup process tracking
- **Log File Management**: Intelligent log file placement (same directory as backup files)

## [2.0.0] - 2025-08-19 - Production Release

### 🎉 Major Features Added
- **Real-time Progress Tracking**: Live progress bars with transfer rates, ETA, and visual indicators using `pv`
- **Pre-backup Database Verification**: SQLite integrity checks before backup starts to prevent backing up corrupted data
- **Automatic Prerequisite Installation**: Auto-installs missing tools (sqlite3, pv, pigz, rsync) with package manager detection
- **Direct Compression Pipeline**: Eliminates intermediate files with tar → pv → pigz streaming pipeline

### 🚀 Performance Improvements
- **239MiB/s Compression Speed**: Optimized compression pipeline with parallel processing
- **13% Space Reduction**: Intelligent compression achieving 23GB → 20GB
- **<10 Second Container Downtime**: Optimized container stop/start process
- **Multi-core Utilization**: Parallel compression with pigz using all available CPU cores

### 🛡️ Safety Enhancements
- **Enhanced Container Management**: Improved stop/start logic with status verification
- **Graceful Error Handling**: Comprehensive rollback mechanisms on failure
- **Data Integrity Verification**: Multiple checkpoints to ensure backup validity
- **User Confirmation Prompts**: Interactive safety confirmations for destructive operations

### 🔧 Technical Improvements
- **Command Line Interface**: Comprehensive CLI options for automation
- **Configuration Management**: Support for custom config files and environment variables
- **Logging System**: Detailed timestamped logs with multiple severity levels
- **Error Propagation**: Proper exit codes and error handling throughout

### 🐛 Critical Fixes
- **ANSI Escape Sequence Corruption**: Fixed directory names being corrupted by color codes
- **Path Construction Issues**: Resolved backup path corruption causing failed backups
- **Visual Interference**: Eliminated progress indicators interfering with backup operations
- **Function Output Conflicts**: Fixed function return values being polluted by log messages

### 🎯 Usability Improvements
- **Progress Feedback**: Real-time visual feedback for all long-running operations
- **Container Status Display**: Clear indication of container states and actions
- **Interactive Prompts**: User-friendly confirmation dialogs
- **Help Documentation**: Comprehensive help text with examples

## [1.1.0] - 2025-08-18 - Clean Version

### 🔧 Fixes
- **Visual Interference Removal**: Removed ANSI color codes causing backup path corruption
- **Directory Creation**: Fixed backup directory creation issues
- **Function Cleanup**: Simplified logging functions to prevent command interference

### 🚀 Improvements
- **Container Discovery**: Enhanced Jellyfin container detection
- **Error Messages**: Clearer error reporting without visual formatting conflicts
- **Backup Validation**: Added backup size and file count reporting

## [1.0.0] - 2025-08-17 - Initial Release

### 🎉 Features
- **Interactive Container Selection**: Menu-driven interface for choosing containers
- **Basic Backup Functionality**: Core backup capabilities for Jellyfin containers
- **Container Safety**: Basic container stop/start management
- **Exclusion Patterns**: Automatic exclusion of logs, cache, and temporary files
- **GNTECH Branding**: Professional interface with company branding

### 🏗️ Architecture
- **Bash Script Foundation**: Robust shell script architecture
- **Docker Integration**: Direct Docker API usage for container management
- **rsync Backend**: Reliable file synchronization with rsync
- **Modular Design**: Function-based architecture for maintainability

---

## Performance Benchmarks

### Version 2.0 vs 1.0 Comparison

| Metric | v1.0 | v2.0 | Improvement |
|--------|------|------|-------------|
| Backup Speed | ~50MB/s | 239MB/s | **378% faster** |
| Compression Ratio | None | 13% | **Space savings** |
| Database Verification | None | 4 databases | **Data integrity** |
| Progress Feedback | None | Real-time | **User experience** |
| Error Handling | Basic | Comprehensive | **Reliability** |
| Container Downtime | ~30s | <10s | **67% reduction** |

### Real-world Performance (23GB Container)
- **Total Time**: 1 minute 34 seconds
- **Transfer Rate**: 239MiB/s sustained
- **Final Size**: 20GB (13% compression)
- **Database Check**: <5 seconds
- **Container Restart**: <3 seconds
