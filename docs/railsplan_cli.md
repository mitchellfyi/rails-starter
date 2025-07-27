# bin/railsplan - Module Management CLI

The `bin/railsplan` command-line tool provides true modular support for the Rails SaaS Starter Template. It allows you to install, remove, upgrade, and manage feature modules via a centralized registry.

## Features

- **Module Registry**: Track installed modules with version and installation metadata
- **Install/Remove**: Add and remove modules with proper cleanup
- **Auto-patching**: Automatically patch configurations, routes, migrations, and seeds
- **Upgrade Support**: Upgrade individual modules or all installed modules
- **Testing Integration**: Run tests for specific modules or the entire suite
- **Health Checks**: Validate setup and module integrity

## Commands

### list
List available and installed modules with version information.

```bash
bin/railsplan list
```

Shows:
- Available modules from `scaffold/lib/templates/railsplan/`
- Installed modules from the registry
- Version numbers and installation dates

### add MODULE
Install a feature module to your application.

```bash
bin/railsplan add billing
bin/railsplan add ai --force    # Force reinstall
```

Features:
- Copies module files to `app/domains/MODULE_NAME`
- Updates the module registry
- Logs installation actions
- Prevents duplicate installations (unless `--force` is used)

### remove MODULE
Uninstall a feature module from your application.

```bash
bin/railsplan remove cms
bin/railsplan remove billing --force    # Skip confirmation
```

Features:
- Removes files from `app/domains/`, `spec/domains/`, and `test/domains/`
- Updates the module registry
- Prompts for confirmation (unless `--force` is used)
- Logs removal actions

### info MODULE
Show detailed information about a module.

```bash
bin/railsplan info billing
```

Shows:
- Module description from README.md
- Version information
- Installation status
- List of files in the module template

### test [MODULE]
Run tests for a specific module or all modules.

```bash
bin/railsplan test billing      # Test specific module
bin/railsplan test              # Test all modules
```

Features:
- Automatically detects RSpec or Minitest
- Looks for module-specific test directories
- Supports both `spec/` and `test/` directory structures

### plan MODULE [OPERATION]
Preview what changes would be made during module installation or upgrade.

```bash
bin/railsplan plan billing              # Preview billing module installation
bin/railsplan plan ai upgrade          # Preview AI module upgrade
```

Features:
- Shows files that would be created, updated, or overwritten
- Lists database migrations that would be applied
- Shows configuration changes (initializers, gems, generators)
- Displays route changes that need manual integration
- Lists dependencies that would be added
- Provides file diff summaries for upgrades
- Non-destructive preview operation

The output includes:
- **File Operations**: New files to create and existing files to update
- **Database Changes**: Migrations with analysis of tables/indexes being created
- **Configuration**: Initializers, gems, and generators that would be run
- **Routes**: Route definitions that need manual integration
- **Dependencies**: Ruby gems and JavaScript packages to be installed

### upgrade [MODULE]
Upgrade one or all installed modules.

```bash
bin/railsplan upgrade billing   # Upgrade specific module
bin/railsplan upgrade           # Upgrade all modules
```

Features:
- Reinstalls modules with latest templates
- Preserves existing data where possible
- Updates registry with new versions

### doctor
Validate setup, configuration, and dependencies.

```bash
bin/railsplan doctor
```

Checks:
- Ruby version
- Module registry integrity
- Template directory structure
- JSON validity of registry file

## Options

### Global Options
- `--verbose, -v`: Enable verbose output showing detailed operations
- `--force, -f`: Force operations without confirmation prompts

## Module Registry

The module registry is stored in `scaffold/config/railsplan_modules.json` and tracks:

```json
{
  "installed": {
    "billing": {
      "version": "1.0.0",
      "installed_at": "2025-07-26T18:15:17+0000",
      "template_path": "/path/to/scaffold/lib/templates/railsplan/billing"
    }
  }
}
```

## Module Structure

Modules are stored in `scaffold/lib/templates/railsplan/MODULE_NAME/` with:

- `README.md`: Module description and documentation
- `VERSION`: Version number (defaults to "1.0.0" if missing)
- `install.rb`: Installation script (required)
- `remove.rb`: Custom removal script (optional)
- Other files: Copied to `app/domains/MODULE_NAME/`

## Directory Structure

After installing modules, your application will have:

```
app/
  domains/
    billing/
      README.md
      assets/
      views/
      test/
    ai/
      README.md
      # ... other module files
spec/
  domains/
    billing/
    ai/
test/
  domains/
    billing/
    ai/
```

## Logging

All module operations are logged to `log/railsplan.log` with timestamps and action details:

```
[2025-07-26 18:15:17] [INSTALL] Module: billing - 1.0.0
[2025-07-26 18:16:30] [REMOVE] Module: cms
[2025-07-26 18:17:45] [ERROR] Module: invalid_module - Module not found
```

## Examples

```bash
# List all modules
bin/railsplan list

# Preview billing module installation
bin/railsplan plan billing

# Preview AI module upgrade
bin/railsplan plan ai upgrade

# Install billing module
bin/railsplan add billing

# Get information about AI module
bin/railsplan info ai

# Remove CMS module without confirmation
bin/railsplan remove cms --force

# Test only the billing module
bin/railsplan test billing

# Upgrade all installed modules
bin/railsplan upgrade

# Check system health
bin/railsplan doctor

# Show help
bin/railsplan help
```

## Error Handling

The CLI provides clear error messages and appropriate exit codes:

- **Exit 0**: Success
- **Exit 1**: Error (missing module, invalid operation, etc.)

Common error scenarios:
- Module not found in templates
- Module already installed (without `--force`)
- Module not installed (for remove/upgrade operations)
- Invalid JSON in registry file
- Missing required directories or files

## Testing

The CLI includes comprehensive tests in `test/railsplan_integration_test.rb` that validate:

- All command functionality
- Error handling
- Module lifecycle (install/remove/upgrade)
- Registry management
- Help and documentation