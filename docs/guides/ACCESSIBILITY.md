# Accessibility Guidelines for Rails SaaS Starter Template

This document outlines the accessibility standards and practices to follow when contributing to the Rails SaaS Starter Template to ensure WCAG 2.1 AA compliance.

## Table of Contents

- [Overview](#overview)
- [HTML Standards](#html-standards)
- [CSS and Styling](#css-and-styling)
- [JavaScript and Interactivity](#javascript-and-interactivity)
- [Testing](#testing)
- [Tools and Resources](#tools-and-resources)

## Overview

The Rails SaaS Starter Template is committed to providing an accessible experience for all users, including those using assistive technologies like screen readers, keyboard navigation, and voice recognition software.

### Accessibility Standards

We follow **WCAG 2.1 AA** standards, which include:

- **Perceivable**: Information must be presentable in ways users can perceive
- **Operable**: Interface components must be operable by all users
- **Understandable**: Information and UI operation must be understandable
- **Robust**: Content must be robust enough for assistive technologies

## HTML Standards

### Semantic HTML

Always use semantic HTML elements to provide proper structure and meaning:

```erb
<!-- ✅ Good: Uses semantic elements -->
<header>
  <nav aria-label="Main navigation">
    <ul>
      <li><a href="/" aria-current="page">Home</a></li>
      <li><a href="/about">About</a></li>
    </ul>
  </nav>
</header>

<main>
  <section>
    <h1>Page Title</h1>
    <p>Content goes here...</p>
  </section>
</main>

<!-- ❌ Bad: Uses generic divs -->
<div class="header">
  <div class="nav">
    <div><a href="/">Home</a></div>
  </div>
</div>

<div class="content">
  <div class="title">Page Title</div>
</div>
```

### Heading Hierarchy

Maintain a logical heading hierarchy (h1 → h2 → h3, etc.):

```erb
<!-- ✅ Good: Logical hierarchy -->
<h1>Main Page Title</h1>
  <h2>Section Heading</h2>
    <h3>Subsection Heading</h3>
  <h2>Another Section</h2>

<!-- ❌ Bad: Skips levels -->
<h1>Main Page Title</h1>
  <h4>Subsection</h4> <!-- Skips h2, h3 -->
```

### Images and Media

All images must have appropriate alt text:

```erb
<!-- ✅ Good: Descriptive alt text -->
<img src="chart.png" alt="Sales increased 25% from January to March 2024">

<!-- ✅ Good: Decorative image hidden from screen readers -->
<img src="decoration.png" alt="" aria-hidden="true">

<!-- ❌ Bad: Missing alt attribute -->
<img src="important-chart.png">
```

### Forms

Forms must be properly labeled and structured:

```erb
<!-- ✅ Good: Proper form labeling -->
<form>
  <div class="form-field">
    <label for="email">Email Address <span class="required">*</span></label>
    <input type="email" id="email" name="email" required aria-describedby="email-help">
    <div id="email-help" class="form-help">We'll never share your email address</div>
  </div>
  
  <button type="submit">Submit</button>
</form>

<!-- Using the accessibility helper -->
<%= form_with model: @user do |form| %>
  <%= accessible_form_field(form, :email, required: true, help: "We'll never share your email") %>
  <%= form.submit "Create Account", class: "btn btn-primary" %>
<% end %>
```

### Links and Navigation

Provide clear, descriptive link text:

```erb
<!-- ✅ Good: Descriptive link text -->
<a href="/contact">Contact us about your project</a>

<!-- ✅ Good: Link with additional context -->
<a href="/report.pdf">
  Download annual report
  <span class="sr-only">(PDF, 2.3MB)</span>
</a>

<!-- ❌ Bad: Non-descriptive text -->
<a href="/contact">Click here</a>
<a href="/report.pdf">Download</a>
```

## CSS and Styling

### Focus Indicators

All interactive elements must have visible focus indicators:

```css
/* ✅ Good: Visible focus styles */
.btn:focus {
  outline: 2px solid #3b82f6;
  outline-offset: 2px;
}

/* Use the existing focus utility classes */
.focus:ring-2:focus {
  box-shadow: 0 0 0 2px #3b82f6;
}
```

### Color Contrast

Ensure sufficient color contrast ratios:

- **Normal text**: 4.5:1 contrast ratio
- **Large text** (18pt+ or 14pt+ bold): 3:1 contrast ratio
- **UI components**: 3:1 contrast ratio

```css
/* ✅ Good: High contrast */
.text-primary {
  color: #1d4ed8; /* Blue with sufficient contrast on white */
}

/* ❌ Bad: Low contrast */
.text-light {
  color: #d1d5db; /* Too light on white background */
}
```

### Screen Reader Support

Use screen reader utilities appropriately:

```erb
<!-- Hide decorative content -->
<svg aria-hidden="true">...</svg>

<!-- Screen reader only content -->
<span class="sr-only">Opens in new window</span>

<!-- Content that becomes visible on focus -->
<a href="#main" class="sr-only focus:not-sr-only">Skip to main content</a>
```

### Responsive Design

Ensure touch targets are at least 44x44 pixels on mobile:

```css
@media (max-width: 768px) {
  button,
  .btn,
  a {
    min-height: 44px;
    min-width: 44px;
  }
}
```

## JavaScript and Interactivity

### ARIA Attributes

Use ARIA attributes to enhance accessibility:

```erb
<!-- Modal/Dialog -->
<div role="dialog" aria-modal="true" aria-labelledby="modal-title">
  <h2 id="modal-title">Confirm Action</h2>
  <!-- Modal content -->
</div>

<!-- Dropdown menu -->
<button aria-expanded="false" aria-haspopup="true" aria-controls="menu-list">
  Menu
</button>
<ul id="menu-list" role="menu" hidden>
  <li role="menuitem"><a href="/profile">Profile</a></li>
</ul>
```

### Keyboard Navigation

Ensure all interactive elements are keyboard accessible:

```javascript
// ✅ Good: Keyboard event handling
button.addEventListener('keydown', (event) => {
  if (event.key === 'Enter' || event.key === ' ') {
    event.preventDefault();
    handleClick();
  }
});

// ✅ Good: Focus management
function openModal() {
  modal.classList.remove('hidden');
  modal.querySelector('h2').focus();
}
```

### Live Regions

Use ARIA live regions for dynamic content updates:

```erb
<!-- Polite announcements -->
<div aria-live="polite" id="status" class="sr-only"></div>

<!-- Urgent announcements -->
<div aria-live="assertive" id="errors" class="sr-only"></div>

<script>
  // Announce status changes
  document.getElementById('status').textContent = 'Form submitted successfully';
</script>
```

## Testing

### Manual Testing

1. **Keyboard Navigation**
   - Tab through all interactive elements
   - Use keyboard shortcuts (Space, Enter, Arrow keys)
   - Ensure focus is visible and logical

2. **Screen Reader Testing**
   - Test with VoiceOver (Mac), NVDA (Windows), or ORCA (Linux)
   - Verify all content is announced correctly
   - Check heading navigation works

3. **High Contrast Mode**
   - Test in Windows High Contrast mode
   - Verify all content remains visible

### Automated Testing

Run the accessibility compliance test:

```bash
ruby test/accessibility_test.rb
```

### Using Browser DevTools

1. **Chrome DevTools**
   - Open Lighthouse tab
   - Run accessibility audit
   - Review and fix issues

2. **Firefox DevTools**
   - Use built-in accessibility inspector
   - Check contrast ratios and semantic structure

## Tools and Resources

### Browser Extensions

- **axe DevTools**: Comprehensive accessibility testing
- **Wave**: Web accessibility evaluation
- **Colour Contrast Analyser**: Check color contrast ratios

### Online Tools

- [WebAIM Contrast Checker](https://webaim.org/resources/contrastchecker/)
- [WAVE Web Accessibility Evaluator](https://wave.webaim.org/)
- [axe-core Accessibility Rules](https://dequeuniversity.com/rules/axe/)

### Documentation

- [WCAG 2.1 Guidelines](https://www.w3.org/WAI/WCAG21/quickref/)
- [MDN Accessibility](https://developer.mozilla.org/en-US/docs/Web/Accessibility)
- [A11y Project Checklist](https://www.a11yproject.com/checklist/)

## Accessibility Helper Usage

The template includes an `AccessibilityHelper` with useful methods:

```erb
<!-- Skip links -->
<%= skip_link("main-content", "Skip to main content") %>

<!-- Accessible headings -->
<%= accessible_heading("Section Title", level: 2, class: "text-xl") %>

<!-- Accessible buttons -->
<%= accessible_button("Delete", 
    aria_label: "Delete user account", 
    class: "btn btn-danger") %>

<!-- Accessible navigation -->
<%= accessible_nav([
  { text: "Home", path: "/", class: "nav-link" },
  { text: "About", path: "/about", class: "nav-link" }
], label: "Main navigation") %>

<!-- Live regions -->
<%= accessible_live_region("status-updates", politeness: "polite") do %>
  <!-- Dynamic content will be announced -->
<% end %>
```

## Contributing

When contributing to the template:

1. **Test accessibility** before submitting PRs
2. **Use semantic HTML** and proper ARIA attributes
3. **Include alt text** for images
4. **Ensure keyboard navigation** works
5. **Test with screen readers** when possible
6. **Run the accessibility test suite**

### Pull Request Checklist

- [ ] All images have appropriate alt text
- [ ] Proper heading hierarchy is maintained
- [ ] Form elements are properly labeled
- [ ] Focus indicators are visible
- [ ] Color contrast meets WCAG AA standards
- [ ] Keyboard navigation works correctly
- [ ] ARIA attributes are used appropriately
- [ ] Accessibility tests pass

Remember: Accessibility is not just about compliance—it's about creating inclusive experiences for all users.