# 🛡️ GNTECH Jellyfin Guardian

**Enterprise-grade backup solution for Jellyfin media servers with intelligent remote storage and automated retention policies.**

[![Version](https://img.shields.io/badge/version-2.2-blue.svg)](CHANGELOG.md)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Docker](https://img.shields.io/badge/docker-compatible-blue.svg)](https://docker.com)

## ✨ Features

### 🔄 **Comprehensive Backup Management**
- **Automated container discovery** - Finds Jellyfin containers automatically
- **Safe container handling** - Optional container stop/start for data integrity
- **Database verification** - SQLite integrity checks before backup
- **Intelligent compression** - Parallel compression with pigz/gzip fallback
- **Detailed logging** - Session logs + backup-specific log files

### ☁️ **Advanced Remote Storage**
- **Multi-provider support** - SFTP, S3-compatible, NFS, FTP, rclone
- **Intelligent retention** - Local: 1 backup, Remote: 3 backups
- **Automatic cleanup** - Space management with configurable policies
- **Upload verification** - Ensure backup integrity after transfer
- **Connection testing** - Validate remote storage before backup

### 🤖 **Flexible Automation**
- **User-level automation** - Crontab or systemd user services (no root required)
- **System-wide automation** - Enterprise systemd services with timers
- **Interactive configuration** - Guided setup for all storage providers
- **Command-line interface** - Full CLI support for scripting

### 🔐 **Security & Permissions**
- **Docker group support** - Works without root privileges
- **Permission validation** - Comprehensive pre-flight checks
- **SSH key authentication** - Secure remote deployment
- **Configurable exclusions** - Skip temp files, logs, cache directories

## 🚀 Quick Start

### 📥 Installation

```bash
# Clone the repository
git clone https://github.com/yourusername/jellyfin-guardian.git
cd jellyfin-guardian

# Install for current user (recommended)
./install.sh

# Or install system-wide (requires sudo)
sudo ./install.sh
```

### ⚙️ Basic Usage

```bash
# Interactive mode
jellyfin-guardian

# Backup all containers
jellyfin-guardian --all

# Backup specific container
jellyfin-guardian --container jellyfin_main

# List available containers
jellyfin-guardian --list

# Clean old backups
jellyfin-guardian --cleanup
```

### ☁️ Remote Storage Setup

```bash
# Interactive remote storage configuration
jellyfin-guardian --configure-remote

# Test remote storage connection
jellyfin-guardian --test-remote

# Backup with remote storage disabled
jellyfin-guardian --no-remote --all
```

## 📁 Project Structure

```
jellyfin-guardian/
├── jellyfin-backup.sh           # Main backup script
├── install.sh                   # Installation script
├── README.md                    # This file
├── CHANGELOG.md                 # Version history
├── LICENSE                      # MIT License
├── config/                      # Configuration templates
│   ├── jellyfin-backup.conf            # Main configuration
│   └── jellyfin-backup-remote.conf     # Remote storage config
├── scripts/                     # Utility scripts
│   ├── configure-remote.sh             # Remote storage setup
│   ├── deploy.sh                       # Remote deployment
│   └── test-deployment.sh              # Deployment testing
├── examples/                    # Example configurations
│   ├── servers.example.txt             # Server list template
│   └── jellyfin-backup-remote.example.conf  # Full config example
├── docs/                        # Documentation
│   ├── PROJECT-SUMMARY.md              # Technical overview
│   └── CONTRIBUTING.md                 # Contribution guidelines
└── archive/                     # Historical versions
    ├── deprecated/                     # Deprecated scripts
    ├── old-versions/                   # Previous versions
    └── test-scripts/                   # Development tests
```

## 🎯 Use Cases

### 🏠 **Home Users**
```bash
# Simple daily backup with user automation
./install.sh  # Choose: y -> 1 (crontab)
jellyfin-guardian --configure-remote  # Setup cloud storage
# Automated daily backups at 2 AM
```

### 🏢 **Enterprise Deployments**
```bash
# System-wide installation with remote deployment
sudo ./install.sh
# Deploy to multiple servers
scripts/deploy.sh --servers production-servers.txt
# Monitor via systemd
sudo systemctl status jellyfin-guardian.timer
```

### 🔧 **Development & Testing**
```bash
# Test deployment without production impact
scripts/test-deployment.sh --check-permissions
scripts/test-deployment.sh --deploy --test
# Dry run before actual backup
jellyfin-guardian --dry-run --all
```

## 🛠️ Configuration

### 📋 **Remote Storage Providers**

| Provider | Authentication | Features |
|----------|---------------|----------|
| **SFTP** | SSH Keys | ✅ Reliable, secure, widely supported |
| **S3-Compatible** | Access/Secret Keys | ✅ AWS S3, MinIO, DigitalOcean Spaces |
| **NFS** | Network Mount | ✅ High performance, local network |
| **FTP** | Username/Password | ✅ Legacy support, simple setup |
| **Rclone** | Provider Config | ✅ 70+ cloud providers supported |

### ⚙️ **Configuration Files**

- **`config/jellyfin-backup.conf`** - Main backup settings
- **`config/jellyfin-backup-remote.conf`** - Remote storage configuration
- **`examples/`** - Example configurations for all providers

### 🕒 **Automation Options**

#### **User-Level (No Root Required)**
```bash
# Crontab (recommended)
crontab -l  # View current jobs
crontab -e  # Edit schedule

# Systemd user service
systemctl --user enable jellyfin-guardian.timer
systemctl --user start jellyfin-guardian.timer
```

#### **System-Level (Root Required)**
```bash
sudo systemctl enable jellyfin-guardian.timer
sudo systemctl start jellyfin-guardian.timer
```

## 📊 Command Reference

### 🎮 **Interactive Options**
- **Container Discovery** - Find and list Jellyfin containers
- **Selective Backup** - Choose specific containers
- **Mount Inspection** - View container volume mounts
- **Settings Configuration** - Modify backup behavior
- **Remote Storage Setup** - Configure cloud/network storage
- **Backup History** - View previous backup information
- **Cleanup Management** - Remove old backups safely

### 💻 **Command Line Interface**

```bash
jellyfin-guardian [OPTIONS]

Options:
  -c, --container NAME      Backup specific container
  -a, --all                 Backup all Jellyfin containers
  -l, --list                List discovered containers only
  -n, --no-stop             Don't stop containers during backup
  -d, --backup-dir DIR      Override backup directory
  --no-compress             Skip compression of backup
  --no-verify               Skip database integrity verification
  --configure-remote        Run interactive remote storage setup
  --test-remote             Test remote storage connection
  --no-remote               Disable remote storage for this run
  --local-only              Keep local backups (don't delete after upload)
  --cleanup                 Clean up all existing backups
  --dry-run                 Show what would be backed up without doing it
  -v, --version             Show version information
  -h, --help                Show help message
```

## 🔧 Advanced Usage

### 🌐 **Remote Deployment**
```bash
# Deploy to single server
scripts/test-deployment.sh --full

# Deploy to multiple servers
scripts/deploy.sh --servers examples/servers.example.txt

# Test permissions only
scripts/test-deployment.sh --check-permissions
```

### 📈 **Monitoring & Logs**
```bash
# View session logs
tail -f ~/.local/log/gntech-jellyfin-backup.log

# Check systemd logs
journalctl --user -u jellyfin-guardian.service

# Backup-specific logs (created alongside .tar.gz files)
ls -la ~/backups/jellyfin/*.log
```

### 🔄 **Backup Verification**
```bash
# Test backup without execution
jellyfin-guardian --dry-run --all

# Verify database integrity
jellyfin-guardian --container jellyfin_main --no-compress

# Test remote storage
jellyfin-guardian --test-remote
```

## 🤝 Contributing

We welcome contributions! Please see [docs/CONTRIBUTING.md](docs/CONTRIBUTING.md) for guidelines.

### 🏗️ **Development Setup**
```bash
git clone https://github.com/yourusername/jellyfin-guardian.git
cd jellyfin-guardian
# Make changes and test
./jellyfin-backup.sh --dry-run --list
```

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🎯 Support

- **📖 Documentation**: [docs/](docs/)
- **🐛 Issues**: [GitHub Issues](https://github.com/yourusername/jellyfin-guardian/issues)
- **💬 Discussions**: [GitHub Discussions](https://github.com/yourusername/jellyfin-guardian/discussions)
- **📧 Email**: support@gntech.solutions

---

**Made with ❤️ by GNTECH Solutions** | [🌐 Website](https://gntech.solutions) | [📚 Documentation](docs/)
