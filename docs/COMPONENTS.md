# Rails SaaS Starter Component Library

This component library provides a comprehensive set of reusable UI components built with ViewComponent and Tailwind CSS. The components are designed to be accessible, responsive, and highly customizable.

## Overview

The component system includes:

- **Core Components**: Button, Card, Alert, Modal, Loading
- **Navigation Components**: Navigation, Breadcrumb, WorkspaceSwitcher
- **Feature Components**: NotificationDropdown, TwoFactorSetup
- **Stimulus Controllers**: Dropdown, Modal, Alert, MobileMenu

## Installation

The components are automatically available when using the Rails SaaS Starter Template. They depend on:

- ViewComponent gem
- Stimulus (Hotwire)
- Tailwind CSS
- Noticed gem (for notifications)

## Core Components

### ButtonComponent

Renders buttons with consistent styling and multiple variants.

```erb
<!-- Basic usage -->
<%= render ButtonComponent.new(variant: :primary) do %>
  Save Changes
<% end %>

<!-- With loading state -->
<%= render ButtonComponent.new(variant: :primary, loading: @saving) do %>
  Save Changes
<% end %>

<!-- Helper method -->
<%= render_button "Delete", variant: :danger, size: :small %>
```

**Variants**: `:primary`, `:secondary`, `:danger`, `:outline`, `:ghost`
**Sizes**: `:small`, `:medium`, `:large`

### CardComponent

Container component for content sections.

```erb
<%= render CardComponent.new(padding: :large, hover: true) do %>
  <h3>Card Title</h3>
  <p>Card content goes here.</p>
<% end %>

<!-- Helper method -->
<%= render_card(shadow: :large) do %>
  Content here
<% end %>
```

### AlertComponent

Displays notifications and messages with icons and dismiss functionality.

```erb
<%= render AlertComponent.new(variant: :success, dismissible: true) do %>
  Operation completed successfully!
<% end %>

<!-- Helper method -->
<%= render_alert "Error occurred", variant: :error, dismissible: true %>
```

**Variants**: `:success`, `:error`, `:warning`, `:info`

### ModalComponent

Modal dialogs with proper focus management and accessibility.

```erb
<%= render ModalComponent.new(id: "confirm-modal", title: "Confirm Action", size: :medium) do %>
  <p>Are you sure you want to proceed?</p>
  <div class="mt-4 flex space-x-2">
    <%= render_button "Cancel", variant: :outline, onclick: "closeModal('confirm-modal')" %>
    <%= render_button "Confirm", variant: :danger %>
  </div>
<% end %>
```

### LoadingComponent

Various loading states and skeleton screens.

```erb
<!-- Spinner -->
<%= render LoadingComponent.new(variant: :spinner, text: "Loading...") %>

<!-- Skeleton loader -->
<%= render LoadingComponent.new(variant: :skeleton, size: :medium) %>

<!-- Overlay -->
<%= render LoadingComponent.new(variant: :spinner, overlay: true) %>
```

**Variants**: `:spinner`, `:dots`, `:pulse`, `:skeleton`, `:bars`

## Navigation Components

### NavigationComponent

Complete navigation bar with workspace switcher, notifications, and user menu.

```erb
<%= render NavigationComponent.new(
      current_user: current_user,
      current_workspace: @current_workspace,
      show_workspace_switcher: true,
      show_notifications: true
    ) %>
```

### BreadcrumbComponent

Navigation breadcrumbs for hierarchical pages.

```erb
<% content_for :breadcrumbs do %>
  <%= render BreadcrumbComponent.new(items: [
        { name: "Home", path: root_path },
        { name: "Workspaces", path: workspaces_path },
        { name: @workspace.name, path: workspace_path(@workspace) }
      ]) %>
<% end %>
```

### WorkspaceSwitcherComponent

Dropdown for switching between workspaces in multi-tenant applications.

```erb
<%= render WorkspaceSwitcherComponent.new(
      current_user: current_user,
      current_workspace: current_workspace
    ) %>
```

## Feature Components

### NotificationDropdownComponent

In-app notification dropdown with real-time updates.

```erb
<%= render NotificationDropdownComponent.new(user: current_user) %>
```

### TwoFactorSetupComponent

Complete 2FA setup flow with QR code generation.

```erb
<%= render TwoFactorSetupComponent.new(user: current_user) %>
```

## Stimulus Controllers

### Dropdown Controller

Handles dropdown menus with keyboard navigation and click outside to close.

```html
<div data-controller="dropdown">
  <button data-dropdown-target="trigger" data-action="click->dropdown#toggle">
    Menu
  </button>
  <div data-dropdown-target="menu" class="hidden">
    <!-- Menu items -->
  </div>
</div>
```

### Modal Controller

Manages modal dialogs with escape key handling and focus trapping.

```html
<div data-controller="modal" id="my-modal">
  <!-- Modal content -->
</div>

<script>
  // Open modal
  openModal('my-modal')
  
  // Close modal
  closeModal('my-modal')
</script>
```

### Alert Controller

Auto-dismissible alerts with customizable timeout.

```html
<div data-controller="alert" data-auto-dismiss="5">
  Alert message
  <button data-action="click->alert#dismiss">×</button>
</div>
```

## Helper Methods

The `ApplicationHelper` provides convenient methods for rendering components:

```erb
<!-- Buttons -->
<%= render_button "Save", variant: :primary %>

<!-- Cards -->
<%= render_card do %>
  Content
<% end %>

<!-- Alerts -->
<%= render_alert "Success!", variant: :success %>

<!-- Flash messages (automatically styled) -->
<%= render_flash_messages %>

<!-- Breadcrumbs -->
<%= render_breadcrumbs([
      { name: "Home", path: root_path },
      { name: "Current Page", path: "#" }
    ]) %>
```

## Customization

### Styling

Components use Tailwind CSS classes and can be customized by:

1. **Passing custom classes**: Most components accept additional CSS classes
2. **Modifying component classes**: Edit the component Ruby files
3. **Creating variants**: Add new variants to existing components
4. **Overriding templates**: Create custom ERB templates

### Adding New Components

1. Create a new component class in `app/components/`
2. Create the corresponding ERB template
3. Add Stimulus controller if needed in `app/javascript/controllers/`
4. Add helper methods to `ApplicationHelper` if desired

Example:

```ruby
# app/components/badge_component.rb
class BadgeComponent < ApplicationComponent
  def initialize(variant: :default, **html_options)
    @variant = variant
    @html_options = html_options
  end
  
  private
  
  attr_reader :variant, :html_options
  
  def badge_classes
    case variant
    when :success
      'bg-green-100 text-green-800'
    when :error
      'bg-red-100 text-red-800'
    else
      'bg-gray-100 text-gray-800'
    end
  end
end
```

```erb
<!-- app/components/badge_component.html.erb -->
<span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium <%= badge_classes %>">
  <%= content %>
</span>
```

## Best Practices

1. **Accessibility**: All components include proper ARIA labels and keyboard navigation
2. **Responsive Design**: Components work on mobile and desktop
3. **Performance**: Components are optimized for minimal DOM manipulation
4. **Consistency**: Use the provided design tokens and spacing
5. **Testing**: Write tests for custom components using the provided patterns

## Browser Support

- Modern browsers (Chrome, Firefox, Safari, Edge)
- ES6+ JavaScript features
- CSS Grid and Flexbox
- Stimulus framework requirements

## Contributing

When adding new components:

1. Follow the existing naming conventions
2. Include proper accessibility features
3. Add responsive design considerations
4. Write documentation and examples
5. Test across different browsers and devices