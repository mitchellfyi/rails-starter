# frozen_string_literal: true

require_relative 'base_command'
require 'securerandom'

module RailsPlan
  module Commands
    # Interactive bootstrap command for setting up new Rails SaaS applications
    class BootstrapCommand < BaseCommand
      def execute(options = {})
        puts "🚀 Welcome to Rails SaaS Starter Bootstrap Wizard!"
        puts "=" * 60
        puts ""
        puts "This wizard will help you set up your Rails SaaS application."
        puts "Choose your setup type:"
        puts ""
        puts "  1. 🎯 Quick Demo Setup - Get up and running fast with demo data"
        puts "  2. 🏗️  New Application Setup - Full guided setup for production use"
        puts "  3. 🔧 Custom Module Selection - Choose specific modules to install"
        puts ""
        
        setup_type = prompt_for_choice("Setup type", ["demo", "new-app", "custom"], "demo")
        
        case setup_type
        when "demo"
          setup_demo_mode
        when "new-app"
          setup_new_application
        when "custom"
          setup_custom_modules
        end
        
        puts ""
        puts "🎉 Bootstrap complete! Your Rails SaaS application is ready."
        display_next_steps(setup_type)
      end

      private

      def setup_demo_mode
        puts ""
        puts "🎯 Quick Demo Setup"
        puts "-" * 30
        puts "Setting up with sensible defaults and demo data..."
        
        # Install core modules for demo
        demo_modules = ['auth', 'billing', 'ai', 'admin']
        
        demo_modules.each do |module_name|
          if module_available?(module_name)
            puts "  📦 Installing #{module_name}..."
            install_module_quick(module_name)
          end
        end
        
        # Generate demo environment
        generate_demo_env
        puts "✅ Demo setup complete!"
      end

      def setup_new_application
        puts ""
        puts "🏗️  New Application Setup"
        puts "-" * 30
        
        # Collect configuration through interactive prompts
        config = collect_application_config
        
        # Generate and configure the application
        setup_application_with_config(config)
        
        puts "✅ New application setup complete!"
      end

      def setup_custom_modules
        puts ""
        puts "🔧 Custom Module Selection"
        puts "-" * 30
        
        available_modules = get_available_modules
        
        if available_modules.empty?
          puts "❌ No modules available for installation"
          return
        end
        
        selected_modules = select_modules_interactively(available_modules)
        
        if selected_modules.empty?
          puts "No modules selected. Exiting."
          return
        end
        
        puts ""
        puts "Installing selected modules..."
        selected_modules.each do |module_name|
          puts "  📦 Installing #{module_name}..."
          install_module_quick(module_name)
        end
        
        puts "✅ Custom module setup complete!"
      end

      def collect_application_config
        config = {}
        
        puts "🔧 Application Configuration"
        puts "-" * 30
        config[:app_name] = prompt_for_input("Application name", "Rails SaaS Starter")
        config[:app_domain] = prompt_for_input("Domain (e.g., myapp.com)", "localhost:3000")
        config[:environment] = prompt_for_choice("Environment", %w[development staging production], "development")
        
        puts ""
        puts "👥 Team Configuration"
        puts "-" * 20
        config[:team_name] = prompt_for_input("Team/Organization name", "My Team")
        config[:owner_email] = prompt_for_input("Owner email address", "admin@#{config[:app_domain]}")
        config[:admin_password] = generate_secure_password
        puts "   Generated admin password: #{config[:admin_password]}"
        
        puts ""
        puts "📦 Module Selection"
        puts "-" * 18
        config[:modules] = select_modules_interactively(get_available_modules)
        
        config
      end

      def prompt_for_input(prompt, default = nil)
        print "#{prompt}"
        print " [#{default}]" if default
        print ": "
        
        input = STDIN.gets.chomp
        input.empty? && default ? default : input
      end

      def prompt_for_choice(prompt, choices, default = nil)
        puts "#{prompt}:"
        choices.each_with_index do |choice, index|
          marker = choice == default ? " (default)" : ""
          puts "  #{index + 1}. #{choice}#{marker}"
        end
        
        print "Select (1-#{choices.length}): "
        choice_index = STDIN.gets.chomp.to_i
        
        if choice_index.between?(1, choices.length)
          choices[choice_index - 1]
        elsif default
          default
        else
          prompt_for_choice(prompt, choices, default)
        end
      end

      def select_modules_interactively(available_modules)
        return [] if available_modules.empty?
        
        puts "Available modules:"
        available_modules.each_with_index do |mod, index|
          puts "  #{index + 1}. #{mod[:name].ljust(15)} - #{mod[:description]}"
        end
        
        puts "  #{available_modules.length + 1}. Install all modules"
        puts "  #{available_modules.length + 2}. Skip module installation"
        
        print "Select modules (comma-separated numbers): "
        selection = STDIN.gets.chomp
        
        return [] if selection.empty?
        
        selected_indices = selection.split(',').map(&:strip).map(&:to_i)
        
        if selected_indices.include?(available_modules.length + 1)
          # Install all modules
          available_modules.map { |mod| mod[:name] }
        elsif selected_indices.include?(available_modules.length + 2)
          # Skip installation
          []
        else
          # Install selected modules
          selected_indices.filter_map do |index|
            available_modules[index - 1]&.dig(:name) if index.between?(1, available_modules.length)
          end
        end
      end

      def module_available?(module_name)
        module_path = File.join(TEMPLATE_PATH, module_name)
        Dir.exist?(module_path)
      end

      def install_module_quick(module_name)
        return false unless module_available?(module_name)
        
        add_command = Synth::Commands::AddCommand.new(verbose: false)
        add_command.execute(module_name, force: true)
      end

      def generate_demo_env
        env_content = <<~ENV
          # Demo Rails SaaS Configuration
          RAILS_ENV=development
          SECRET_KEY_BASE=#{SecureRandom.hex(64)}
          
          # Application Configuration
          APP_NAME=Rails SaaS Demo
          APP_HOST=localhost:3000
          
          # Database Configuration
          DATABASE_URL=sqlite3:db/development.sqlite3
          
          # Admin Configuration
          ADMIN_EMAIL=admin@demo.com
          ADMIN_PASSWORD=demo123456
          TEAM_NAME=Demo Team
          
          # Demo API Keys (replace with real keys for production)
          OPENAI_API_KEY=sk-demo-key-replace-with-real
          STRIPE_PUBLISHABLE_KEY=pk_test_demo
          STRIPE_SECRET_KEY=sk_test_demo
        ENV
        
        File.write('.env', env_content)
        log_verbose "✅ Generated demo .env file"
      end

      def setup_application_with_config(config)
        # Generate .env file
        generate_env_file(config)
        
        # Install selected modules
        install_selected_modules(config[:modules])
        
        # Generate seed data
        generate_seed_data(config)
      end

      def generate_env_file(config)
        log_verbose "📝 Generating .env file..."
        
        env_content = <<~ENV
          # Rails SaaS Configuration
          RAILS_ENV=#{config[:environment]}
          SECRET_KEY_BASE=#{SecureRandom.hex(64)}
          
          # Application Configuration
          APP_NAME=#{config[:app_name]}
          APP_HOST=#{config[:app_domain]}
          
          # Database Configuration
          DATABASE_URL=sqlite3:db/#{config[:environment]}.sqlite3
          
          # Admin Configuration
          ADMIN_EMAIL=#{config[:owner_email]}
          ADMIN_PASSWORD=#{config[:admin_password]}
          TEAM_NAME=#{config[:team_name]}
          
          # API Keys (add your keys here)
          # OPENAI_API_KEY=your-openai-key
          # STRIPE_PUBLISHABLE_KEY=pk_test_your-stripe-key
          # STRIPE_SECRET_KEY=sk_test_your-stripe-key
        ENV
        
        File.write('.env', env_content)
        log_verbose "✅ .env file created"
      end

      def install_selected_modules(modules)
        return if modules.empty?
        
        log_verbose "📦 Installing selected modules..."
        modules.each do |module_name|
          log_verbose "  Installing #{module_name}..."
          install_module_quick(module_name)
        end
      end

      def generate_seed_data(config)
        log_verbose "🌱 Generating seed data..."
        
        seed_content = <<~SEEDS
          # Bootstrap generated seeds
          # Created by Rails SaaS Starter Bootstrap Wizard
          
          # Create admin user
          admin_user = User.find_or_create_by(email: '#{config[:owner_email]}') do |user|
            user.password = '#{config[:admin_password]}'
            user.password_confirmation = '#{config[:admin_password]}'
            user.confirmed_at = Time.now
            user.admin = true
          end
          
          puts "Created admin user: \#{admin_user.email}" if admin_user.persisted?
          
          # Create default team
          if defined?(Team)
            team = Team.find_or_create_by(name: '#{config[:team_name]}') do |t|
              t.owner = admin_user
            end
            
            puts "Created team: \#{team.name}" if team.persisted?
          end
          
          puts "Bootstrap seeds completed!"
        SEEDS
        
        seeds_file = 'db/seeds.rb'
        if File.exist?(seeds_file)
          existing_content = File.read(seeds_file)
          unless existing_content.include?('# Bootstrap generated seeds')
            File.write(seeds_file, "#{existing_content}\n#{seed_content}")
          end
        else
          File.write(seeds_file, seed_content)
        end
        
        log_verbose "✅ Seed data generated"
      end

      def generate_secure_password
        SecureRandom.alphanumeric(16)
      end

      def display_next_steps(setup_type)
        puts "📋 Next steps:"
        
        case setup_type
        when "demo"
          puts "   1. Run: rails db:create db:migrate db:seed"
          puts "   2. Start your application: rails server"
          puts "   3. Visit: http://localhost:3000"
          puts "   4. Login with: admin@demo.com / demo123456"
          puts "   5. Explore the admin panel: http://localhost:3000/admin"
        when "new-app"
          puts "   1. Review the generated .env file and add any missing API keys"
          puts "   2. Run: rails db:create db:migrate db:seed"
          puts "   3. Start your application: rails server"
          puts "   4. Visit: http://localhost:3000"
          puts "   5. Configure your deployed environment"
        when "custom"
          puts "   1. Review module documentation in docs/modules/"
          puts "   2. Configure modules in config/initializers/"
          puts "   3. Run: rails db:migrate"
          puts "   4. Start your application: rails server"
        end
        
        puts ""
        puts "📚 For more information:"
        puts "   - Documentation: docs/README.md"
        puts "   - Module docs: docs/modules/"
        puts "   - CLI help: bin/synth help"
      end
    end
  end
end