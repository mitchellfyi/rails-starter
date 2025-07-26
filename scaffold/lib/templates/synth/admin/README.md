# Admin Module

Administrative dashboard with user management and system monitoring.

## Features

- **User Management**: View, edit, and manage user accounts
- **Impersonation**: Safely impersonate users for support
- **Audit Logs**: Track system changes and user actions
- **System Monitoring**: View application metrics and health
- **Feature Flags**: Toggle features on/off without deployments
- **Background Jobs**: Monitor Sidekiq queues and jobs

## Installation

```sh
bin/synth add admin
```

This creates admin controllers, views, and adds an admin role to the User model.