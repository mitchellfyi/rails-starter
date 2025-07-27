# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2024-01-15

### Added
- Initial release of RailsPlan
- CLI interface using Thor
- Ruby version management and detection
- Rails installation and version management
- Modular template system
- Application generation with optimal defaults
- Module installation and management
- Comprehensive logging system
- Configuration management
- Interactive prompts and progress indicators
- Support for AI, Billing, Admin, and CMS modules
- Development environment setup
- Git repository initialization
- Database setup and seeding

### Features
- `railsplan new` - Generate new Rails SaaS applications
- `railsplan add` - Add modules to existing applications
- `railsplan list` - List available and installed modules
- `railsplan doctor` - Run diagnostics and validation
- `railsplan rails` - Pass through to Rails CLI
- `railsplan version` - Show version information

### Technical
- Built with Ruby 3.0+ compatibility
- Uses Thor for CLI framework
- TTY tools for interactive prompts
- Structured logging with file rotation
- JSON-based configuration management
- Modular template architecture 