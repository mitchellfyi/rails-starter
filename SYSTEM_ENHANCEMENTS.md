# RailsPlan System Enhancements

## Overview

This implementation provides comprehensive enhancements to the `railsplan` CLI and scaffold system, ensuring that every feature, module, or change added to a Rails app via `railsplan` adheres to system-level guarantees for **consistency**, **verifiability**, and **extensibility**.

## 🎯 Goals Achieved

### 1. Consistency ✅

All modules now include:

- **I18n keys** - Validated via `Validator#validate_i18n_keys`
- **Accessibility (a11y) tags** - Checked via `Validator#validate_accessibility_tags`
- **SEO metadata** - Validated via `Validator#validate_seo_metadata`
- **Schema and migration files** - Checked via `Validator#validate_migrations`
- **Tests (unit + system)** - Validated via `Validator#validate_tests`
- **Documentation** - Checked via `Validator#validate_documentation`
- **AI prompt logs** - Tracked in `.railsplan/prompts.log`
- **Audit logging** - Validated via `Validator#validate_audit_logging`
- **Context registration** - Tracked in `.railsplan/context.json` and `.railsplan/modules.json`

### 2. Verifiability ✅

The enhanced `railsplan doctor` command can:

- **Detect missing coverage** - Tests, SEO, I18n, accessibility, documentation
- **Detect stale context** - Validates `.railsplan/context.json` freshness
- **Confirm prompt logs consistency** - Checks `.railsplan/prompts.log`
- **Validate AI-generated diffs** - Ensures uncommitted changes are tracked
- **Ensure install/uninstall hooks** - Validates module install/remove scripts

### 3. Extensibility ✅

Each module is now:

- **Self-contained** - Located under `lib/railsplan/modules/<name>/`
- **Install/uninstall capable** - With `install.rb` and `remove.rb` scripts
- **CLI supported** - Via `railsplan add <module>` and `railsplan remove <module>`
- **Version tracked** - With `VERSION` file and changelog per module
- **Configurable** - With optional prompts for configuration
- **Modular** - Large files broken into logical components

### 4. Developer DX Enhancements ✅

Modules now offer:

- **Dry-run mode** - `--dry-run` flag for preview without changes
- **Silent mode** - `--ci` flag for automated environments
- **Replay capability** - `railsplan replay` command for AI interactions
- **Clear documentation** - Comprehensive help and module documentation

## 🛠 Implementation Details

### Core Components

#### 1. `RailsPlan::Validator`
Located: `lib/railsplan/validator.rb`

A comprehensive validation system that checks:
- Module structure and completeness
- I18n localization files
- Accessibility attributes in views
- SEO metadata presence
- Test coverage
- Documentation completeness
- Migration integrity
- Audit logging implementation
- Context registration

**Key Methods:**
- `validate_module(module_name, app_path)` - Validates a specific module
- `validate_all_modules(app_path)` - Validates all installed modules
- `validate_system_consistency(app_path)` - Validates overall system integrity

#### 2. `RailsPlan::ModulesRegistry`
Located: `lib/railsplan/modules_registry.rb`

A registry system for tracking installed modules with:
- Module metadata tracking
- Version management
- Validation status tracking
- Dependency management
- Auto-discovery of modules
- Legacy registry migration
- Integrity validation

**Key Methods:**
- `register_module(name, metadata)` - Register a new module
- `unregister_module(name)` - Remove a module
- `module_installed?(name)` - Check installation status
- `update_validation_status(name, status, details)` - Track validation results

#### 3. Enhanced `DoctorCommand`
Located: `lib/railsplan/commands/doctor_command.rb`

Enhanced diagnostics with:
- Module-by-module validation
- System consistency checks
- Detailed reporting (markdown/JSON)
- Auto-fix capabilities
- CI-specific validation

#### 4. `ReplayCommand`
Located: `lib/railsplan/commands/replay_command.rb`

AI interaction replay system with:
- Prompt log parsing
- Command filtering (by session/type)
- Interactive and batch replay modes
- Dry-run support
- Error handling and continuation

#### 5. Enhanced `ModuleManager`
Located: `lib/railsplan/module_manager.rb`

Improved module management with:
- Dry-run installation planning
- Validation integration
- Dependency checking
- Proper error handling
- Hook script execution

### CLI Enhancements

#### Enhanced Commands

1. **`railsplan doctor`**
   - Module validation integration
   - System consistency checks
   - Enhanced reporting options
   - Auto-fix capabilities

2. **`railsplan add <module>`**
   - Dry-run support (`--dry-run`)
   - Silent mode (`--ci`)
   - Post-install validation
   - Dependency checking

3. **`railsplan remove <module>`**
   - Dry-run support
   - Dependency validation
   - Clean removal with hooks

4. **`railsplan list`**
   - Detailed module information (`--detailed`)
   - Filter by status (`--installed`, `--available`)
   - Validation status display

5. **`railsplan replay`** *(NEW)*
   - Replay AI interactions from logs
   - Filter by session or command type
   - Interactive and batch modes
   - Dry-run support

6. **`railsplan plan <module>`** *(ENHANCED)*
   - Preview installation changes
   - Dependency analysis
   - File change prediction

7. **`railsplan info <module>`** *(ENHANCED)*
   - Detailed module information
   - Installation status
   - Validation results

### File Structure

```
lib/railsplan/
├── validator.rb              # Module validation system
├── modules_registry.rb       # Module tracking and metadata
├── commands/
│   ├── doctor_command.rb     # Enhanced diagnostics
│   └── replay_command.rb     # AI interaction replay
└── module_manager.rb         # Enhanced module management

.railsplan/
├── context.json              # Application context
├── modules.json              # Module registry
├── prompts.log              # AI interaction log
└── doctor_report.json       # Validation reports
```

## 📋 Module Requirements

For a module to be considered complete, it must include:

### Required Files
- `lib/railsplan/modules/<name>/install.rb` - Installation script
- `lib/railsplan/modules/<name>/remove.rb` - Removal script  
- `lib/railsplan/modules/<name>/README.md` - Module documentation
- `lib/railsplan/modules/<name>/VERSION` - Version identifier

### Required Features
- **I18n Support** - `config/locales/<module>.yml`
- **Tests** - Test files in `test/` or `spec/`
- **Accessibility** - Proper `aria-*` attributes and `alt` tags
- **SEO Metadata** - Meta tags and structured data where applicable
- **Audit Logging** - User action tracking for compliance
- **Documentation** - Clear README and usage instructions

### Optional Enhancements
- **Migrations** - Database schema changes
- **Views** - UI components with accessibility
- **Controllers** - RESTful endpoints
- **Models** - Data layer with validations
- **Assets** - Stylesheets and JavaScript
- **Background Jobs** - Async processing

## 🔧 Usage Examples

### Validate All Modules
```bash
railsplan doctor
```

### Add a Module with Dry Run
```bash
railsplan add ai --dry-run
railsplan add ai
```

### List Modules with Details
```bash
railsplan list --detailed
```

### Replay AI Interactions
```bash
railsplan replay --session=abc123
railsplan replay --command=generate --dry-run
```

### Plan Module Installation
```bash
railsplan plan billing install
```

### Remove Module Safely
```bash
railsplan remove cms --dry-run
railsplan remove cms
```

## 🧪 Testing

Run the comprehensive test suite:

```bash
# Basic functionality tests
ruby test_railsplan_system.rb

# Feature demonstration
ruby demo_system_enhancements.rb
```

## 📈 Benefits

1. **Consistency** - All modules follow the same patterns and requirements
2. **Quality Assurance** - Automated validation catches missing features
3. **Developer Experience** - Clear feedback and helpful error messages
4. **Maintainability** - Modular design with clear separation of concerns
5. **Extensibility** - Easy to add new validation rules and module types
6. **Reliability** - Comprehensive error handling and recovery
7. **Compliance** - Built-in audit logging and documentation requirements

## 🚀 Future Enhancements

- **Module Marketplace** - Discover and install community modules
- **Automated Testing** - Generate tests based on module structure
- **Performance Monitoring** - Track module impact on application performance
- **Security Scanning** - Automated security vulnerability detection
- **Integration Testing** - Cross-module compatibility validation
- **Documentation Generation** - Auto-generate API docs from modules