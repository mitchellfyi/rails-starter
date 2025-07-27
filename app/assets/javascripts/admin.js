// Admin Dashboard JavaScript Functionality

class AdminDashboard {
  constructor() {
    this.init();
  }

  init() {
    this.setupMobileMenu();
    this.setupKeyboardNavigation();
    this.setupFocusManagement();
  }

  // Mobile menu functionality
  setupMobileMenu() {
    const mobileMenuBtn = document.querySelector('.mobile-menu-btn');
    const sidebar = document.querySelector('.admin-sidebar');

    if (mobileMenuBtn && sidebar) {
      mobileMenuBtn.addEventListener('click', () => {
        sidebar.classList.toggle('mobile-open');
        
        // Update aria-expanded
        const isOpen = sidebar.classList.contains('mobile-open');
        mobileMenuBtn.setAttribute('aria-expanded', isOpen);
        
        // Focus management
        if (isOpen) {
          const firstNavLink = sidebar.querySelector('.sidebar-nav-link');
          if (firstNavLink) {
            firstNavLink.focus();
          }
        }
      });

      // Close sidebar when clicking outside
      document.addEventListener('click', (event) => {
        if (sidebar.classList.contains('mobile-open') &&
            !sidebar.contains(event.target) &&
            !mobileMenuBtn.contains(event.target)) {
          sidebar.classList.remove('mobile-open');
          mobileMenuBtn.setAttribute('aria-expanded', 'false');
        }
      });

      // Close on escape key
      document.addEventListener('keydown', (event) => {
        if (event.key === 'Escape' && sidebar.classList.contains('mobile-open')) {
          sidebar.classList.remove('mobile-open');
          mobileMenuBtn.setAttribute('aria-expanded', 'false');
          mobileMenuBtn.focus();
        }
      });
    }
  }

  // Keyboard navigation
  setupKeyboardNavigation() {
    const navLinks = document.querySelectorAll('.sidebar-nav-link');
    
    navLinks.forEach((link, index) => {
      link.addEventListener('keydown', (event) => {
        let targetIndex;
        
        switch (event.key) {
          case 'ArrowDown':
            event.preventDefault();
            targetIndex = (index + 1) % navLinks.length;
            navLinks[targetIndex].focus();
            break;
          case 'ArrowUp':
            event.preventDefault();
            targetIndex = (index - 1 + navLinks.length) % navLinks.length;
            navLinks[targetIndex].focus();
            break;
          case 'Home':
            event.preventDefault();
            navLinks[0].focus();
            break;
          case 'End':
            event.preventDefault();
            navLinks[navLinks.length - 1].focus();
            break;
        }
      });
    });

    // Quick navigation shortcuts
    document.addEventListener('keydown', (event) => {
      // Alt + D for Dashboard
      if (event.altKey && event.key === 'd') {
        event.preventDefault();
        const dashboardLink = document.querySelector('a[href*="admin"]');
        if (dashboardLink) {
          dashboardLink.click();
        }
      }
      
      // Alt + F for Feature Flags
      if (event.altKey && event.key === 'f') {
        event.preventDefault();
        const flagsLink = document.querySelector('a[href*="feature_flags"]');
        if (flagsLink) {
          flagsLink.click();
        }
      }
      
      // Alt + A for Audit Logs
      if (event.altKey && event.key === 'a') {
        event.preventDefault();
        const auditLink = document.querySelector('a[href*="audit"]');
        if (auditLink) {
          auditLink.click();
        }
      }
    });
  }

  // Focus management for better accessibility
  setupFocusManagement() {
    // Add focus indicators to interactive elements
    const interactiveElements = document.querySelectorAll(
      'a, button, input, select, textarea, [tabindex]'
    );

    interactiveElements.forEach(element => {
      element.addEventListener('focus', () => {
        element.classList.add('keyboard-focus');
      });

      element.addEventListener('blur', () => {
        element.classList.remove('keyboard-focus');
      });

      // Remove focus class on mouse down to avoid conflict
      element.addEventListener('mousedown', () => {
        element.classList.remove('keyboard-focus');
      });
    });

    // Skip link functionality
    const skipLink = document.querySelector('.skip-link');
    if (skipLink) {
      skipLink.addEventListener('click', (event) => {
        event.preventDefault();
        const target = document.querySelector(skipLink.getAttribute('href'));
        if (target) {
          target.focus();
          target.scrollIntoView();
        }
      });
    }
  }

  // Update active nav item based on current page
  updateActiveNavigation() {
    const currentPath = window.location.pathname;
    const navLinks = document.querySelectorAll('.sidebar-nav-link');
    
    navLinks.forEach(link => {
      link.classList.remove('active');
      if (link.getAttribute('href') === currentPath ||
          (currentPath.includes(link.getAttribute('href')) && 
           link.getAttribute('href') !== '/admin')) {
        link.classList.add('active');
      }
    });
  }

  // Utility method to show notifications
  showNotification(message, type = 'info') {
    const notification = document.createElement('div');
    notification.className = `alert alert-${type}`;
    notification.textContent = message;
    notification.style.position = 'fixed';
    notification.style.top = '1rem';
    notification.style.right = '1rem';
    notification.style.zIndex = '100';
    notification.style.minWidth = '300px';

    document.body.appendChild(notification);

    // Auto-remove after 5 seconds
    setTimeout(() => {
      if (notification.parentNode) {
        notification.parentNode.removeChild(notification);
      }
    }, 5000);

    // Allow manual dismissal
    notification.addEventListener('click', () => {
      if (notification.parentNode) {
        notification.parentNode.removeChild(notification);
      }
    });
  }
}

// Initialize when DOM is loaded
document.addEventListener('DOMContentLoaded', () => {
  const adminDashboard = new AdminDashboard();
  adminDashboard.updateActiveNavigation();
});

// Re-update navigation on turbo:load for SPA-style navigation
document.addEventListener('turbo:load', () => {
  const adminDashboard = new AdminDashboard();
  adminDashboard.updateActiveNavigation();
});