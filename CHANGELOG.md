# Changelog

All notable changes to the Rails SaaS Starter Template will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Comprehensive documentation system with enhanced README, module guides, and CLI help
- Enhanced CLI help system with detailed descriptions and examples for all commands
- Module documentation standards and templates
- Testing strategy documentation
- Contributing guidelines for new modules

### Changed
- Improved CLI help output with long descriptions and usage examples
- Enhanced module documentation structure

### Deprecated
- None

### Removed
- None

### Fixed
- CLI path issues in bin/synth

### Security
- None

## [0.1.0] - Initial Release

### Added
- Base Rails SaaS Starter Template with modular architecture
- Core stack: Rails Edge, PostgreSQL with pgvector, Redis, Sidekiq
- Authentication system with Devise and OmniAuth support
- Workspace/team management with role-based permissions
- AI module with prompt templates and LLM job system
- Multi-Context Provider (MCP) for dynamic prompt enrichment
- CLI tool (`bin/synth`) for managing feature modules
- Basic module system with installation/removal capabilities
- Template script for `rails new` integration
- Core gems and dependencies setup
- Basic testing framework integration (RSpec/Minitest)

### Infrastructure
- Hotwire (Turbo & Stimulus) for modern frontend interactions
- TailwindCSS for styling
- Sidekiq for background job processing
- JSON:API compliant endpoints
- OpenAPI schema generation support

---

## Release Notes

### Version Numbering
This template follows semantic versioning:
- **Major** (X.0.0): Breaking changes that require manual migration
- **Minor** (0.X.0): New features and modules, backward compatible
- **Patch** (0.0.X): Bug fixes and documentation improvements

### Module Versioning
Individual modules may have their own version numbers. Use `bin/synth list` to see installed module versions.

### Migration Guide
When upgrading between major versions, check the migration guide in `docs/` for breaking changes and upgrade instructions.

### Contributing
See [AGENTS.md](AGENTS.md) for detailed contribution guidelines. When making changes:
1. Update this changelog in the [Unreleased] section
2. Follow conventional commit format
3. Document breaking changes clearly
4. Update relevant documentation