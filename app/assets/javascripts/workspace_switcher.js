// Workspace Switcher with Fuzzy Search

class WorkspaceSwitcher {
  constructor(element) {
    this.element = element;
    this.trigger = element.querySelector('[data-workspace-switcher-target="trigger"]');
    this.menu = element.querySelector('[data-workspace-switcher-target="menu"]');
    this.searchInput = element.querySelector('[data-workspace-switcher-target="searchInput"]');
    this.list = element.querySelector('[data-workspace-switcher-target="list"]');
    this.noResults = element.querySelector('[data-workspace-switcher-target="noResults"]');
    this.items = [];
    this.filteredItems = [];
    this.highlightedIndex = -1;
    this.isOpen = false;

    this.init();
  }

  init() {
    this.collectItems();
    this.bindEvents();
  }

  collectItems() {
    this.items = Array.from(this.element.querySelectorAll('[data-workspace-switcher-target="item"]')).map(item => ({
      element: item,
      name: item.dataset.workspaceName || item.textContent.trim().toLowerCase(),
      searchText: this.createSearchText(item)
    }));
    this.filteredItems = [...this.items];
  }

  createSearchText(element) {
    // Create comprehensive search text from element content
    const name = element.dataset.workspaceName || '';
    const textContent = element.textContent || '';
    return `${name} ${textContent}`.toLowerCase().replace(/\s+/g, ' ').trim();
  }

  bindEvents() {
    // Toggle menu
    this.trigger?.addEventListener('click', () => this.toggle());

    // Search functionality
    this.searchInput?.addEventListener('input', (e) => this.search(e.target.value));

    // Keyboard navigation
    this.searchInput?.addEventListener('keydown', (e) => this.handleKeydown(e));
    this.element.addEventListener('keydown', (e) => this.handleGlobalKeydown(e));

    // Close on outside click
    document.addEventListener('click', (e) => this.handleOutsideClick(e));

    // Close on escape
    document.addEventListener('keydown', (e) => {
      if (e.key === 'Escape' && this.isOpen) {
        this.close();
      }
    });
  }

  toggle() {
    if (this.isOpen) {
      this.close();
    } else {
      this.open();
    }
  }

  open() {
    this.isOpen = true;
    this.menu.classList.remove('hidden');
    this.element.setAttribute('aria-expanded', 'true');
    this.searchInput?.focus();
    this.highlightedIndex = -1;
    this.updateHighlight();
  }

  close() {
    this.isOpen = false;
    this.menu.classList.add('hidden');
    this.element.setAttribute('aria-expanded', 'false');
    this.highlightedIndex = -1;
    this.clearSearch();
  }

  search(query) {
    const normalizedQuery = query.toLowerCase().trim();
    
    if (!normalizedQuery) {
      this.filteredItems = [...this.items];
      this.showAllItems();
      this.hideNoResults();
      return;
    }

    // Fuzzy search implementation
    this.filteredItems = this.items.filter(item => 
      this.fuzzyMatch(item.searchText, normalizedQuery)
    ).sort((a, b) => 
      this.calculateRelevanceScore(a.searchText, normalizedQuery) - 
      this.calculateRelevanceScore(b.searchText, normalizedQuery)
    );

    this.updateItemsVisibility();
    this.highlightedIndex = this.filteredItems.length > 0 ? 0 : -1;
    this.updateHighlight();
  }

  fuzzyMatch(text, query) {
    // Simple fuzzy matching - checks if all characters in query appear in order in text
    let textIndex = 0;
    let queryIndex = 0;
    
    while (textIndex < text.length && queryIndex < query.length) {
      if (text[textIndex] === query[queryIndex]) {
        queryIndex++;
      }
      textIndex++;
    }
    
    return queryIndex === query.length;
  }

  calculateRelevanceScore(text, query) {
    // Lower score = more relevant
    let score = 0;
    
    // Exact match gets highest priority
    if (text.includes(query)) {
      score += 100;
      // Boost for match at beginning
      if (text.startsWith(query)) {
        score += 50;
      }
    }
    
    // Word boundary matches get priority
    const words = text.split(/\s+/);
    for (const word of words) {
      if (word.startsWith(query)) {
        score += 25;
        break;
      }
    }
    
    // Character distance penalty for fuzzy matches
    let lastMatchIndex = -1;
    for (const char of query) {
      const charIndex = text.indexOf(char, lastMatchIndex + 1);
      if (charIndex === -1) break;
      score += charIndex - lastMatchIndex;
      lastMatchIndex = charIndex;
    }
    
    return -score; // Negative because we want higher scores first
  }

  updateItemsVisibility() {
    this.items.forEach(item => {
      if (this.filteredItems.includes(item)) {
        item.element.style.display = '';
      } else {
        item.element.style.display = 'none';
      }
    });

    // Handle section headers
    this.updateSectionVisibility();

    if (this.filteredItems.length === 0) {
      this.showNoResults();
    } else {
      this.hideNoResults();
    }
  }

  updateSectionVisibility() {
    const sections = this.list.querySelectorAll('.workspace-section');
    sections.forEach(section => {
      const visibleItems = section.querySelectorAll('[data-workspace-switcher-target="item"]:not([style*="display: none"])');
      if (visibleItems.length === 0) {
        section.style.display = 'none';
      } else {
        section.style.display = '';
      }
    });
  }

  showAllItems() {
    this.items.forEach(item => {
      item.element.style.display = '';
    });
    
    const sections = this.list.querySelectorAll('.workspace-section');
    sections.forEach(section => {
      section.style.display = '';
    });
  }

  showNoResults() {
    this.list.style.display = 'none';
    this.noResults?.classList.remove('hidden');
  }

  hideNoResults() {
    this.list.style.display = '';
    this.noResults?.classList.add('hidden');
  }

  clearSearch() {
    if (this.searchInput) {
      this.searchInput.value = '';
      this.search('');
    }
  }

  handleKeydown(e) {
    switch (e.key) {
      case 'ArrowDown':
        e.preventDefault();
        this.highlightNext();
        break;
      case 'ArrowUp':
        e.preventDefault();
        this.highlightPrevious();
        break;
      case 'Enter':
        e.preventDefault();
        this.selectHighlighted();
        break;
      case 'Escape':
        e.preventDefault();
        this.close();
        this.trigger?.focus();
        break;
    }
  }

  handleGlobalKeydown(e) {
    if (!this.isOpen) return;

    switch (e.key) {
      case 'Home':
        e.preventDefault();
        this.highlightFirst();
        break;
      case 'End':
        e.preventDefault();
        this.highlightLast();
        break;
    }
  }

  handleOutsideClick(e) {
    if (this.isOpen && !this.element.contains(e.target)) {
      this.close();
    }
  }

  highlightNext() {
    if (this.filteredItems.length === 0) return;
    
    this.highlightedIndex = (this.highlightedIndex + 1) % this.filteredItems.length;
    this.updateHighlight();
    this.scrollToHighlighted();
  }

  highlightPrevious() {
    if (this.filteredItems.length === 0) return;
    
    this.highlightedIndex = this.highlightedIndex <= 0 
      ? this.filteredItems.length - 1 
      : this.highlightedIndex - 1;
    this.updateHighlight();
    this.scrollToHighlighted();
  }

  highlightFirst() {
    if (this.filteredItems.length === 0) return;
    
    this.highlightedIndex = 0;
    this.updateHighlight();
    this.scrollToHighlighted();
  }

  highlightLast() {
    if (this.filteredItems.length === 0) return;
    
    this.highlightedIndex = this.filteredItems.length - 1;
    this.updateHighlight();
    this.scrollToHighlighted();
  }

  updateHighlight() {
    // Remove existing highlights
    this.items.forEach(item => {
      item.element.classList.remove('highlighted');
      item.element.setAttribute('aria-selected', 'false');
    });

    // Add highlight to current item
    if (this.highlightedIndex >= 0 && this.filteredItems[this.highlightedIndex]) {
      const highlightedItem = this.filteredItems[this.highlightedIndex];
      highlightedItem.element.classList.add('highlighted');
      highlightedItem.element.setAttribute('aria-selected', 'true');
    }
  }

  scrollToHighlighted() {
    if (this.highlightedIndex >= 0 && this.filteredItems[this.highlightedIndex]) {
      const element = this.filteredItems[this.highlightedIndex].element;
      element.scrollIntoView({ block: 'nearest' });
    }
  }

  selectHighlighted() {
    if (this.highlightedIndex >= 0 && this.filteredItems[this.highlightedIndex]) {
      const element = this.filteredItems[this.highlightedIndex].element;
      
      // Simulate click or navigate
      if (element.href) {
        window.location.href = element.href;
      } else {
        element.click();
      }
      
      this.close();
    }
  }
}

// Auto-initialize workspace switchers
document.addEventListener('DOMContentLoaded', () => {
  const switchers = document.querySelectorAll('[data-controller="workspace-switcher"]');
  switchers.forEach(switcher => new WorkspaceSwitcher(switcher));
});

// Re-initialize on turbo:load for SPA-style navigation
document.addEventListener('turbo:load', () => {
  const switchers = document.querySelectorAll('[data-controller="workspace-switcher"]');
  switchers.forEach(switcher => {
    if (!switcher._workspaceSwitcher) {
      switcher._workspaceSwitcher = new WorkspaceSwitcher(switcher);
    }
  });
});