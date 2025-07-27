# Flowbite UI Components Module

Integrates Flowbite, a comprehensive UI component library built on top of Tailwind CSS, providing ready-to-use interactive components with JavaScript functionality.

## Features

- **Pre-built UI Components**: Buttons, forms, modals, dropdowns, navigation, and more
- **JavaScript Interactivity**: Built-in JavaScript behaviors for dynamic components  
- **Tailwind CSS Integration**: Seamlessly works with your existing Tailwind setup
- **Accessibility**: ARIA-compliant components with keyboard navigation support
- **Dark Mode Support**: Built-in dark theme variants for all components
- **Stimulus Controllers**: Optional Stimulus.js controllers for enhanced functionality

## Installation

```bash
bin/synth add flowbite
```

This will:
- Add Flowbite CSS and JavaScript files to your asset pipeline
- Configure Tailwind CSS to include Flowbite components
- Add example component templates
- Set up Stimulus controllers for enhanced component interactions

## Usage

### Basic Components

Once installed, you can use Flowbite components directly in your ERB templates:

```erb
<!-- Button -->
<button type="button" class="text-white bg-blue-700 hover:bg-blue-800 focus:ring-4 focus:ring-blue-300 font-medium rounded-lg text-sm px-5 py-2.5 me-2 mb-2 dark:bg-blue-600 dark:hover:bg-blue-700 focus:outline-none dark:focus:ring-blue-800">Default</button>

<!-- Modal -->
<div id="default-modal" tabindex="-1" aria-hidden="true" class="hidden overflow-y-auto overflow-x-hidden fixed top-0 right-0 left-0 z-50 justify-center items-center w-full md:inset-0 h-[calc(100%-1rem)] max-h-full">
  <!-- Modal content -->
</div>

<!-- Dropdown -->
<div class="relative inline-block text-left">
  <div>
    <button type="button" class="inline-flex w-full justify-center gap-x-1.5 rounded-md bg-white px-3 py-2 text-sm font-semibold text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 hover:bg-gray-50" id="menu-button" aria-expanded="true" aria-haspopup="true">
      Options
    </button>
  </div>
</div>
```

### Component Helpers

The module includes Rails helpers for common components:

```erb
<!-- Using helpers -->
<%= flowbite_button "Click me", type: :primary %>
<%= flowbite_modal "my-modal", title: "Modal Title" do %>
  <p>Modal content goes here</p>
<% end %>
<%= flowbite_dropdown trigger: "Dropdown", items: [
  { text: "Item 1", link: "#" },
  { text: "Item 2", link: "#" }
] %>
```

### Stimulus Integration

Enhanced components with Stimulus.js controllers:

```erb
<!-- Enhanced modal with Stimulus -->
<div data-controller="flowbite-modal">
  <%= flowbite_modal "enhanced-modal", title: "Enhanced Modal" do %>
    <p>This modal uses Stimulus for enhanced functionality</p>
  <% end %>
</div>

<!-- Enhanced dropdown -->
<div data-controller="flowbite-dropdown">
  <%= flowbite_dropdown trigger: "Enhanced Dropdown", items: dropdown_items %>
</div>
```

## Available Components

### Navigation
- Navbar
- Sidebar
- Breadcrumb
- Pagination

### Forms
- Input fields
- Select dropdowns
- Checkboxes and radios
- File uploads
- Form validation

### Data Display
- Tables
- Cards
- Lists
- Badges
- Avatars

### Feedback
- Alerts
- Toasts
- Progress bars
- Spinners

### Overlay
- Modals
- Tooltips
- Popovers
- Dropdowns

### Layout
- Grid system
- Containers
- Dividers

## Customization

### Tailwind Configuration

The module automatically updates your `tailwind.config.js` to include Flowbite:

```javascript
module.exports = {
  content: [
    './app/views/**/*.html.erb',
    './app/helpers/**/*.rb',
    './app/assets/stylesheets/**/*.css',
    './app/javascript/**/*.js',
    './node_modules/flowbite/**/*.js'
  ],
  plugins: [
    require('flowbite/plugin')
  ],
}
```

### Custom Themes

Customize Flowbite components to match your brand:

```css
/* app/assets/stylesheets/flowbite_custom.css */
:root {
  --flowbite-primary: #3b82f6;
  --flowbite-secondary: #64748b;
}

/* Override specific component styles */
.flowbite-btn-primary {
  background-color: var(--flowbite-primary);
}
```

## JavaScript Configuration

Configure Flowbite's JavaScript behavior:

```javascript
// app/javascript/flowbite_config.js
import { initFlowbite } from 'flowbite'

// Initialize all components
initFlowbite()

// Or initialize specific components
import { Modal, Dropdown } from 'flowbite'
```

## Files Added

- `app/javascript/flowbite_init.js` - Flowbite initialization
- `app/javascript/controllers/flowbite_*_controller.js` - Stimulus controllers
- `app/assets/stylesheets/flowbite_custom.css` - Custom styling
- `app/helpers/flowbite_helper.rb` - Rails helpers
- `app/views/shared/_flowbite_*.html.erb` - Component templates
- Updated `package.json` with Flowbite dependency
- Updated `tailwind.config.js` with Flowbite configuration

## Browser Support

- Modern browsers (Chrome, Firefox, Safari, Edge)
- IE11+ with polyfills
- Mobile browsers (iOS Safari, Chrome Mobile)

## Performance

- Tree-shakable JavaScript modules
- CSS purging with Tailwind
- Lazy loading for heavy components
- CDN delivery options

## Testing

Test your Flowbite components:

```ruby
# In your system tests
test "dropdown shows options when clicked" do
  visit root_path
  
  click_button "Dropdown trigger"
  assert_selector "[data-dropdown-toggle]", visible: true
  
  within "[data-dropdown-toggle]" do
    assert_link "Option 1"
    assert_link "Option 2"
  end
end
```

## Resources

- [Flowbite Documentation](https://flowbite.com/docs/getting-started/introduction/)
- [Flowbite Components](https://flowbite.com/docs/components/alerts/)
- [Tailwind CSS Documentation](https://tailwindcss.com/docs)
- [Stimulus Handbook](https://stimulus.hotwired.dev/handbook/introduction)