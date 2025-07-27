# Example: Future UI-based Module Management

This file demonstrates how the railsplan.json manifest enables a future web-based module management interface.

## UI Data Structure

The `bin/railsplan manifest ui-data` command outputs structured data that can be consumed by a web interface:

```ruby
# Example controller for module management interface
class Admin::ModulesController < ApplicationController
  before_action :ensure_admin
  
  def index
    @modules_data = RailsPlanManifest.new.ui_modules_data
    @categories = @modules_data.group_by { |mod| mod[:category] }
  end
  
  def toggle
    module_name = params[:id]
    if params[:enable] == 'true'
      system("bin/railsplan add #{module_name}")
    else
      system("bin/railsplan remove #{module_name}")
    end
    
    redirect_to admin_modules_path, notice: "Module #{module_name} updated"
  end
end
```

## UI Template Example

```erb
<!-- app/views/admin/modules/index.html.erb -->
<div class="modules-management">
  <h1>Module Management</h1>
  
  <% @categories.each do |category, modules| %>
    <div class="category-section">
      <h2><%= category.upcase %> MODULES</h2>
      
      <div class="modules-grid">
        <% modules.each do |mod| %>
          <div class="module-card <%= mod[:status] %> <%= mod[:health_status] %>">
            <div class="module-header">
              <i class="icon-<%= mod[:icon] %>" style="color: <%= mod[:color] %>"></i>
              <h3><%= mod[:display_name] %></h3>
              
              <% if mod[:toggleable] %>
                <%= form_with url: admin_module_path(mod[:name]), method: :patch, local: true do |f| %>
                  <%= f.hidden_field :enable, value: mod[:status] != 'installed' %>
                  <%= f.submit mod[:status] == 'installed' ? 'Disable' : 'Enable', 
                      class: "btn #{mod[:status] == 'installed' ? 'btn-danger' : 'btn-success'}" %>
                <% end %>
              <% else %>
                <span class="badge required">Required</span>
              <% end %>
            </div>
            
            <div class="module-details">
              <p><%= mod[:description] %></p>
              <div class="module-meta">
                <span class="version">v<%= mod[:version] %></span>
                <span class="health <%= mod[:health_status] %>">
                  <%= mod[:health_status] == 'healthy' ? '✅' : '❌' %>
                  <%= mod[:health_status] %>
                </span>
                <% if mod[:admin_only] %>
                  <span class="badge admin">Admin Only</span>
                <% end %>
              </div>
            </div>
          </div>
        <% end %>
      </div>
    </div>
  <% end %>
</div>
```

## JavaScript Integration

```javascript
// Enhanced module management with AJAX
class ModuleManager {
  constructor() {
    this.bindEvents();
  }
  
  bindEvents() {
    document.querySelectorAll('.module-toggle').forEach(btn => {
      btn.addEventListener('click', this.toggleModule.bind(this));
    });
  }
  
  async toggleModule(event) {
    event.preventDefault();
    
    const btn = event.target;
    const moduleCard = btn.closest('.module-card');
    const moduleName = moduleCard.dataset.module;
    const enable = btn.dataset.enable === 'true';
    
    // Show loading state
    btn.disabled = true;
    btn.textContent = enable ? 'Installing...' : 'Removing...';
    
    try {
      const response = await fetch(`/admin/modules/${moduleName}`, {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': this.getCSRFToken()
        },
        body: JSON.stringify({ enable: enable })
      });
      
      if (response.ok) {
        // Refresh the module status
        this.refreshModuleStatus(moduleName);
      } else {
        throw new Error('Failed to toggle module');
      }
    } catch (error) {
      alert(`Error: ${error.message}`);
      btn.disabled = false;
      btn.textContent = enable ? 'Enable' : 'Disable';
    }
  }
  
  async refreshModuleStatus(moduleName) {
    // Fetch updated module data and update UI
    const response = await fetch(`/admin/modules/${moduleName}/status`);
    const moduleData = await response.json();
    
    // Update the module card with new status
    this.updateModuleCard(moduleName, moduleData);
  }
}

// Initialize on page load
document.addEventListener('DOMContentLoaded', () => {
  new ModuleManager();
});
```

## API Endpoints for Module Management

```ruby
# config/routes.rb
namespace :admin do
  resources :modules, only: [:index, :show, :update] do
    member do
      get :status
      post :install
      delete :remove
      get :health_check
    end
  end
end

# app/controllers/admin/modules_controller.rb
class Admin::ModulesController < ApplicationController
  def status
    manifest_manager = RailsPlanManifest.new
    module_info = manifest_manager.module_info(params[:id])
    
    render json: {
      name: params[:id],
      status: module_info[:status],
      health: manifest_manager.module_healthy?(params[:id]) ? 'healthy' : 'unhealthy',
      version: module_info[:version]
    }
  end
  
  def install
    system("bin/railsplan add #{params[:id]}")
    render json: { success: true, message: "Module #{params[:id]} installed" }
  rescue => e
    render json: { success: false, error: e.message }, status: 422
  end
  
  def remove
    system("bin/railsplan remove #{params[:id]} --force")
    render json: { success: true, message: "Module #{params[:id]} removed" }
  rescue => e
    render json: { success: false, error: e.message }, status: 422
  end
  
  def health_check
    manifest_manager = RailsPlanManifest.new
    health_status = manifest_manager.module_healthy?(params[:id])
    
    render json: {
      healthy: health_status,
      checks: {
        config_files: true, # Could be more specific checks
        dependencies: true,
        migrations: true
      }
    }
  end
end
```

## Benefits of the Manifest System

1. **Rich UI Data**: Icons, colors, categories, and descriptions for polished interfaces
2. **Real-time Status**: Health checks and dependency validation
3. **Safe Operations**: Dependency tracking prevents breaking installations
4. **Audit Trail**: Complete tracking of module lifecycle and changes
5. **Progressive Enhancement**: CLI works independently, UI adds convenience
6. **Extensible**: Manifest schema can grow with new requirements

This manifest system provides a solid foundation for sophisticated module management tools while maintaining the simplicity and reliability of the CLI interface.