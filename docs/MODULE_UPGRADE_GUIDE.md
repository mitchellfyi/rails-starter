# Module Upgrade Guide

This guide explains how to use the robust self-update mechanism for Rails SaaS Starter Template modules.

## Overview

The `bin/railsplan upgrade` command provides a comprehensive system for updating template modules to their latest versions while preserving your local customizations and handling database migrations, configuration changes, and seed data.

## Version Management

### Version Detection

Each module includes a `VERSION` file that follows semantic versioning (e.g., `1.2.3`). The upgrade system compares your installed version with the available template version to determine if an upgrade is needed.

```bash
# Check what versions are installed vs available
bin/railsplan list
```

### Version Comparison

The system uses semantic versioning rules:
- `1.1.0` > `1.0.9` (minor version beats patch)
- `2.0.0` > `1.9.9` (major version beats all)
- `1.0.1` > `1.0.0` (patch version increments)

## Upgrade Commands

### Upgrade Single Module

```bash
# Basic upgrade with interactive conflict resolution
bin/railsplan upgrade ai

# Non-interactive upgrade (auto-accepts template versions)
bin/railsplan upgrade ai --yes

# Upgrade without creating backup
bin/railsplan upgrade ai --no-backup

# Verbose output showing all operations
bin/railsplan upgrade ai --verbose
```

### Upgrade All Modules

```bash
# Check and upgrade all modules (interactive)
bin/railsplan upgrade

# Upgrade all modules without prompts
bin/railsplan upgrade --yes

# Upgrade all without backups (faster)
bin/railsplan upgrade --yes --no-backup
```

## Backup System

### Automatic Backups

By default, the upgrade system creates comprehensive backups before making any changes:

```
backups/railsplan_modules/
├── ai_v1.0.0_20240126_143022/
│   ├── app_domains/          # Your module files
│   ├── spec_domains/         # Your test files
│   ├── test_domains/         # Alternative test location
│   └── registry.json         # Module registry entry
```

### Backup Location

Backups are stored in `backups/railsplan_modules/` with the naming pattern:
`{module_name}_v{version}_{timestamp}/`

### Disabling Backups

For CI environments or when you're confident in your changes:

```bash
bin/railsplan upgrade --no-backup
```

**⚠️ Warning:** Only disable backups if you have alternative version control or backup systems in place.

## Conflict Resolution

### Detection

The system detects conflicts when:
- Template files have been modified since installation
- Your local files differ from the new template versions
- Configuration files have diverged

### Resolution Options

When conflicts are detected, you'll see options:

```
⚠️  Found 2 file conflict(s) in ai:
  📄 app/services/ai_service.rb
  📄 config/ai_settings.yml

Conflict resolution options:
  [o] Overwrite all with template versions
  [k] Keep all current versions  
  [i] Review each conflict individually
  [a] Abort upgrade
```

#### Option Details

- **[o] Overwrite**: Replace all conflicted files with template versions
- **[k] Keep**: Preserve all your current file versions
- **[i] Interactive**: Review each file individually with side-by-side comparison
- **[a] Abort**: Cancel the upgrade process

### Interactive Review

When choosing interactive mode, you'll see:

```
============================================================
Conflict in: app/services/ai_service.rb
============================================================

[1] Template version:
class AiService
  def enhanced_method
    # New template implementation
  end
end

[2] Current version:
class AiService  
  def enhanced_method
    # Your custom implementation
  end
end

Choose: [1] Use template, [2] Keep current, [s] Skip this file:
```

## Migration Handling

### Automatic Migration Detection

The upgrade system automatically handles database migrations:

1. **Detection**: Scans `{module}/db/migrate/` for new migration files
2. **Copying**: Copies new migrations to your `db/migrate/` directory
3. **Notification**: Informs you about new migrations to run

### Running Migrations

After upgrade, run any new migrations:

```bash
bin/rails db:migrate
```

### Migration Conflicts

If migration timestamps conflict, manually rename them:

```bash
# Rename migration file to current timestamp
mv db/migrate/20240101000000_add_feature.rb db/migrate/$(date +%Y%m%d%H%M%S)_add_feature.rb
```

## Configuration Updates

### Initializers

New or updated initializer files are automatically copied to `config/initializers/`.

### Routes

Route file updates require manual integration. The system will notify you:

```
📝 Found routes file - manual integration may be required
```

Review `{module}/config/routes.rb` and integrate changes into your `config/routes.rb`.

### Environment Variables

Check `.env.example` for new required environment variables after upgrades.

## Seed Data Handling

### Automatic Seed Processing

Module seed data is handled automatically:

1. **Detection**: Finds `{module}/db/seeds.rb` files
2. **Copying**: Copies to `db/seeds/{module}_seeds.rb`
3. **Notification**: Suggests running seeds

### Running Seeds

Execute module seeds after upgrade:

```bash
# Run all seeds (includes module seeds)
bin/rails db:seed

# Or manually load specific module seeds
bin/rails runner "load 'db/seeds/ai_seeds.rb'"
```

## CI/CD Integration

### Non-Interactive Mode

For automated environments, use the `--yes` flag to skip all prompts:

```bash
bin/railsplan upgrade --yes --no-backup
```

### CI Pipeline Example

```yaml
# .github/workflows/upgrade.yml
name: Update Template Modules
on:
  schedule:
    - cron: '0 2 * * 1'  # Weekly on Monday 2AM
  workflow_dispatch:

jobs:
  upgrade:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Setup Ruby
        uses: ruby/setup-ruby@v1
        with:
          bundler-cache: true
      - name: Upgrade modules
        run: |
          bin/railsplan upgrade --yes --verbose
          bin/rails db:migrate
      - name: Run tests
        run: |
          bin/rails test
      - name: Create PR if changes
        if: success()
        run: |
          # Create PR with changes
```

### Docker Integration

```dockerfile
# In your Dockerfile
RUN bin/railsplan upgrade --yes --no-backup
RUN bin/rails db:migrate
```

## Best Practices

### Before Upgrading

1. **Commit changes**: Ensure your working directory is clean
2. **Review release notes**: Check module changelogs for breaking changes
3. **Test in staging**: Run upgrades in non-production environments first

### During Upgrades

1. **Read conflict descriptions**: Understand what's changing before choosing resolution
2. **Keep custom logic**: When in doubt, choose to keep your implementations
3. **Note migration requirements**: Plan for database migration downtime

### After Upgrades

1. **Run tests**: Execute your full test suite
2. **Check functionality**: Verify critical features work as expected
3. **Update documentation**: Document any changes made to configurations

## Troubleshooting

### Common Issues

#### "Module not found" Error
```bash
❌ Module 'ai' template not found
```
**Solution**: Ensure you're in the correct project directory and the template repository is up to date.

#### Registry Corruption
```bash
❌ Module registry is corrupted (invalid JSON)
```
**Solution**: Reset registry or restore from backup:
```bash
# Reset registry
echo '{"installed":{}}' > scaffold/config/railsplan_modules.json

# Or restore from backup
cp backups/railsplan_modules/*/registry.json scaffold/config/railsplan_modules.json
```

#### Migration Conflicts
```bash
# Multiple migrations with same timestamp
```
**Solution**: Rename conflicting migrations with new timestamps.

### Recovery from Failed Upgrades

#### Restore from Backup
```bash
# List available backups
ls backups/railsplan_modules/

# Restore specific module
cp -r backups/railsplan_modules/ai_v1.0.0_20240126_143022/app_domains/* app/domains/ai/

# Restore registry entry
# (manually edit scaffold/config/railsplan_modules.json)
```

#### Force Clean Reinstall
```bash
bin/railsplan remove ai --force
bin/railsplan add ai
```

## Module Development

### Version Bump Guidelines

When updating template modules:

1. **Patch** (`1.0.1`): Bug fixes, documentation updates
2. **Minor** (`1.1.0`): New features, backward-compatible changes
3. **Major** (`2.0.0`): Breaking changes, API modifications

### Adding Upgrade Support to Custom Modules

Ensure your custom modules include:

```
my_module/
├── VERSION              # Semantic version
├── README.md           # Module description
├── install.rb          # Installation script
├── remove.rb           # Removal script (optional)
├── db/
│   ├── migrate/        # Database migrations
│   └── seeds.rb        # Seed data (optional)
├── config/
│   ├── initializers/   # Configuration files
│   └── routes.rb       # Route definitions (optional)
└── app/               # Module implementation
```

### Testing Upgrades

Test upgrade scenarios for your modules:

```ruby
# In your module tests
def test_upgrade_from_previous_version
  # Install old version
  install_module('my_module', '1.0.0')
  
  # Simulate changes
  modify_module_files
  
  # Upgrade to new version
  upgrade_module('my_module', '1.1.0')
  
  # Verify upgrade succeeded
  assert_module_upgraded
end
```

## Security Considerations

### Backup Security

- Backups may contain sensitive configuration data
- Exclude backups from version control (add to `.gitignore`)
- Consider encrypting backups in production environments

### Update Verification

- Always review changes in staging environments
- Verify checksums of template files if security is critical
- Use signed commits for template repositories

## Support

### Getting Help

1. **Check logs**: Review `log/railsplan.log` for detailed operation logs
2. **Run diagnostics**: Use `bin/railsplan doctor` to validate your setup
3. **Community support**: Create issues on the template repository

### Reporting Issues

When reporting upgrade issues, include:

- Module name and versions (current and target)
- Full error output with `--verbose` flag
- Your operating system and Ruby version
- Relevant log entries from `log/railsplan.log`