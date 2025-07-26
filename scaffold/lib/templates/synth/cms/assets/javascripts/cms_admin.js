// CMS Admin JavaScript
// Handles admin interface interactions and enhancements

document.addEventListener('DOMContentLoaded', function() {
  // Initialize CMS functionality
  initializeTagInput();
  initializeSEOPreview();
  initializeSlugGeneration();
  initializeActionTextEnhancements();
  initializeFormValidation();
});

// Tag input functionality
function initializeTagInput() {
  const tagInputs = document.querySelectorAll('[data-tag-input]');
  
  tagInputs.forEach(input => {
    const container = input.parentElement;
    const hiddenInput = container.querySelector('input[type="hidden"]');
    
    input.addEventListener('keydown', function(e) {
      if (e.key === 'Enter' || e.key === ',') {
        e.preventDefault();
        addTag(input.value.trim(), container, hiddenInput);
        input.value = '';
      }
    });
    
    input.addEventListener('blur', function() {
      if (input.value.trim()) {
        addTag(input.value.trim(), container, hiddenInput);
        input.value = '';
      }
    });
  });
}

function addTag(tagName, container, hiddenInput) {
  if (!tagName) return;
  
  // Check if tag already exists
  const existingTags = Array.from(container.querySelectorAll('.tag-pill')).map(pill => 
    pill.textContent.replace('×', '').trim()
  );
  
  if (existingTags.includes(tagName)) return;
  
  // Create tag pill
  const pill = document.createElement('span');
  pill.className = 'tag-pill bg-blue-100 text-blue-800';
  pill.innerHTML = `
    ${tagName}
    <button type="button" class="ml-1 text-blue-600 hover:text-blue-800" onclick="removeTag(this)">×</button>
  `;
  
  // Insert before input
  const input = container.querySelector('[data-tag-input]');
  container.insertBefore(pill, input);
  
  // Update hidden input
  updateTagsHiddenInput(container, hiddenInput);
}

function removeTag(button) {
  const pill = button.parentElement;
  const container = pill.parentElement;
  const hiddenInput = container.querySelector('input[type="hidden"]');
  
  pill.remove();
  updateTagsHiddenInput(container, hiddenInput);
}

function updateTagsHiddenInput(container, hiddenInput) {
  const tags = Array.from(container.querySelectorAll('.tag-pill')).map(pill => 
    pill.textContent.replace('×', '').trim()
  );
  
  if (hiddenInput) {
    hiddenInput.value = tags.join(',');
  }
}

// SEO preview functionality
function initializeSEOPreview() {
  const seoForm = document.querySelector('[data-seo-form]');
  if (!seoForm) return;
  
  const titleInput = seoForm.querySelector('[data-seo-title]');
  const descriptionInput = seoForm.querySelector('[data-seo-description]');
  const preview = document.querySelector('[data-seo-preview]');
  
  if (!preview) return;
  
  function updatePreview() {
    const title = titleInput?.value || 'Page Title';
    const description = descriptionInput?.value || 'Page description...';
    
    preview.innerHTML = `
      <div class="seo-preview-result">
        <div class="text-blue-600 text-lg hover:underline cursor-pointer">${title}</div>
        <div class="text-green-700 text-sm">https://yourdomain.com/page-url</div>
        <div class="text-gray-600 text-sm">${description}</div>
      </div>
    `;
  }
  
  titleInput?.addEventListener('input', updatePreview);
  descriptionInput?.addEventListener('input', updatePreview);
  
  // Initial preview
  updatePreview();
}

// Slug generation from title
function initializeSlugGeneration() {
  const titleInputs = document.querySelectorAll('[data-generate-slug]');
  
  titleInputs.forEach(titleInput => {
    const slugInput = document.querySelector(titleInput.dataset.generateSlug);
    if (!slugInput) return;
    
    titleInput.addEventListener('input', function() {
      // Only auto-generate if slug is empty
      if (slugInput.value === '') {
        const slug = generateSlug(titleInput.value);
        slugInput.value = slug;
      }
    });
  });
}

function generateSlug(text) {
  return text
    .toLowerCase()
    .trim()
    .replace(/[^\w\s-]/g, '') // Remove special characters
    .replace(/[\s_-]+/g, '-') // Replace spaces and underscores with hyphens
    .replace(/^-+|-+$/g, ''); // Remove leading/trailing hyphens
}

// ActionText enhancements
function initializeActionTextEnhancements() {
  // Add custom toolbar buttons or styling
  const trixEditors = document.querySelectorAll('trix-editor');
  
  trixEditors.forEach(editor => {
    editor.addEventListener('trix-initialize', function() {
      // Add custom styling or buttons if needed
      const toolbar = editor.toolbarElement;
      if (toolbar) {
        toolbar.classList.add('trix-toolbar-enhanced');
      }
    });
    
    // Track content changes for auto-save functionality
    editor.addEventListener('trix-change', function() {
      // Implement auto-save if needed
      debounce(() => {
        console.log('Content changed, could auto-save here');
      }, 2000)();
    });
  });
}

// Form validation enhancements
function initializeFormValidation() {
  const forms = document.querySelectorAll('[data-cms-form]');
  
  forms.forEach(form => {
    form.addEventListener('submit', function(e) {
      if (!validateForm(form)) {
        e.preventDefault();
        return false;
      }
      
      // Show loading state
      const submitButton = form.querySelector('[type="submit"]');
      if (submitButton) {
        submitButton.disabled = true;
        submitButton.textContent = 'Saving...';
      }
    });
  });
}

function validateForm(form) {
  let isValid = true;
  const requiredFields = form.querySelectorAll('[required]');
  
  requiredFields.forEach(field => {
    if (!field.value.trim()) {
      showFieldError(field, 'This field is required');
      isValid = false;
    } else {
      clearFieldError(field);
    }
  });
  
  // Validate SEO meta description length
  const metaDescription = form.querySelector('[data-seo-description]');
  if (metaDescription && metaDescription.value.length > 160) {
    showFieldError(metaDescription, 'Meta description should be 160 characters or less');
    isValid = false;
  }
  
  // Validate SEO meta title length
  const metaTitle = form.querySelector('[data-seo-title]');
  if (metaTitle && metaTitle.value.length > 60) {
    showFieldError(metaTitle, 'Meta title should be 60 characters or less');
    isValid = false;
  }
  
  return isValid;
}

function showFieldError(field, message) {
  clearFieldError(field);
  
  const errorDiv = document.createElement('div');
  errorDiv.className = 'cms-field-error text-red-600 text-sm mt-1';
  errorDiv.textContent = message;
  
  field.parentElement.appendChild(errorDiv);
  field.classList.add('border-red-300', 'focus:border-red-500', 'focus:ring-red-500');
}

function clearFieldError(field) {
  const existingError = field.parentElement.querySelector('.cms-field-error');
  if (existingError) {
    existingError.remove();
  }
  
  field.classList.remove('border-red-300', 'focus:border-red-500', 'focus:ring-red-500');
}

// Utility functions
function debounce(func, wait) {
  let timeout;
  return function executedFunction(...args) {
    const later = () => {
      clearTimeout(timeout);
      func(...args);
    };
    clearTimeout(timeout);
    timeout = setTimeout(later, wait);
  };
}

// Character count for form fields
function initializeCharacterCounts() {
  const fieldsWithCounts = document.querySelectorAll('[data-character-count]');
  
  fieldsWithCounts.forEach(field => {
    const maxLength = parseInt(field.dataset.characterCount);
    const countDisplay = document.createElement('div');
    countDisplay.className = 'text-sm text-gray-500 mt-1';
    
    function updateCount() {
      const remaining = maxLength - field.value.length;
      countDisplay.textContent = `${remaining} characters remaining`;
      
      if (remaining < 0) {
        countDisplay.classList.add('text-red-600');
        countDisplay.classList.remove('text-gray-500');
      } else {
        countDisplay.classList.remove('text-red-600');
        countDisplay.classList.add('text-gray-500');
      }
    }
    
    field.addEventListener('input', updateCount);
    field.parentElement.appendChild(countDisplay);
    updateCount();
  });
}

// Initialize character counts
document.addEventListener('DOMContentLoaded', initializeCharacterCounts);

// Auto-resize textareas
function initializeAutoResize() {
  const textareas = document.querySelectorAll('[data-auto-resize]');
  
  textareas.forEach(textarea => {
    function resize() {
      textarea.style.height = 'auto';
      textarea.style.height = textarea.scrollHeight + 'px';
    }
    
    textarea.addEventListener('input', resize);
    resize(); // Initial resize
  });
}

document.addEventListener('DOMContentLoaded', initializeAutoResize);