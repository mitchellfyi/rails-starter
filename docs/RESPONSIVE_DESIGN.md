# Responsive Design Patterns

This document outlines the responsive design patterns used throughout the Rails SaaS Starter Template scaffolded views.

## Design Principles

### Mobile-First Approach
All views are built using a mobile-first approach with progressive enhancement:
- Start with mobile-optimized layouts
- Add complexity for larger screens using Tailwind's responsive breakpoints
- Ensure touch-friendly interface elements on mobile devices

### Breakpoints
We use Tailwind CSS's default breakpoints:
- `sm:` (640px+) - Small tablets and larger phones
- `md:` (768px+) - Tablets
- `lg:` (1024px+) - Small laptops
- `xl:` (1280px+) - Desktop
- `2xl:` (1536px+) - Large desktop

## Layout Patterns

### Grid Layouts
```erb
<!-- Mobile: Single column, Desktop: Multi-column -->
<div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4 sm:gap-6">
```

### Sidebar Layouts
```erb
<!-- Mobile: Stacked, Desktop: Sidebar -->
<div class="grid grid-cols-1 xl:grid-cols-3 gap-6">
  <main class="xl:col-span-2">...</main>
  <aside>...</aside>
</div>
```

### Card Layouts
```erb
<!-- Responsive cards with consistent spacing -->
<article class="bg-white border border-gray-200 rounded-lg p-4 sm:p-6 hover:shadow-md transition-shadow">
```

## Component Patterns

### Headers and Navigation
- Stack elements vertically on mobile
- Horizontal layout on larger screens
- Responsive typography (text-2xl sm:text-3xl)

### Forms
- Full-width inputs on mobile
- Optimized spacing and touch targets
- Clear labels and help text
- Responsive button layouts

### Tables vs Cards
- Use card layouts for mobile devices
- Switch to traditional tables on larger screens
- Ensure all information is accessible on both layouts

### Modals
- Full-screen modals on mobile
- Centered dialogs on desktop
- Responsive button stacking
- Proper focus management

## Accessibility Features

### Semantic HTML
- Proper heading hierarchy (h1, h2, h3)
- Semantic elements (main, aside, section, article)
- ARIA labels and roles where appropriate

### Focus Management
- Visible focus indicators
- Logical tab order
- Proper focus trapping in modals

### Screen Reader Support
- Descriptive link text
- Form labels and fieldsets
- Status indicators and state changes

## Button Patterns

### Primary Actions
```erb
<%= link_to "Action", path, class: "inline-flex justify-center items-center px-4 py-2 bg-blue-600 hover:bg-blue-700 text-white font-medium rounded-lg shadow-sm transition-colors" %>
```

### Secondary Actions
```erb
<%= link_to "Action", path, class: "inline-flex justify-center items-center px-4 py-2 border border-gray-300 text-gray-700 bg-white hover:bg-gray-50 rounded-lg shadow-sm transition-colors" %>
```

### Mobile Button Stacks
```erb
<!-- Mobile: Full width, stacked -->
<div class="flex flex-col sm:flex-row gap-3">
  <button class="w-full sm:w-auto ...">Primary</button>
  <button class="w-full sm:w-auto ...">Secondary</button>
</div>
```

## Typography Scale

### Responsive Headings
- `text-2xl sm:text-3xl` for main page titles
- `text-lg` for section headings
- `text-sm` for helper text and metadata

### Content Hierarchy
- Use consistent font weights (font-medium, font-semibold)
- Proper color contrast (text-gray-900, text-gray-600, text-gray-500)
- Responsive line heights and spacing

## Color and Theming

### Status Colors
- Success: `bg-green-100 text-green-800`
- Warning: `bg-yellow-100 text-yellow-800`
- Error: `bg-red-100 text-red-800`
- Info: `bg-blue-100 text-blue-800`

### Interactive States
- Hover: Slightly darker backgrounds
- Focus: Ring outlines (`focus:ring-2 focus:ring-blue-500`)
- Active: Clear visual feedback

## Implementation Examples

See the following scaffolded views for implementation examples:

### Workspace Views
- `workspaces/index.html.erb` - Responsive grid layout
- `workspaces/show.html.erb` - Sidebar layout with responsive cards
- `workspaces/new.html.erb` - Mobile-optimized form
- `memberships/index.html.erb` - Table to card transformation

### Billing Views
- `billing/index.html.erb` - Dashboard with responsive metrics
- Invoice table with mobile card fallback

### CMS Views
- `admin/cms/posts/_form.html.erb` - Complex form with responsive sidebar

### AI Views
- `llm_outputs/index.html.erb` - Card-based responsive layout

## Testing Responsiveness

### Manual Testing
1. Use browser dev tools to test different viewport sizes
2. Test on actual mobile devices when possible
3. Verify touch targets are large enough (minimum 44px)
4. Check text readability at different sizes

### Automated Testing
- Include responsive design tests in your test suite
- Test critical user flows on mobile devices
- Verify accessibility with screen readers

## Best Practices

1. **Start Mobile**: Design for the smallest screen first
2. **Progressive Enhancement**: Add features for larger screens
3. **Touch-Friendly**: Ensure interactive elements are easily tappable
4. **Performance**: Optimize images and assets for mobile
5. **Accessibility**: Test with keyboard navigation and screen readers
6. **Consistency**: Use established patterns across the application