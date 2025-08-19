# Contributing to GNTECH Jellyfin Guardian

🛡️ Thank you for your interest in contributing to Jellyfin Guardian! This document provides guidelines and information for contributors.

## 🤝 How to Contribute

### Reporting Issues
- Use the [GitHub Issues](https://github.com/gntech/jellyfin-guardian/issues) page
- Search existing issues before creating a new one
- Provide detailed information including:
  - Operating system and version
  - Docker version
  - Container setup details
  - Error messages and logs
  - Steps to reproduce

### Suggesting Features
- Open an issue with the "enhancement" label
- Describe the use case and benefit
- Consider backward compatibility
- Provide examples if possible

### Contributing Code

#### Getting Started
1. Fork the repository
2. Clone your fork: `git clone https://github.com/yourusername/jellyfin-guardian.git`
3. Create a feature branch: `git checkout -b feature/amazing-feature`
4. Make your changes
5. Test thoroughly
6. Commit with clear messages
7. Push to your fork
8. Open a Pull Request

#### Development Setup
```bash
# Clone the repository
git clone https://github.com/gntech/jellyfin-guardian.git
cd jellyfin-guardian

# Make scripts executable
chmod +x *.sh

# Test basic functionality
./jellyfin-backup.sh --help
./jellyfin-backup.sh --version
```

## 🧪 Testing

### Basic Testing
```bash
# Syntax check
bash -n jellyfin-backup.sh

# Help and version tests
./jellyfin-backup.sh --help
./jellyfin-backup.sh --version

# Dry run test (safe, no actual backup)
./jellyfin-backup.sh --dry-run --all
```

### Container Testing
If you have test containers:
```bash
# Test with specific container
./jellyfin-backup.sh --dry-run -c your-test-container

# Test listing
./jellyfin-backup.sh --list
```

### Remote Testing
Test deployment functionality:
```bash
# Test deployment script syntax
bash -n deploy.sh

# Test with dry run (modify deploy.sh temporarily)
```

## 📝 Code Style

### Shell Script Guidelines
- Use `#!/bin/bash` shebang
- Enable strict mode: `set -euo pipefail`
- Use proper quoting: `"$variable"`
- Check exit codes: `if command; then`
- Use meaningful variable names
- Add comments for complex logic
- Follow existing indentation (4 spaces)

### Function Conventions
```bash
# Function naming: lowercase with underscores
backup_container_data() {
    local container_name=$1
    local backup_path=$2
    
    # Function body
    return 0
}
```

### Error Handling
```bash
# Always check critical operations
if ! docker stop "$container_name"; then
    log_message "ERROR" "Failed to stop container: $container_name"
    return 1
fi
```

### Logging Standards
```bash
# Use consistent logging levels
log_message "INFO" "Starting backup process"
log_message "SUCCESS" "Backup completed successfully"
log_message "WARNING" "Container is running but auto-stop disabled"
log_message "ERROR" "Critical failure occurred"
```

## 🏗️ Architecture

### Core Components
- **jellyfin-backup.sh**: Main backup script
- **deploy.sh**: Remote deployment automation
- **install.sh**: Local installation script
- **jellyfin-backup.conf**: Configuration template

### Key Functions
- `backup_container_data()`: Main backup orchestration
- `create_compressed_backup()`: Compression pipeline
- `verify_jellyfin_databases()`: Database integrity checks
- `log_message()`: Centralized logging

### Configuration Management
- Environment variables override defaults
- Configuration file support
- Command-line argument parsing
- Validation and sanitization

## 🚀 Release Process

### Version Numbering
We follow [Semantic Versioning](https://semver.org/):
- `MAJOR.MINOR.PATCH` (e.g., 2.1.0)
- Major: Breaking changes
- Minor: New features, backward compatible
- Patch: Bug fixes, backward compatible

### Creating Releases
1. Update version in script header
2. Update CHANGELOG.md
3. Test thoroughly
4. Create git tag: `git tag -a v2.1.0 -m "Release message"`
5. Push tag: `git push origin v2.1.0`
6. GitHub Actions will create the release

### Changelog Format
```markdown
## [2.1.0] - 2025-08-19 - Log Enhancement Release

### 🆕 New Features
- Feature description

### 🔧 Improvements
- Improvement description

### 🐛 Bug Fixes
- Bug fix description
```

## 🛡️ Security

### Security Considerations
- Never commit credentials or keys
- Validate all user inputs
- Use secure file permissions
- Handle sensitive data carefully
- Test with untrusted inputs

### Reporting Security Issues
- Email security issues privately (not public issues)
- Provide detailed information
- Allow time for fixes before disclosure

## 📚 Documentation

### Required Documentation
- Update README.md for new features
- Add inline comments for complex code
- Update help text (`show_help()` function)
- Update configuration examples

### Documentation Style
- Clear, concise explanations
- Include practical examples
- Use consistent formatting
- Test all examples

## ✅ Pull Request Guidelines

### Before Submitting
- [ ] Code follows style guidelines
- [ ] All tests pass
- [ ] Documentation updated
- [ ] Changelog updated (for features)
- [ ] Commit messages are clear

### PR Description Template
```markdown
## Description
Brief description of changes

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation update

## Testing
- [ ] Tested locally
- [ ] Added tests for new features
- [ ] All existing tests pass

## Checklist
- [ ] Code follows project style
- [ ] Self-review completed
- [ ] Documentation updated
- [ ] Changelog updated
```

## 🎯 Areas for Contribution

### High Priority
- Database backup verification improvements
- Performance optimizations
- Error handling enhancements
- Additional container platform support

### Medium Priority
- Backup retention policies
- Notification systems
- Configuration management improvements
- Additional compression algorithms

### Low Priority
- UI improvements
- Additional logging formats
- Integration with monitoring systems
- Backup encryption

## 💬 Community

### Getting Help
- GitHub Discussions for questions
- GitHub Issues for bugs
- Check existing documentation first

### Code of Conduct
- Be respectful and inclusive
- Focus on constructive feedback
- Help others learn and contribute
- Follow GitHub's community guidelines

## 🙏 Recognition

Contributors will be recognized in:
- GitHub contributors list
- Release notes for significant contributions
- Special mentions for major features

Thank you for contributing to GNTECH Jellyfin Guardian! 🛡️
