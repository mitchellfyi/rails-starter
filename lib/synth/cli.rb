# frozen_string_literal: true

require 'fileutils'
require 'json'
require 'pathname'

# Load all command classes
require_relative 'commands/base_command'
require_relative 'commands/list_command'
require_relative 'commands/add_command'
require_relative 'commands/remove_command'
require_relative 'commands/bootstrap_command'
require_relative 'commands/doctor_command'
require_relative 'commands/info_command'
require_relative 'commands/test_command'

module Synth
  # Main CLI dispatcher for Synth commands
  class CLI
    COMMANDS = {
      'list' => Commands::ListCommand,
      'add' => Commands::AddCommand,
      'remove' => Commands::RemoveCommand,
      'bootstrap' => Commands::BootstrapCommand,
      'doctor' => Commands::DoctorCommand,
      'info' => Commands::InfoCommand,
      'test' => Commands::TestCommand
    }.freeze

    def self.start(args)
      new.execute(args)
    end

    def execute(args)
      command_name = args.first
      verbose = args.include?('--verbose') || args.include?('-v')
      
      case command_name
      when 'help', '--help', '-h', nil
        show_help
      when *COMMANDS.keys
        run_command(command_name, args[1..-1], verbose)
      when 'upgrade'
        run_upgrade_command(args[1..-1], verbose)
      when 'docs'
        run_docs_command(verbose)
      else
        puts "❌ Unknown command: #{command_name}"
        show_help
        exit 1
      end
    end

    private

    def run_command(command_name, args, verbose)
      command_class = COMMANDS[command_name]
      command = command_class.new(verbose: verbose)
      
      case command_name
      when 'list'
        options = {
          available: args.include?('--available') || args.include?('-a'),
          installed: args.include?('--installed') || args.include?('-i')
        }
        command.execute(options)
      when 'add'
        module_name = args.first
        unless module_name
          puts "❌ Module name required. Usage: bin/synth add MODULE_NAME"
          exit 1
        end
        options = { force: args.include?('--force') || args.include?('-f') }
        command.execute(module_name, options)
      when 'remove'
        module_name = args.first
        unless module_name
          puts "❌ Module name required. Usage: bin/synth remove MODULE_NAME"
          exit 1
        end
        options = { force: args.include?('--force') || args.include?('-f') }
        command.execute(module_name, options)
      when 'bootstrap'
        options = {
          skip_modules: args.include?('--skip-modules'),
          skip_credentials: args.include?('--skip-credentials')
        }
        command.execute(options)
      when 'doctor'
        command.execute
      when 'info'
        module_name = args.first
        unless module_name
          puts "❌ Module name required. Usage: bin/synth info MODULE_NAME"
          exit 1
        end
        command.execute(module_name)
      when 'test'
        module_name = args.first
        command.execute(module_name)
      end
    end

    def run_upgrade_command(args, verbose)
      puts "🔄 Upgrade command not yet implemented in modular CLI"
      puts "This will be implemented in a future update"
      # TODO: Implement upgrade command
    end

    def run_docs_command(verbose)
      puts "📚 Docs command not yet implemented in modular CLI"
      puts "This will be implemented in a future update"
      # TODO: Implement docs command
    end

    def show_help
      puts <<~HELP
        bin/synth - Rails SaaS Starter Template Module Manager

        USAGE:
          bin/synth COMMAND [OPTIONS]

        COMMANDS:
          bootstrap             Interactive setup wizard for new applications
          list                  List available and installed modules
          add MODULE            Install a feature module
          remove MODULE         Uninstall a feature module  
          info MODULE           Show detailed information about a module
          test [MODULE]         Run tests for a module or all modules
          doctor                Validate setup and configuration
          help                  Show this help message

        BOOTSTRAP MODES:
          bootstrap             Interactive wizard with setup type selection
          bootstrap --demo      Quick demo setup with sensible defaults
          bootstrap --guided    Full guided setup for production

        OPTIONS:
          --verbose, -v         Enable verbose output
          --force, -f           Force operation without confirmation
          --available, -a       Show only available modules (list command)
          --installed, -i       Show only installed modules (list command)

        EXAMPLES:
          bin/synth bootstrap              # Interactive setup wizard
          bin/synth list                   # Show all modules
          bin/synth add billing            # Install billing module
          bin/synth remove cms --force     # Remove CMS module without confirmation
          bin/synth info ai                # Show AI module information
          bin/synth test billing           # Run billing module tests
          bin/synth doctor                 # Check system health

        GETTING STARTED:
          1. Run 'bin/synth bootstrap' for guided setup
          2. Choose demo mode for quick start or guided mode for production
          3. Follow the wizard prompts to configure your application
          4. Run 'bin/synth doctor' to validate your setup

        For more information, visit: docs/README.md
      HELP
    end
  end
end