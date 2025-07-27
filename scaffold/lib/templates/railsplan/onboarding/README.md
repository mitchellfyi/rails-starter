# Onboarding Module

Wizard-style onboarding for new users that guides them through initial setup process.

## Features

- **Multi-step wizard** that guides new users through setup
- **Adaptive steps** based on installed modules (workspace, billing, AI)
- **Progress tracking** with ability to skip or resume later
- **Helpful tooltips** and examples throughout the journey
- **Module detection** to only show relevant onboarding steps
- **User-friendly interface** with clear navigation and progress indicators

## Installation

1. Install the onboarding module:
   ```bash
   bin/railsplan add onboarding
   ```

2. Run the migrations:
   ```bash
   rails db:migrate
   ```

3. Add onboarding to your user registration flow (optional):
   ```erb
   <!-- After user signs up -->
   <% if current_user.onboarding_incomplete? %>
     <%= link_to "Complete Setup", onboarding_path, class: "btn btn-primary" %>
   <% end %>
   ```

## Models

### OnboardingProgress
- `user`: Reference to the user completing onboarding
- `current_step`: Current step in the onboarding process
- `completed_steps`: JSON array of completed step names
- `skipped`: Boolean indicating if user skipped onboarding
- `completed_at`: Timestamp when onboarding was completed

## Available Steps

The onboarding wizard adapts to show only relevant steps based on installed modules:

### Core Steps (always available)
1. **Welcome** - Introduction to the application
2. **Create Workspace** - Set up first workspace (if workspace module installed)
3. **Explore Features** - Overview of key application features

### Conditional Steps (based on installed modules)
- **Invite Colleagues** - Send invitations (requires workspace module)
- **Connect Billing** - Set up payment methods (requires billing module)  
- **Connect AI Providers** - Configure AI settings (requires AI module)

## Usage

### Starting Onboarding
```ruby
# Automatically triggered for new users, or manually:
current_user.start_onboarding!
redirect_to onboarding_path
```

### Checking Progress
```ruby
# In controllers or views
current_user.onboarding_complete?
current_user.onboarding_progress.current_step
current_user.onboarding_progress.completed_steps
```

### Custom Step Logic
```ruby
# Add custom completion logic for steps
class CustomOnboardingStepHandler < OnboardingStepHandler
  def handle_custom_step(user)
    # Custom logic here
    mark_step_complete(user, 'custom_step')
  end
end
```

## Routes

The module provides these routes:

- `GET /onboarding` - Start or continue onboarding
- `GET /onboarding/step/:step` - Show specific step
- `POST /onboarding/step/:step` - Complete specific step
- `POST /onboarding/skip` - Skip onboarding entirely
- `POST /onboarding/resume` - Resume onboarding later

## Views

All views use Tailwind CSS classes and can be customized:
- `onboarding/index` - Main onboarding entry point
- `onboarding/steps/` - Individual step views
- `onboarding/_progress` - Progress indicator partial
- `onboarding/_navigation` - Step navigation partial

## User Model Integration

The onboarding module automatically extends your User model:

```ruby
# Available methods on User instances
user.onboarding_progress        # Get onboarding progress record
user.onboarding_complete?       # Check if onboarding is done
user.onboarding_incomplete?     # Check if onboarding needs completion
user.start_onboarding!          # Initialize onboarding
user.complete_onboarding!       # Mark onboarding as complete
user.skip_onboarding!           # Skip onboarding process
```

## Customization

### Adding Custom Steps
1. Create a new step view in `app/views/onboarding/steps/`
2. Update the `OnboardingStepHandler` to include your step logic
3. Modify the step sequence in the controller

### Module Detection
The system automatically detects installed modules by checking:
- Workspace module: presence of `Workspace` model
- Billing module: presence of `Subscription` model  
- AI module: presence of `LLMOutput` model

### Styling
Customize the appearance by editing the CSS classes in the view templates.

## Testing

The module includes comprehensive tests:
- **Model tests**: OnboardingProgress model validations and methods
- **Controller tests**: All onboarding flow actions
- **Integration tests**: Complete wizard flow with different module combinations
- **Feature tests**: End-to-end user experience

Run tests:
```bash
rails test test/models/onboarding_progress_test.rb
rails test test/controllers/onboarding_controller_test.rb
rails test test/integration/onboarding_flow_test.rb
```

## Security Considerations

- All onboarding actions require user authentication
- Progress tracking respects user privacy
- Skip option available to respect user choice
- No sensitive data stored in onboarding progress

## Multi-tenancy Support

The onboarding module works seamlessly with the workspace system:
- Each user has their own onboarding progress
- Workspace creation step integrates with existing workspace module
- Team invitations respect workspace permissions

Perfect for improving user activation and reducing time-to-value for new users.