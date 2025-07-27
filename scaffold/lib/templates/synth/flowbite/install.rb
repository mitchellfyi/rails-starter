# frozen_string_literal: true

# Flowbite module installer for the Rails SaaS starter template.
# This module integrates Flowbite UI components library with Tailwind CSS
# for ready-to-use interactive components.

say_status :flowbite, "Installing Flowbite UI components library"

after_bundle do
  # Create necessary directories
  run 'mkdir -p app/javascript/controllers'
  run 'mkdir -p app/assets/stylesheets'
  run 'mkdir -p app/helpers'
  run 'mkdir -p app/views/shared'
  
  # Check if package.json exists, create if not
  unless File.exist?('package.json')
    say_status :flowbite, "Creating package.json..."
    create_file 'package.json', <<~JSON
      {
        "name": "rails-saas-app",
        "private": true,
        "dependencies": {
          "@hotwired/stimulus": "^3.0.0",
          "@hotwired/turbo-rails": "^7.0.0"
        }
      }
    JSON
  end
  
  # Add Flowbite to package.json dependencies
  package_json_path = 'package.json'
  if File.exist?(package_json_path)
    say_status :flowbite, "Adding Flowbite to package.json..."
    
    package_json = JSON.parse(File.read(package_json_path))
    package_json['dependencies'] ||= {}
    package_json['dependencies']['flowbite'] = '^2.2.1'
    
    File.write(package_json_path, JSON.pretty_generate(package_json))
  end
  
  # Install npm dependencies
  if File.exist?('package.json')
    say_status :flowbite, "Installing npm dependencies..."
    run 'npm install'
  end
  
  # Update Tailwind configuration
  tailwind_config_path = 'tailwind.config.js'
  
  # Create or update tailwind.config.js
  if File.exist?(tailwind_config_path)
    say_status :flowbite, "Updating existing Tailwind configuration..."
    
    config_content = File.read(tailwind_config_path)
    
    # Add Flowbite to content paths if not already present
    unless config_content.include?('flowbite')
      config_content = config_content.gsub(
        /content:\s*\[(.*?)\]/m,
        'content: [\\1,
    "./node_modules/flowbite/**/*.js"
  ]'
      )
    end
    
    # Add Flowbite plugin if not already present  
    unless config_content.include?("require('flowbite/plugin')")
      config_content = config_content.gsub(
        /plugins:\s*\[(.*?)\]/m,
        'plugins: [\\1,
    require("flowbite/plugin")
  ]'
      )
    end
    
    File.write(tailwind_config_path, config_content)
  else
    say_status :flowbite, "Creating Tailwind configuration with Flowbite..."
    create_file tailwind_config_path, <<~JS
      const defaultTheme = require('tailwindcss/defaultTheme')

      module.exports = {
        content: [
          './public/*.html',
          './app/helpers/**/*.rb',
          './app/javascript/**/*.js',
          './app/views/**/*',
          './node_modules/flowbite/**/*.js'
        ],
        theme: {
          extend: {
            fontFamily: {
              sans: ['Inter var', ...defaultTheme.fontFamily.sans],
            },
          },
        },
        plugins: [
          require('@tailwindcss/forms'),
          require('@tailwindcss/aspect-ratio'),
          require('@tailwindcss/typography'),
          require('flowbite/plugin')
        ]
      }
    JS
  end
  
  # Create Flowbite initialization file
  create_file 'app/javascript/flowbite_init.js', <<~JS
    // Flowbite initialization for Rails SaaS Starter
    import { initFlowbite } from 'flowbite'

    // Initialize Flowbite components when DOM is loaded
    document.addEventListener('DOMContentLoaded', function() {
      initFlowbite()
    })

    // Re-initialize Flowbite after Turbo navigation
    document.addEventListener('turbo:load', function() {
      initFlowbite()
    })

    // Re-initialize Flowbite after Turbo frame load
    document.addEventListener('turbo:frame-load', function() {
      initFlowbite()
    })

    // Export for manual initialization if needed
    export { initFlowbite }
  JS
  
  # Create custom Flowbite styles
  create_file 'app/assets/stylesheets/flowbite_custom.css', <<~CSS
    /* Flowbite Custom Styles */
    /* Override Flowbite component styles to match your brand */
    
    :root {
      /* Flowbite color customizations */
      --flowbite-primary-50: #eff6ff;
      --flowbite-primary-100: #dbeafe;
      --flowbite-primary-500: #3b82f6;
      --flowbite-primary-600: #2563eb;
      --flowbite-primary-700: #1d4ed8;
      --flowbite-primary-900: #1e3a8a;
    }

    /* Custom button styles */
    .flowbite-btn-primary {
      @apply bg-blue-600 hover:bg-blue-700 text-white font-medium rounded-lg text-sm px-5 py-2.5 transition-colors duration-200;
    }

    .flowbite-btn-secondary {
      @apply bg-gray-600 hover:bg-gray-700 text-white font-medium rounded-lg text-sm px-5 py-2.5 transition-colors duration-200;
    }

    .flowbite-btn-outline {
      @apply border border-gray-300 hover:bg-gray-100 text-gray-700 font-medium rounded-lg text-sm px-5 py-2.5 transition-colors duration-200;
    }

    /* Dark mode button styles */
    .dark .flowbite-btn-outline {
      @apply border-gray-600 hover:bg-gray-700 text-gray-300;
    }

    /* Custom modal styles */
    .flowbite-modal {
      @apply fixed top-0 left-0 right-0 z-50 hidden w-full p-4 overflow-x-hidden overflow-y-auto md:inset-0 h-[calc(100%-1rem)] max-h-full;
    }

    .flowbite-modal-content {
      @apply relative w-full max-w-2xl max-h-full mx-auto;
    }

    .flowbite-modal-body {
      @apply relative bg-white rounded-lg shadow dark:bg-gray-700;
    }

    /* Custom dropdown styles */
    .flowbite-dropdown {
      @apply z-10 hidden bg-white divide-y divide-gray-100 rounded-lg shadow w-44 dark:bg-gray-700;
    }

    .flowbite-dropdown-item {
      @apply block px-4 py-2 text-sm text-gray-700 hover:bg-gray-100 dark:hover:bg-gray-600 dark:text-gray-200 dark:hover:text-white;
    }

    /* Alert components */
    .flowbite-alert {
      @apply flex items-center p-4 mb-4 text-sm rounded-lg;
    }

    .flowbite-alert-info {
      @apply text-blue-800 border border-blue-300 bg-blue-50 dark:bg-gray-800 dark:text-blue-400 dark:border-blue-800;
    }

    .flowbite-alert-success {
      @apply text-green-800 border border-green-300 bg-green-50 dark:bg-gray-800 dark:text-green-400 dark:border-green-800;
    }

    .flowbite-alert-warning {
      @apply text-yellow-800 border border-yellow-300 bg-yellow-50 dark:bg-gray-800 dark:text-yellow-300 dark:border-yellow-800;
    }

    .flowbite-alert-error {
      @apply text-red-800 border border-red-300 bg-red-50 dark:bg-gray-800 dark:text-red-400 dark:border-red-800;
    }
  CSS
  
  # Create Flowbite helper methods
  create_file 'app/helpers/flowbite_helper.rb', <<~RUBY
    # frozen_string_literal: true
    
    # Flowbite UI Components Helper
    # Provides Rails helper methods for commonly used Flowbite components
    module FlowbiteHelper
      
      # Generate a Flowbite button
      # @param text [String] Button text
      # @param options [Hash] Button options
      # @option options [Symbol] :type Button type (:primary, :secondary, :outline)
      # @option options [String] :href Link URL (creates <a> instead of <button>)
      # @option options [Hash] :html Additional HTML attributes
      def flowbite_button(text, options = {})
        type = options[:type] || :primary
        href = options[:href]
        html_options = options[:html] || {}
        
        css_classes = case type
                     when :primary
                       'flowbite-btn-primary'
                     when :secondary
                       'flowbite-btn-secondary'
                     when :outline
                       'flowbite-btn-outline'
                     else
                       'flowbite-btn-primary'
                     end
        
        html_options[:class] = [html_options[:class], css_classes].compact.join(' ')
        
        if href
          link_to text, href, html_options
        else
          content_tag :button, text, html_options.merge(type: 'button')
        end
      end
      
      # Generate a Flowbite modal
      # @param id [String] Modal ID
      # @param options [Hash] Modal options
      # @option options [String] :title Modal title
      # @option options [String] :size Modal size ('sm', 'md', 'lg', 'xl')
      def flowbite_modal(id, options = {}, &block)
        title = options[:title] || 'Modal'
        size = options[:size] || 'md'
        
        size_class = case size
                    when 'sm' then 'max-w-sm'
                    when 'lg' then 'max-w-4xl'
                    when 'xl' then 'max-w-7xl'
                    else 'max-w-2xl'
                    end
        
        content_tag :div, id: id, tabindex: '-1', 'aria-hidden': 'true', 
                    class: 'flowbite-modal' do
          content_tag :div, class: "flowbite-modal-content \#{size_class}" do
            content_tag :div, class: 'flowbite-modal-body' do
              concat(content_tag :div, class: 'flex items-center justify-between p-4 md:p-5 border-b rounded-t dark:border-gray-600' do
                concat(content_tag :h3, title, class: 'text-xl font-semibold text-gray-900 dark:text-white')
                concat(content_tag :button, type: 'button', 
                                  class: 'text-gray-400 bg-transparent hover:bg-gray-200 hover:text-gray-900 rounded-lg text-sm w-8 h-8 ms-auto inline-flex justify-center items-center dark:hover:bg-gray-600 dark:hover:text-white',
                                  'data-modal-hide': id do
                  content_tag :svg, class: 'w-3 h-3', 'aria-hidden': 'true', xmlns: 'http://www.w3.org/2000/svg', fill: 'none', viewBox: '0 0 14 14' do
                    content_tag :path, stroke: 'currentColor', 'stroke-linecap': 'round', 'stroke-linejoin': 'round', 'stroke-width': '2', d: 'm1 1 6 6m0 0 6 6M7 7l6-6M7 7l-6 6'
                  end
                end)
              end)
              concat(content_tag :div, class: 'p-4 md:p-5 space-y-4', &block)
            end
          end
        end
      end
      
      # Generate a Flowbite dropdown
      # @param options [Hash] Dropdown options
      # @option options [String] :trigger Trigger button text
      # @option options [Array] :items Dropdown items
      def flowbite_dropdown(options = {})
        trigger_text = options[:trigger] || 'Dropdown'
        items = options[:items] || []
        dropdown_id = "dropdown-\#{SecureRandom.hex(4)}"
        
        content_tag :div, class: 'relative inline-block text-left' do
          concat(content_tag :button, trigger_text,
                           id: "\#{dropdown_id}-button",
                           'data-dropdown-toggle': dropdown_id,
                           class: 'text-white bg-blue-700 hover:bg-blue-800 focus:ring-4 focus:outline-none focus:ring-blue-300 font-medium rounded-lg text-sm px-5 py-2.5 text-center inline-flex items-center dark:bg-blue-600 dark:hover:bg-blue-700 dark:focus:ring-blue-800',
                           type: 'button')
          
          concat(content_tag :div, id: dropdown_id, class: 'flowbite-dropdown' do
            content_tag :ul, class: 'py-2 text-sm text-gray-700 dark:text-gray-200' do
              items.each do |item|
                concat(content_tag :li do
                  link_to item[:text], item[:link], class: 'flowbite-dropdown-item'
                end)
              end
            end
          end)
        end
      end
      
      # Generate a Flowbite alert
      # @param message [String] Alert message
      # @param type [Symbol] Alert type (:info, :success, :warning, :error)
      def flowbite_alert(message, type = :info)
        type_class = "flowbite-alert-\#{type}"
        
        content_tag :div, class: "flowbite-alert \#{type_class}", role: 'alert' do
          concat(content_tag :svg, class: 'flex-shrink-0 w-4 h-4', 'aria-hidden': 'true', xmlns: 'http://www.w3.org/2000/svg', fill: 'currentColor', viewBox: '0 0 20 20' do
            content_tag :path, d: 'M10 .5a9.5 9.5 0 1 0 9.5 9.5A9.51 9.51 0 0 0 10 .5ZM9.5 4a1.5 1.5 0 1 1 0 3 1.5 1.5 0 0 1 0-3ZM12 15H8a1 1 0 0 1 0-2h1v-3H8a1 1 0 0 1 0-2h2a1 1 0 0 1 1 1v4h1a1 1 0 0 1 0 2Z'
          end)
          concat(content_tag :span, class: 'sr-only', text: type.to_s.capitalize)
          concat(content_tag :div, class: 'ms-3 text-sm font-medium' do
            message
          end)
        end
      end
    end
  RUBY
  
  # Create Stimulus controllers for enhanced Flowbite functionality
  create_file 'app/javascript/controllers/flowbite_modal_controller.js', <<~JS
    import { Controller } from "@hotwired/stimulus"
    import { Modal } from "flowbite"

    // Connects to data-controller="flowbite-modal"
    export default class extends Controller {
      static targets = ["modal"]
      static values = { 
        id: String,
        backdrop: { type: String, default: "dynamic" },
        keyboard: { type: Boolean, default: true }
      }

      connect() {
        this.modal = new Modal(this.modalTarget, {
          backdrop: this.backdropValue,
          keyboard: this.keyboardValue,
          closable: true
        })
      }

      open() {
        this.modal.show()
      }

      close() {
        this.modal.hide()
      }

      toggle() {
        this.modal.toggle()
      }

      disconnect() {
        if (this.modal) {
          this.modal.destroy()
        }
      }
    }
  JS
  
  create_file 'app/javascript/controllers/flowbite_dropdown_controller.js', <<~JS
    import { Controller } from "@hotwired/stimulus"
    import { Dropdown } from "flowbite"

    // Connects to data-controller="flowbite-dropdown"
    export default class extends Controller {
      static targets = ["trigger", "menu"]
      static values = { 
        placement: { type: String, default: "bottom" },
        offsetDistance: { type: Number, default: 10 }
      }

      connect() {
        this.dropdown = new Dropdown(this.menuTarget, this.triggerTarget, {
          placement: this.placementValue,
          triggerType: 'click',
          offsetSkidding: 0,
          offsetDistance: this.offsetDistanceValue,
          delay: 300
        })
      }

      toggle() {
        this.dropdown.toggle()
      }

      show() {
        this.dropdown.show()
      }

      hide() {
        this.dropdown.hide()
      }

      disconnect() {
        if (this.dropdown) {
          this.dropdown.destroy()
        }
      }
    }
  JS

  create_file 'app/javascript/controllers/flowbite_alert_controller.js', <<~JS
    import { Controller } from "@hotwired/stimulus"
    import { Dismiss } from "flowbite"

    // Connects to data-controller="flowbite-alert"
    export default class extends Controller {
      static targets = ["dismissButton"]

      connect() {
        if (this.hasDismissButtonTarget) {
          this.dismiss = new Dismiss(this.element, this.dismissButtonTarget)
        }
      }

      hide() {
        if (this.dismiss) {
          this.dismiss.hide()
        } else {
          this.element.remove()
        }
      }

      disconnect() {
        if (this.dismiss) {
          this.dismiss.destroy()
        }
      }
    }
  JS
  
  # Create example component templates
  create_file 'app/views/shared/_flowbite_button_examples.html.erb', <<~ERB
    <!-- Flowbite Button Examples -->
    <div class="space-y-4">
      <h3 class="text-lg font-semibold">Flowbite Buttons</h3>
      
      <div class="flex space-x-4">
        <%= flowbite_button "Primary Button", type: :primary %>
        <%= flowbite_button "Secondary Button", type: :secondary %>
        <%= flowbite_button "Outline Button", type: :outline %>
      </div>
      
      <div class="flex space-x-4">
        <%= flowbite_button "Link Button", type: :primary, href: "#" %>
        <%= flowbite_button "Disabled Button", type: :primary, html: { disabled: true } %>
      </div>
    </div>
  ERB
  
  create_file 'app/views/shared/_flowbite_modal_example.html.erb', <<~ERB
    <!-- Flowbite Modal Example -->
    <div class="space-y-4">
      <h3 class="text-lg font-semibold">Flowbite Modal</h3>
      
      <!-- Modal trigger -->
      <button data-modal-target="example-modal" data-modal-toggle="example-modal" 
              class="block text-white bg-blue-700 hover:bg-blue-800 focus:ring-4 focus:outline-none focus:ring-blue-300 font-medium rounded-lg text-sm px-5 py-2.5 text-center dark:bg-blue-600 dark:hover:bg-blue-700 dark:focus:ring-blue-800" 
              type="button">
        Toggle modal
      </button>
      
      <!-- Modal -->
      <%= flowbite_modal "example-modal", title: "Example Modal", size: "md" do %>
        <p class="text-base leading-relaxed text-gray-500 dark:text-gray-400">
          This is an example modal using Flowbite components. You can customize the content, size, and behavior.
        </p>
        <p class="text-base leading-relaxed text-gray-500 dark:text-gray-400">
          Modals are great for displaying detailed information, forms, or confirmations without leaving the current page.
        </p>
        
        <!-- Modal footer -->
        <div class="flex items-center p-4 md:p-5 border-t border-gray-200 rounded-b dark:border-gray-600">
          <button data-modal-hide="example-modal" type="button" 
                  class="text-white bg-blue-700 hover:bg-blue-800 focus:ring-4 focus:outline-none focus:ring-blue-300 font-medium rounded-lg text-sm px-5 py-2.5 text-center dark:bg-blue-600 dark:hover:bg-blue-700 dark:focus:ring-blue-800">
            I accept
          </button>
          <button data-modal-hide="example-modal" type="button" 
                  class="py-2.5 px-5 ms-3 text-sm font-medium text-gray-900 focus:outline-none bg-white rounded-lg border border-gray-200 hover:bg-gray-100 hover:text-blue-700 focus:z-10 focus:ring-4 focus:ring-gray-100 dark:focus:ring-gray-700 dark:bg-gray-800 dark:text-gray-400 dark:border-gray-600 dark:hover:text-white dark:hover:bg-gray-700">
            Decline
          </button>
        </div>
      <% end %>
    </div>
  ERB
  
  create_file 'app/views/shared/_flowbite_dropdown_example.html.erb', <<~ERB
    <!-- Flowbite Dropdown Example -->
    <div class="space-y-4">
      <h3 class="text-lg font-semibold">Flowbite Dropdown</h3>
      
      <%= flowbite_dropdown trigger: "Dropdown Menu", items: [
        { text: "Dashboard", link: "#" },
        { text: "Settings", link: "#" },
        { text: "Earnings", link: "#" },
        { text: "Sign out", link: "#" }
      ] %>
    </div>
  ERB
  
  create_file 'app/views/shared/_flowbite_alert_examples.html.erb', <<~ERB
    <!-- Flowbite Alert Examples -->
    <div class="space-y-4">
      <h3 class="text-lg font-semibold">Flowbite Alerts</h3>
      
      <%= flowbite_alert "This is an info alert with some additional information.", :info %>
      <%= flowbite_alert "Success! Your changes have been saved.", :success %>
      <%= flowbite_alert "Warning: Please check your input and try again.", :warning %>
      <%= flowbite_alert "Error: Something went wrong. Please try again later.", :error %>
    </div>
  ERB
  
  # Create a demo page template
  create_file 'app/views/shared/_flowbite_demo.html.erb', <<~ERB
    <!-- Flowbite Components Demo Page -->
    <div class="container mx-auto px-4 py-8 space-y-8">
      <div class="text-center mb-12">
        <h1 class="text-4xl font-bold text-gray-900 dark:text-white mb-4">
          Flowbite Components Demo
        </h1>
        <p class="text-lg text-gray-600 dark:text-gray-300">
          Interactive examples of Flowbite UI components integrated with Rails
        </p>
      </div>
      
      <!-- Include component examples -->
      <div class="grid grid-cols-1 md:grid-cols-2 gap-8">
        <div class="bg-white dark:bg-gray-800 p-6 rounded-lg shadow">
          <%= render 'shared/flowbite_button_examples' %>
        </div>
        
        <div class="bg-white dark:bg-gray-800 p-6 rounded-lg shadow">
          <%= render 'shared/flowbite_alert_examples' %>
        </div>
        
        <div class="bg-white dark:bg-gray-800 p-6 rounded-lg shadow">
          <%= render 'shared/flowbite_modal_example' %>
        </div>
        
        <div class="bg-white dark:bg-gray-800 p-6 rounded-lg shadow">
          <%= render 'shared/flowbite_dropdown_example' %>
        </div>
      </div>
    </div>
  ERB
  
  # Update the main application.js file to import Flowbite
  application_js_path = 'app/javascript/application.js'
  
  if File.exist?(application_js_path)
    append_to_file application_js_path, "\n// Flowbite initialization\nimport './flowbite_init'\n"
  else
    create_file application_js_path, <<~JS
      // Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
      import "@hotwired/turbo-rails"
      import "controllers"

      // Flowbite initialization
      import './flowbite_init'
    JS
  end
  
  # Update application CSS to include Flowbite styles
  application_css_path = 'app/assets/stylesheets/application.css'
  tailwind_css_path = 'app/assets/stylesheets/application.tailwind.css'
  
  css_file_to_modify = if File.exist?(tailwind_css_path)
    tailwind_css_path
  elsif File.exist?(application_css_path)
    application_css_path
  else
    create_file application_css_path, <<~CSS
      /*
       * This is a manifest file that'll be compiled into application.css, which will include all the files
       * listed below.
       *
       *= require_tree .
       *= require_self
       */
    CSS
    application_css_path
  end
  
  # Add Flowbite styles import
  if File.exist?(css_file_to_modify)
    unless File.read(css_file_to_modify).include?('flowbite_custom')
      append_to_file css_file_to_modify, "\n/* Flowbite Custom Styles */\n@import \"flowbite_custom\";\n"
    end
  end
  
  say_status :flowbite, "✅ Flowbite integration installed successfully!"
  say_status :flowbite, "📦 Flowbite npm package added to package.json"
  say_status :flowbite, "⚙️  Tailwind configuration updated with Flowbite plugin"
  say_status :flowbite, "🎨 Custom Flowbite styles created in app/assets/stylesheets/flowbite_custom.css"
  say_status :flowbite, "🚀 Flowbite helpers available in FlowbiteHelper module"
  say_status :flowbite, "📝 Example components available in app/views/shared/"
  say_status :flowbite, ""
  say_status :flowbite, "Next steps:"
  say_status :flowbite, "1. Run: npm install (if not already done)"
  say_status :flowbite, "2. Add <%= render 'shared/flowbite_demo' %> to a view to see examples"
  say_status :flowbite, "3. Customize styles in app/assets/stylesheets/flowbite_custom.css"
  say_status :flowbite, "4. Use Flowbite helpers in your views: <%= flowbite_button 'Click me' %>"
end