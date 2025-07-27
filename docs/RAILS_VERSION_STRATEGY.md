# Rails Version Strategy

This Rails SaaS Starter Template uses a **dual-version strategy** to provide both cutting-edge features and stability options.

## 🚀 Rails Edge (Default)

**Default choice**: Rails edge from the `main` branch

### Why Rails Edge?
- **Latest Features**: Access to the newest Rails features and improvements
- **Performance**: Latest optimizations and performance enhancements
- **Security**: Most recent security patches and updates
- **Future-Proof**: Stay ahead of the curve with upcoming Rails 8 features

### Configuration
```ruby
# In Gemfile
gem 'rails', github: 'rails/rails', branch: 'main'
```

## 🛡️ Rails 8 Stable (Fallback)

**Alternative choice**: Rails 8.0.x stable release

### When to Use Rails 8 Stable?
- **Production Stability**: When you need maximum stability for production
- **Team Familiarity**: If your team prefers well-documented, stable releases
- **Third-party Compatibility**: When you encounter gem compatibility issues
- **Enterprise Requirements**: When your organization requires stable releases

### Configuration
```ruby
# In Gemfile
# gem 'rails', github: 'rails/rails', branch: 'main'
gem 'rails', '~> 8.0.0'
```

## 🔄 Switching Between Versions

### From Edge to Stable
1. Edit your `Gemfile`
2. Comment out the edge line: `# gem 'rails', github: 'rails/rails', branch: 'main'`
3. Uncomment the stable line: `gem 'rails', '~> 8.0.0'`
4. Run: `bundle update rails`

### From Stable to Edge
1. Edit your `Gemfile`
2. Comment out the stable line: `# gem 'rails', '~> 8.0.0'`
3. Uncomment the edge line: `gem 'rails', github: 'rails/rails', branch: 'main'`
4. Run: `bundle update rails`

## 📋 Version Requirements

### Ruby Version
- **Minimum**: Ruby >= 3.3.0
- **Supported**: Ruby 3.3.x, 3.4.x, and future versions
- **Recommended**: Latest stable Ruby version (3.4.x or newer)

### Rails Versions
- **Edge**: Rails main branch (latest commit)
- **Stable**: Rails 8.0.x series

## 🧪 Testing Strategy

### Rails Edge Testing
- **Continuous Integration**: Tests run against Rails edge
- **Regression Testing**: Automated tests catch breaking changes
- **Module Compatibility**: All modules tested against edge

### Rails 8 Stable Testing
- **Release Testing**: Tests against each Rails 8.x release
- **Compatibility Matrix**: Track module compatibility with stable releases

## 🚨 Breaking Changes

### Rails Edge Considerations
- **API Changes**: Edge may introduce breaking changes
- **Gem Compatibility**: Some gems may not work with edge
- **Documentation**: Features may be undocumented or in flux

### Mitigation Strategies
- **Feature Flags**: Use feature flags for new Rails features
- **Version Checks**: Check Rails version before using new features
- **Fallback Code**: Provide fallbacks for edge-only features

## 📊 Version Comparison

| Feature | Rails Edge | Rails 8 Stable |
|---------|------------|----------------|
| Latest Features | ✅ | ❌ |
| Stability | ⚠️ | ✅ |
| Performance | ✅ | ✅ |
| Security | ✅ | ✅ |
| Documentation | ⚠️ | ✅ |
| Gem Compatibility | ⚠️ | ✅ |

## 🎯 Recommendations

### Use Rails Edge When:
- Building new applications
- Wanting latest features
- Comfortable with potential instability
- Have time to handle breaking changes

### Use Rails 8 Stable When:
- Building production applications
- Need maximum stability
- Working with enterprise constraints
- Prefer well-documented features

## 🔧 Template Configuration

The template automatically configures Rails edge by default, but provides an interactive choice during setup:

```bash
rails new myapp --dev -m https://github.com/your-username/rails-starter/raw/main/scaffold/template.rb
```

You'll be prompted to choose between:
1. **Edge** (default) - Latest features
2. **Stable** - Production stability

## 📚 Additional Resources

- [Rails Edge Documentation](https://edgeguides.rubyonrails.org/)
- [Rails 8 Release Notes](https://rubyonrails.org/2024/8/0)
- [Rails Upgrade Guide](https://guides.rubyonrails.org/upgrading_ruby_on_rails.html)
- [Rails Security Advisories](https://groups.google.com/forum/#!forum/rubyonrails-security) 