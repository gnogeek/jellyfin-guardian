# GNTECH Solutions - Jellyfin Backup Script

[![Version](https://img.shields.io/badge/version-2.0-blue.svg)](https://github.com/gntech/jellyfin-backup)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Shell](https://img.shields.io/badge/shell-bash-orange.svg)](https://www.gnu.org/software/bash/)

Professional-grade backup solution for Jellyfin containers running on remote servers with enterprise features including database verification, real-time progress tracking, and intelligent compression.

## 🚀 Features

### Core Functionality
- **🔍 Pre-backup Database Verification** - SQLite integrity checks before backup starts
- **📊 Real-time Progress Tracking** - Live progress bars with transfer rates and ETA
- **🗜️ Intelligent Compression** - Direct compression with pigz (parallel) or gzip fallback
- **🔄 Safe Container Management** - Graceful stop/start to prevent database corruption
- **🎯 Interactive Container Selection** - Choose specific containers or backup all
- **⚡ High Performance** - 239MiB/s compression speeds with 13% size reduction

### Advanced Features
- **🔧 Auto-prerequisite Installation** - Installs required tools automatically
- **💾 Space-efficient Backups** - Direct compression (no intermediate files)
- **🛡️ Data Integrity** - Comprehensive verification before and after backup
- **📱 Remote Deployment Ready** - Optimized for SSH and remote servers
- **📋 Comprehensive Logging** - Detailed logs with timestamps
- **🎛️ Flexible Configuration** - Command-line options and config files

## 📦 Quick Start

### Installation

```bash
# Clone the repository
git clone https://github.com/gntech/jellyfin-backup.git
cd jellyfin-backup

# Make script executable
chmod +x jellyfin-backup.sh

# Deploy to remote server
./deploy.sh
```

### Basic Usage

```bash
# Interactive mode with full verification and compression
./jellyfin-backup.sh

# Backup specific container
./jellyfin-backup.sh -c vfx

# Backup all Jellyfin containers
./jellyfin-backup.sh --all

# List available containers
./jellyfin-backup.sh --list

# Dry run (show what would be backed up)
./jellyfin-backup.sh --dry-run --all
```

## 📋 Requirements

### System Requirements
- **OS**: Linux (Ubuntu, Debian, CentOS, RHEL)
- **Shell**: Bash 4.0+
- **Docker**: Any recent version
- **Disk Space**: 2x container size (for compression)

### Auto-installed Prerequisites
The script automatically installs these tools if missing:
- `sqlite3` - Database integrity verification
- `pv` - Progress display
- `pigz` - Parallel compression (falls back to gzip)
- `rsync` - File synchronization

## 🎛️ Command Line Options

```
Usage: ./jellyfin-backup.sh [OPTIONS]

Options:
  -c, --container NAME      Backup specific container
  -a, --all                 Backup all Jellyfin containers
  -l, --list                List discovered containers only
  -n, --no-stop             Don't stop containers during backup
  -d, --backup-dir DIR      Override backup directory
  --no-compress             Skip compression of backup
  --no-verify               Skip database integrity verification
  -v, --version             Show version information
  -h, --help                Show this help message
  --dry-run                 Show what would be backed up without doing it

Examples:
  ./jellyfin-backup.sh                           Interactive mode with full verification
  ./jellyfin-backup.sh --all                     Backup all containers with compression
  ./jellyfin-backup.sh -c jellyfin_main          Backup specific container
  ./jellyfin-backup.sh --list                    List containers only
  ./jellyfin-backup.sh --dry-run --all           Show backup plan without executing
  ./jellyfin-backup.sh -c vfx --no-compress      Backup without compression
```

## 📊 Performance Metrics

### Benchmark Results (23GB Jellyfin Container)
- **Compression Speed**: 239MiB/s
- **Backup Time**: 1 minute 34 seconds
- **Compression Ratio**: 23GB → 20GB (13% reduction)
- **Database Verification**: 4 databases verified in <5 seconds
- **Container Downtime**: <10 seconds (stop/start)

### Optimizations
- **Parallel Compression**: Uses all available CPU cores
- **Direct Streaming**: tar → pv → pigz → file (no intermediate storage)
- **Intelligent Exclusions**: Skips logs, cache, transcodes, temp files
- **Progress Tracking**: Real-time feedback without performance impact

## 🏗️ Architecture

### Backup Process Flow
```
1. Prerequisites Check → Install missing tools
2. Container Discovery → Find Jellyfin containers  
3. Pre-backup Verification → Check database integrity
4. Container Management → Safe stop if running
5. Direct Compression → tar | pv | pigz > backup.tar.gz
6. Container Restart → Restore original state
7. Verification → Confirm backup integrity
```

### Directory Structure
```
jellyfin-backups/
├── 20250819_142922/
│   └── vfx_20250819_142934.tar.gz    # Compressed backup
├── 20250819_135933/
│   └── vfx_20250819_135947.tar.gz
└── logs/
    └── gntech-jellyfin-backup.log     # Detailed logs
```

## 🔧 Configuration

### Default Settings
```bash
BACKUP_BASE_DIR="$HOME/jellyfin-backups"
STOP_CONTAINER_FOR_BACKUP=true
ENABLE_COMPRESSION=true
METADATA_INTEGRITY_CHECK=true
BACKUP_RETENTION_DAYS=3
```

### Custom Configuration
Create `~/.config/gntech/jellyfin-backup.conf`:
```bash
# Custom backup directory
BACKUP_BASE_DIR="/mnt/backups/jellyfin"

# Disable container stopping (not recommended)
STOP_CONTAINER_FOR_BACKUP=false

# Compression settings
COMPRESSION_LEVEL=6
AUTO_REMOVE_UNCOMPRESSED=true
```

## 🛡️ Safety Features

### Database Integrity
- **Pre-backup Verification**: Checks SQLite databases before backup
- **PRAGMA integrity_check**: Comprehensive database validation
- **Abort on Corruption**: Stops backup if databases are corrupted

### Container Safety
- **Graceful Shutdown**: Proper container stop with timeout
- **Data Consistency**: Prevents database corruption during backup
- **Automatic Restart**: Restores container to original state
- **Status Monitoring**: Verifies successful restart

### Error Handling
- **Comprehensive Logging**: All operations logged with timestamps
- **Rollback on Failure**: Automatic cleanup on errors
- **Exit Code Management**: Proper error propagation
- **User Confirmation**: Interactive prompts for destructive operations

## 📈 Monitoring

### Real-time Progress
```
Progress format: [Data rate] [Progress] [Time elapsed] [ETA]
22.1GiB 0:01:34 [ 239MiB/s] [================================>] 100%
```

### Log Analysis
```bash
# View recent backup activity
tail -f ~/.local/log/gntech-jellyfin-backup.log

# Check backup success rate
grep "SUCCESS" ~/.local/log/gntech-jellyfin-backup.log | tail -10

# Monitor errors
grep "ERROR" ~/.local/log/gntech-jellyfin-backup.log
```

## 🚀 Remote Deployment

### Deploy to Server
```bash
# Copy script to remote server
scp jellyfin-backup.sh user@server:~/

# SSH and run
ssh user@server "./jellyfin-backup.sh -c container_name"

# Automated deployment
./deploy.sh user@server
```

### Server Requirements
- SSH access with sudo privileges
- Docker installed and running
- Sufficient disk space (2x container size)
- Internet access for prerequisite installation

## 🔍 Troubleshooting

### Common Issues

**Progress bar not showing**
```bash
# Install pv manually if auto-install fails
sudo apt-get install pv
```

**Container won't stop**
```bash
# Check container status
docker ps -a | grep container_name

# Force stop if needed
docker kill container_name
```

**Backup file corrupted**
```bash
# Test backup integrity
tar -tzf backup_file.tar.gz > /dev/null && echo "OK" || echo "Corrupted"
```

**Insufficient disk space**
```bash
# Check available space
df -h ~/jellyfin-backups

# Clean old backups
find ~/jellyfin-backups -name "*.tar.gz" -mtime +7 -delete
```

## 📝 Changelog

### Version 2.0 (2025-08-19) - Production Release
- ✅ **NEW**: Real-time progress tracking with pv
- ✅ **NEW**: Pre-backup database verification
- ✅ **NEW**: Automatic prerequisite installation
- ✅ **NEW**: Direct compression (no intermediate files)
- ✅ **IMPROVED**: Container safety with enhanced stop/start logic
- ✅ **IMPROVED**: Error handling and rollback mechanisms
- ✅ **IMPROVED**: Performance optimization (239MiB/s)
- ✅ **FIXED**: ANSI escape sequence corruption in directory names

### Version 1.1 (2025-08-18) - Clean Version
- ✅ Removed visual interference causing backup failures
- ✅ Fixed directory creation issues
- ✅ Improved container discovery

### Version 1.0 (2025-08-17) - Initial Release
- ✅ Basic container backup functionality
- ✅ Interactive container selection
- ✅ GNTECH Solutions branding

## 📄 License

MIT License - see [LICENSE](LICENSE) file for details.

## 🤝 Support

- **Issues**: [GitHub Issues](https://github.com/gntech/jellyfin-backup/issues)
- **Documentation**: [Wiki](https://github.com/gntech/jellyfin-backup/wiki)
- **Email**: support@gntech.solutions

---

**GNTECH Solutions** - Professional IT Infrastructure Solutions
