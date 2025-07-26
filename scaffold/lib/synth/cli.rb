#!/usr/bin/env ruby
# frozen_string_literal: true

require 'thor'
require 'fileutils'
require 'logger'
require 'time'

module Synth
  class CLI < Thor
    include Thor::Actions
    
    def self.exit_on_failure?
      true
    end
    
    def self.source_root
      File.expand_path('../templates', __dir__)
    end

    desc 'new', 'Setup scaffolding for new application'
    option :verbose, type: :boolean, aliases: ['-v'], desc: 'Enable verbose output'
    def new
      log_operation('new', description: 'Setting up scaffolding for new application')
      
      # Ensure basic directory structure exists
      %w[app/models app/controllers app/views lib/templates/synth config log].each do |dir|
        empty_directory(dir)
      end

      # Create basic configuration files
      create_file 'config/synth_modules.json', JSON.pretty_generate({
        installed: {},
        version: '1.0.0'
      })

      # Create .env.example if it doesn't exist
      unless File.exist?('.env.example')
        create_file '.env.example', <<~ENV
          # Rails
          SECRET_KEY_BASE=

          # Database
          DATABASE_URL=

          # Redis
          REDIS_URL=

          # AI Providers
          OPENAI_API_KEY=
          ANTHROPIC_API_KEY=
          
          # Stripe
          STRIPE_PUBLISHABLE_KEY=
          STRIPE_SECRET_KEY=
          STRIPE_WEBHOOK_SECRET=
        ENV
      end

      log_operation('new_complete', description: 'Application scaffolding setup complete')
      puts "✅ New application scaffolding complete. Run 'bin/synth list' to see available modules."
    end

    desc 'add MODULE', 'Add a feature module to your app'
    option :verbose, type: :boolean, aliases: ['-v'], desc: 'Enable verbose output'
    def add(feature)
      log_operation('add_start', module: feature, description: "Adding module #{feature}")
      
      module_path = File.join(modules_path, feature)
      install_script = File.join(module_path, 'install.rb')
      
      unless Dir.exist?(module_path)
        error_msg = "Module '#{feature}' not found in templates"
        log_operation('add_error', module: feature, error: error_msg)
        puts "❌ #{error_msg}"
        available_modules = Dir.exist?(modules_path) ? Dir.children(modules_path) : []
        puts "Available modules: #{available_modules.join(', ')}" if available_modules.any?
        exit(1)
      end

      # Check if module is already installed
      installed_modules = load_installed_modules
      if installed_modules.dig('installed', feature)
        puts "⚠️  Module '#{feature}' is already installed"
        return
      end

      # Execute the install script if it exists
      if File.exist?(install_script)
        puts "📦 Installing module: #{feature}"
        log_operation('install_script_run', module: feature, script: install_script)
        
        # Load and execute the install script in the context of this CLI
        load install_script
      end

      # Copy module files if they exist
      %w[migrations seeds].each do |subdir|
        source_dir = File.join(module_path, subdir)
        if Dir.exist?(source_dir)
          target_dir = File.join(Dir.pwd, subdir == 'migrations' ? 'db/migrate' : 'db/seeds')
          FileUtils.mkdir_p(target_dir)
          
          Dir.glob(File.join(source_dir, '*')).each do |file|
            if File.file?(file)
              target_file = File.join(target_dir, File.basename(file))
              FileUtils.cp(file, target_file)
              log_operation('file_copy', source: file, target: target_file)
            end
          end
        end
      end

      # Update installed modules tracking
      installed_modules['installed'] ||= {}
      installed_modules['installed'][feature] = {
        version: '1.0.0',
        installed_at: Time.now.iso8601
      }
      save_installed_modules(installed_modules)
      
      log_operation('add_complete', module: feature, description: "Module #{feature} installed successfully")
      puts "✅ Module '#{feature}' installed successfully"
    end

    desc 'remove MODULE', 'Remove a feature module from your app'
    option :verbose, type: :boolean, aliases: ['-v'], desc: 'Enable verbose output'
    def remove(feature)
      log_operation('remove_start', module: feature, description: "Removing module #{feature}")
      
      installed_modules = load_installed_modules
      
      unless installed_modules.dig('installed', feature)
        puts "⚠️  Module '#{feature}' is not installed"
        return
      end

      module_path = File.join(modules_path, feature)
      removal_script = File.join(module_path, 'remove.rb')
      
      # Execute removal script if it exists
      if File.exist?(removal_script)
        puts "🗑️  Removing module: #{feature}"
        log_operation('removal_script_run', module: feature, script: removal_script)
        load removal_script
      else
        puts "⚠️  No removal script found for '#{feature}'. Manual cleanup may be required."
      end

      # Remove from installed modules tracking
      installed_modules['installed'].delete(feature)
      save_installed_modules(installed_modules)
      
      log_operation('remove_complete', module: feature, description: "Module #{feature} removed successfully")
      puts "✅ Module '#{feature}' removed successfully"
    end

    desc 'list', 'List installed modules and versions'
    option :verbose, type: :boolean, aliases: ['-v'], desc: 'Enable verbose output'
    def list
      log_operation('list', description: 'Listing installed modules')
      
      installed_modules = load_installed_modules
      available_modules = Dir.exist?(modules_path) ? Dir.children(modules_path) : []
      
      puts "\n📦 Installed modules:"
      if installed_modules.dig('installed')&.any?
        installed_modules['installed'].each do |name, info|
          status = available_modules.include?(name) ? '✅' : '⚠️ (template missing)'
          puts "  #{status} #{name} (v#{info['version']}) - installed #{info['installed_at']}"
        end
      else
        puts "  (none)"
      end
      
      puts "\n🛠️  Available modules:"
      available_modules.each do |module_name|
        next if installed_modules.dig('installed', module_name)
        
        readme_path = File.join(modules_path, module_name, 'README.md')
        description = ''
        if File.exist?(readme_path)
          # Extract first line as description
          description = File.readlines(readme_path).find { |line| line.strip != '' && !line.start_with?('#') }
          description = " - #{description.strip}" if description
        end
        puts "  📄 #{module_name}#{description}"
      end
    end

    desc 'upgrade', 'Upgrade installed modules'
    option :verbose, type: :boolean, aliases: ['-v'], desc: 'Enable verbose output'
    def upgrade
      log_operation('upgrade_start', description: 'Starting module upgrades')
      
      installed_modules = load_installed_modules
      
      unless installed_modules.dig('installed')&.any?
        puts "No modules are currently installed"
        return
      end

      upgraded_count = 0
      installed_modules['installed'].each do |name, info|
        module_path = File.join(modules_path, name)
        upgrade_script = File.join(module_path, 'upgrade.rb')
        
        if File.exist?(upgrade_script)
          puts "⬆️  Upgrading module: #{name}"
          log_operation('upgrade_module', module: name, from_version: info['version'])
          load upgrade_script
          
          # Update version (in a real implementation, this would read from module metadata)
          info['upgraded_at'] = Time.now.iso8601
          upgraded_count += 1
        end
      end

      save_installed_modules(installed_modules)
      log_operation('upgrade_complete', upgraded_count: upgraded_count)
      puts "✅ Upgrade complete. #{upgraded_count} modules processed."
    end

    desc 'test [MODULE]', 'Run tests; if MODULE specified, run tests only for that module'
    option :verbose, type: :boolean, aliases: ['-v'], desc: 'Enable verbose output'
    def test(feature = nil)
      if feature == 'ai'
        log_operation('test_ai', description: 'Running AI tests')
        puts "🧠 Running AI tests..."
        
        # Check for AI module installation
        installed_modules = load_installed_modules
        unless installed_modules.dig('installed', 'ai')
          puts "⚠️  AI module is not installed. Run 'bin/synth add ai' first."
          return
        end

        # Run AI-specific tests
        test_commands = [
          'bundle exec rspec spec/models/prompt_template_spec.rb',
          'bundle exec rspec spec/jobs/llm_job_spec.rb',
          'bundle exec rspec spec/services/mcp_service_spec.rb'
        ]

        test_commands.each do |cmd|
          puts "Running: #{cmd}"
          unless system(cmd)
            puts "❌ Command failed: #{cmd}"
            log_operation('test_ai_error', description: "Command failed: #{cmd}")
            return
          end
        end
        
        log_operation('test_ai_complete', description: 'AI tests completed')
        puts "✅ AI tests completed"
      elsif feature.nil?
        log_operation('test_all', description: 'Running full test suite')
        puts "🧪 Running full test suite..."
        if system('bundle exec rspec')
          puts "✅ RSpec tests completed successfully."
        else
          puts "⚠️  RSpec tests failed. Attempting to run Rails tests..."
          system('bin/rails test')
        end
        log_operation('test_all_complete', description: 'Full test suite completed')
      else
        log_operation('test_module', module: feature, description: "Running tests for #{feature}")
        puts "🧪 Running tests for #{feature}..."
        
        # Run module-specific tests
        test_file = "spec/modules/#{feature}_spec.rb"
        if File.exist?(test_file)
          system("bundle exec rspec #{test_file}")
        else
          puts "⚠️  No tests found for module '#{feature}'"
        end
        
        log_operation('test_module_complete', module: feature)
      end
    end

    desc 'doctor', 'Validate setup, keys, and MCP fetchers'
    option :verbose, type: :boolean, aliases: ['-v'], desc: 'Enable verbose output'
    def doctor
      log_operation('doctor_start', description: 'Starting system validation')
      puts "🩺 Running synth doctor..."
      
      issues = []
      
      # Check basic directory structure
      required_dirs = %w[app/models app/controllers config lib]
      required_dirs.each do |dir|
        unless Dir.exist?(dir)
          issues << "Missing directory: #{dir}"
        end
      end
      
      # Check for environment file
      unless File.exist?('.env') || File.exist?('.env.local')
        issues << "No .env or .env.local file found"
      end
      
      # Check installed modules
      installed_modules = load_installed_modules
      if installed_modules.dig('installed')&.any?
        installed_modules['installed'].each do |name, _info|
          module_path = File.join(modules_path, name)
          unless Dir.exist?(module_path)
            issues << "Module '#{name}' is installed but template is missing"
          end
        end
      end
      
      # Check AI module if installed
      if installed_modules.dig('installed', 'ai')
        puts "  🧠 Checking AI module..."
        
        # Check for API keys
        %w[OPENAI_API_KEY ANTHROPIC_API_KEY].each do |key|
          unless ENV[key] || (File.exist?('.env') && File.read('.env').include?(key))
            issues << "Missing environment variable: #{key}"
          end
        end
        
        # Check for MCP configuration
        mcp_config = File.join('config', 'mcp.yml')
        unless File.exist?(mcp_config)
          issues << "MCP configuration file missing: #{mcp_config}"
        end
      end
      
      # Check billing module if installed
      if installed_modules.dig('installed', 'billing')
        puts "  💳 Checking billing module..."
        
        %w[STRIPE_PUBLISHABLE_KEY STRIPE_SECRET_KEY].each do |key|
          unless ENV[key] || (File.exist?('.env') && File.read('.env').include?(key))
            issues << "Missing environment variable: #{key}"
          end
        end
      end
      
      # Report results
      if issues.empty?
        log_operation('doctor_success', description: 'All checks passed')
        puts "✅ All checks passed! Your setup looks good."
      else
        log_operation('doctor_issues', issues: issues, count: issues.length)
        puts "❌ Found #{issues.length} issue(s):"
        issues.each { |issue| puts "  - #{issue}" }
        puts "\nRun 'bin/synth new' to fix basic setup issues."
      end
    end

    desc 'scaffold agent NAME', 'Scaffold a new AI agent'
    option :verbose, type: :boolean, aliases: ['-v'], desc: 'Enable verbose output'
    def scaffold(type, name = nil)
      if type == 'agent'
        if name.nil?
          puts "❌ Agent name is required. Usage: bin/synth scaffold agent <name>"
          exit(1)
        end
        
        log_operation('scaffold_agent', name: name, description: "Scaffolding agent #{name}")
        puts "🤖 Scaffolding agent: #{name}"
        
        # Check if AI module is installed
        installed_modules = load_installed_modules
        unless installed_modules.dig('installed', 'ai')
          puts "⚠️  AI module is not installed. Run 'bin/synth add ai' first."
          return
        end

        # Create agent directory structure
        agent_dir = "app/agents/#{name.downcase}"
        empty_directory(agent_dir)
        
        # Create agent class
        create_file "#{agent_dir}/#{name.downcase}_agent.rb", <<~RUBY
          # frozen_string_literal: true

          class #{camelize(name)}Agent
            include AgentConcerns::Base
            
            def initialize(context = {})
              @context = context
            end
            
            def process(input)
              # TODO: Implement agent logic
              prompt_template = PromptTemplate.find_by(name: '#{name.downcase}_prompt')
              
              if prompt_template
                LLMJob.perform_later(
                  template: prompt_template,
                  context: @context.merge(input: input),
                  model: 'gpt-4'
                )
              else
                raise "Prompt template '#{name.downcase}_prompt' not found"
              end
            end
            
            private
            
            attr_reader :context
          end
        RUBY
        
        # Create controller
        create_file "app/controllers/#{name.downcase}_agents_controller.rb", <<~RUBY
          # frozen_string_literal: true

          class #{camelize(name)}AgentsController < ApplicationController
            before_action :authenticate_user!
            
            def create
              agent = #{camelize(name)}Agent.new(current_user: current_user)
              result = agent.process(agent_params[:input])
              
              render json: { job_id: result.job_id }, status: :accepted
            rescue => e
              render json: { error: e.message }, status: :unprocessable_entity
            end
            
            private
            
            def agent_params
              params.require(:agent).permit(:input)
            end
          end
        RUBY
        
        # Create spec file
        spec_dir = "spec/agents"
        empty_directory(spec_dir)
        create_file "#{spec_dir}/#{name.downcase}_agent_spec.rb", <<~RUBY
          # frozen_string_literal: true

          require 'rails_helper'

          RSpec.describe #{camelize(name)}Agent do
            let(:agent) { described_class.new }
            
            describe '#process' do
              it 'processes input and returns job' do
                # TODO: Add test implementation
                pending 'Add test implementation'
              end
            end
          end
        RUBY
        
        # Add route
        route_line = "  resources :#{name.downcase}_agents, only: [:create]"
        routes_file = 'config/routes.rb'
        if File.exist?(routes_file)
          routes_content = File.read(routes_file)
          unless routes_content.include?(route_line.strip)
            # Insert before the end of the Rails.application.routes.draw block
            new_content = routes_content.sub(/end\s*\z/, "#{route_line}\nend")
            File.write(routes_file, new_content)
            log_operation('route_added', route: route_line.strip)
          end
        end
        
        log_operation('scaffold_agent_complete', name: name, files_created: 4)
        puts "✅ Agent '#{name}' scaffolded successfully"
        puts "   Created:"
        puts "   - app/agents/#{name.downcase}/#{name.downcase}_agent.rb"
        puts "   - app/controllers/#{name.downcase}_agents_controller.rb" 
        puts "   - spec/agents/#{name.downcase}_agent_spec.rb"
        puts "   - Added route to config/routes.rb"
      else
        puts "❌ Unknown scaffold type: #{type}. Supported types: agent"
        exit(1)
      end
    end

    private

    def logger
      @logger ||= begin
        log_dir = File.join(Dir.pwd, 'log')
        FileUtils.mkdir_p(log_dir)
        log_file = File.join(log_dir, 'synth.log')
        Logger.new(log_file, 'daily').tap do |log|
          log.level = Logger::INFO
          log.formatter = proc do |severity, datetime, progname, msg|
            "#{datetime.strftime('%Y-%m-%d %H:%M:%S')} [#{severity}] #{msg}\n"
          end
        end
      end
    end

    def log_operation(operation, details = {})
      timestamp = Time.now.iso8601
      entry = {
        timestamp: timestamp,
        operation: operation,
        details: details
      }
      logger.info(entry.to_json)
      puts "#{operation}: #{details[:description] || details.inspect}" if options[:verbose]
    end

    def modules_path
      File.expand_path('../templates/synth', __dir__)
    end

    def installed_modules_file
      File.join(Dir.pwd, 'config', 'synth_modules.json')
    end

    def load_installed_modules
      return {} unless File.exist?(installed_modules_file)
      JSON.parse(File.read(installed_modules_file))
    rescue JSON::ParserError
      {}
    end

    def save_installed_modules(modules)
      FileUtils.mkdir_p(File.dirname(installed_modules_file))
      File.write(installed_modules_file, JSON.pretty_generate(modules))
    end

    # Simple string inflection helpers
    def camelize(string)
      string.to_s.split('_').map(&:capitalize).join
    end

    def underscore(string)
      string.to_s.gsub(/([A-Z])/, '_\1').downcase.sub(/^_/, '')
    end
  end
end