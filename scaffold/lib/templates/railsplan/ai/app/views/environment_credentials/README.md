# Environment Credentials Management

## Overview

The environment credentials management system allows workspaces to:

1. **Scan and import API keys** from environment variables and .env files
2. **Integrate with external secret managers** (Vault, Doppler, 1Password CLI)  
3. **Manage workspace-level environment variables** centrally
4. **Map environment variables to AiCredential fields** via UI
5. **Validate and test all credentials** with comprehensive error reporting

## Features

### Environment Variable Import Wizard

- Automatically scans `.env`, `.env.local`, `.env.development`, `.env.production` files
- Detects API keys for major AI providers (OpenAI, Anthropic, Cohere, etc.)
- Suggests credential mappings based on environment variable patterns
- Validates API key formats before import
- Provides import wizard UI for reviewing and customizing imports

### External Secret Manager Integration

#### HashiCorp Vault
- Connects to Vault using `VAULT_ADDR` and `VAULT_TOKEN`
- Syncs secrets from configurable path (`VAULT_SECRETS_PATH`)
- Bi-directional sync (read from and write to Vault)
- Namespace support via `VAULT_NAMESPACE`

#### Doppler
- Uses Doppler CLI for secret management
- Requires `DOPPLER_TOKEN` for authentication
- Syncs from specified project and config
- Automatic detection of AI-related secrets

#### 1Password CLI
- Supports both service account tokens and Connect API
- Searches specified vault for AI credential items
- Extracts API keys from items with AI-related tags
- Can create new items when storing credentials

### Validation and Testing

- **Comprehensive credential testing** with connection verification
- **API key format validation** for different providers
- **Model compatibility checking** 
- **Parameter range validation** (temperature, max_tokens)
- **External sync status monitoring**
- **Real-time test result reporting** with detailed error messages

### Workspace-Level Environment Vault

- Centralized management of environment variables per workspace
- Role-based access control (admin-only for credential management)
- Audit trail of imports and syncs with user attribution
- Support for multiple credentials per provider with clear naming

## Configuration

### Environment Variables

```bash
# Vault Integration
VAULT_ADDR=http://localhost:8200
VAULT_TOKEN=your_vault_token
VAULT_NAMESPACE=your_namespace  # Optional
VAULT_SECRETS_PATH=secret/data/ai-credentials  # Default path

# Doppler Integration  
DOPPLER_TOKEN=your_doppler_token
DOPPLER_PROJECT=ai-credentials  # Default project
DOPPLER_CONFIG=prd  # Default config

# 1Password Integration
OP_SERVICE_ACCOUNT_TOKEN=your_service_account_token
ONEPASSWORD_VAULT=AI Credentials  # Default vault name

# Or for 1Password Connect
OP_CONNECT_HOST=https://your-connect-server
OP_CONNECT_TOKEN=your_connect_token
```

### Usage

1. **Access Environment Credentials**: Navigate to workspace settings → Environment Credentials
2. **Import from .env files**: Use the import wizard to scan and import detected API keys
3. **Configure external integrations**: Set up Vault, Doppler, or 1Password credentials
4. **Sync from external sources**: Use one-click sync buttons to pull secrets
5. **Test all credentials**: Run comprehensive validation across all credentials
6. **Monitor sync status**: View last sync times and external source indicators

## Security Considerations

- All API keys are encrypted at rest using Rails credentials
- External secret manager connections use secure authentication
- Environment variable scanning only reads, never writes to .env files
- Audit logging tracks all imports and sync operations
- Admin-only access ensures proper access control

## Troubleshooting

### Common Issues

- **Vault connection failed**: Check `VAULT_ADDR` and `VAULT_TOKEN` configuration
- **Doppler CLI not found**: Install Doppler CLI and ensure it's in PATH
- **1Password access denied**: Verify service account token or Connect API credentials
- **API key format invalid**: Some providers have specific format requirements
- **Model not supported**: Check that the specified model is available for the provider

### Debug Steps

1. Check environment variables are properly set
2. Verify external service connectivity using their native CLI tools
3. Review Rails logs for detailed error messages
4. Use the test functionality to validate individual credentials
5. Check workspace admin permissions for the user