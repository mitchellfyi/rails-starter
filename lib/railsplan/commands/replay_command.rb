# frozen_string_literal: true

require_relative 'base_command'
require 'json'
require 'yaml'

module RailsPlan
  module Commands
    # Command for replaying AI interactions from prompt logs
    class ReplayCommand < BaseCommand
      def initialize(verbose: false)
        super
        @prompts_log_path = File.join(".railsplan", "prompts.log")
      end

      def execute(options = {})
        unless File.exist?(@prompts_log_path)
          puts "❌ No prompts log found at #{@prompts_log_path}"
          puts "💡 Run some AI commands first to generate prompt logs"
          return false
        end

        puts "🔄 Replaying AI interactions from prompts log..."
        
        # Parse options
        session_id = options[:session]
        command_filter = options[:command]
        dry_run = options[:dry_run] || false
        interactive = options[:interactive] || false
        
        # Load and parse prompts log
        log_entries = parse_prompts_log
        
        if log_entries.empty?
          puts "ℹ️  No valid log entries found"
          return true
        end
        
        # Filter entries if requested
        filtered_entries = filter_entries(log_entries, session_id, command_filter)
        
        if filtered_entries.empty?
          puts "ℹ️  No entries match the specified filters"
          puts "💡 Available sessions: #{available_sessions(log_entries).join(', ')}" if session_id
          puts "💡 Available commands: #{available_commands(log_entries).join(', ')}" if command_filter
          return true
        end
        
        puts "📋 Found #{filtered_entries.length} entries to replay"
        
        # Replay entries
        success_count = 0
        filtered_entries.each_with_index do |entry, index|
          puts "\n#{index + 1}/#{filtered_entries.length}: Replaying #{entry[:command]}"
          
          if interactive
            print "🤔 Replay this entry? (y/n/q): "
            response = $stdin.gets.chomp.downcase
            case response
            when 'q', 'quit'
              puts "🛑 Replay cancelled by user"
              break
            when 'n', 'no'
              puts "⏭️  Skipping entry"
              next
            end
          end
          
          if replay_entry(entry, dry_run, options)
            success_count += 1
            puts "✅ Entry replayed successfully"
          else
            puts "❌ Failed to replay entry"
            break unless options[:continue_on_error]
          end
        end
        
        puts "\n🎬 Replay complete: #{success_count}/#{filtered_entries.length} entries succeeded"
        success_count == filtered_entries.length
      end

      private

      def parse_prompts_log
        entries = []
        current_entry = nil
        
        File.readlines(@prompts_log_path).each_with_index do |line, line_number|
          line = line.strip
          next if line.empty?
          
          # Check for new entry marker (timestamp + command)
          if line.match?(/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/)
            # Save previous entry if exists
            entries << current_entry if current_entry&.dig(:prompt)
            
            # Parse new entry
            parts = line.split(' ', 3)
            if parts.length >= 3
              current_entry = {
                timestamp: parts[0],
                session_id: parts[1],
                command: parts[2],
                prompt: "",
                response: "",
                metadata: {},
                line_number: line_number + 1
              }
            end
          elsif line.start_with?("PROMPT:")
            current_entry[:prompt] = line[7..-1].strip if current_entry
          elsif line.start_with?("RESPONSE:")
            current_entry[:response] = line[9..-1].strip if current_entry
          elsif line.start_with?("METADATA:")
            begin
              metadata_json = line[9..-1].strip
              current_entry[:metadata] = JSON.parse(metadata_json) if current_entry
            rescue JSON::ParserError
              # Ignore invalid metadata
            end
          elsif current_entry
            # Multi-line content
            if current_entry[:response].empty?
              current_entry[:prompt] += " #{line}"
            else
              current_entry[:response] += " #{line}"
            end
          end
        end
        
        # Don't forget the last entry
        entries << current_entry if current_entry&.dig(:prompt)
        
        entries.compact
      rescue => e
        puts "❌ Failed to parse prompts log: #{e.message}"
        []
      end

      def filter_entries(entries, session_id, command_filter)
        filtered = entries
        
        if session_id
          filtered = filtered.select { |entry| entry[:session_id] == session_id }
        end
        
        if command_filter
          filtered = filtered.select { |entry| entry[:command].include?(command_filter) }
        end
        
        filtered
      end

      def available_sessions(entries)
        entries.map { |e| e[:session_id] }.uniq.sort
      end

      def available_commands(entries)
        entries.map { |e| e[:command] }.uniq.sort
      end

      def replay_entry(entry, dry_run, options)
        puts "📅 Original timestamp: #{entry[:timestamp]}"
        puts "🔖 Session ID: #{entry[:session_id]}"
        puts "💬 Command: #{entry[:command]}"
        puts "📝 Prompt: #{truncate_text(entry[:prompt], 100)}"
        
        if dry_run
          puts "🔍 [DRY RUN] Would replay this entry"
          return true
        end
        
        # Determine command type and replay accordingly
        case entry[:command]
        when /^generate/
          replay_generate_command(entry, options)
        when /^evolve/
          replay_evolve_command(entry, options)
        when /^refactor/
          replay_refactor_command(entry, options)
        when /^fix/
          replay_fix_command(entry, options)
        when /^chat/
          replay_chat_command(entry, options)
        else
          puts "⚠️  Unknown command type, skipping replay"
          false
        end
      end

      def replay_generate_command(entry, options)
        # Extract instruction from prompt or command
        instruction = extract_instruction(entry)
        return false unless instruction
        
        puts "🔄 Replaying generate command with instruction: #{truncate_text(instruction, 50)}"
        
        begin
          require "railsplan/commands/generate_command"
          command = GenerateCommand.new(verbose: options[:verbose])
          
          # Build options from metadata and replay options
          generate_options = build_command_options(entry, options)
          
          command.execute(instruction, generate_options)
        rescue => e
          puts "❌ Failed to replay generate command: #{e.message}"
          false
        end
      end

      def replay_evolve_command(entry, options)
        instruction = extract_instruction(entry)
        return false unless instruction
        
        puts "🔄 Replaying evolve command with instruction: #{truncate_text(instruction, 50)}"
        
        begin
          require "railsplan/commands/upgrade_command"
          command = UpgradeCommand.new(verbose: options[:verbose])
          
          evolve_options = build_command_options(entry, options)
          
          command.execute(instruction, evolve_options)
        rescue => e
          puts "❌ Failed to replay evolve command: #{e.message}"
          false
        end
      end

      def replay_refactor_command(entry, options)
        # Extract path from command or metadata
        path = extract_path_from_entry(entry)
        return false unless path
        
        puts "🔄 Replaying refactor command for path: #{path}"
        
        begin
          require "railsplan/commands/refactor_command"
          command = RefactorCommand.new(verbose: options[:verbose])
          
          refactor_options = build_command_options(entry, options)
          
          command.execute(path, refactor_options)
        rescue => e
          puts "❌ Failed to replay refactor command: #{e.message}"
          false
        end
      end

      def replay_fix_command(entry, options)
        instruction = extract_instruction(entry)
        return false unless instruction
        
        puts "🔄 Replaying fix command with issue: #{truncate_text(instruction, 50)}"
        
        begin
          require "railsplan/commands/fix_command"
          command = FixCommand.new(verbose: options[:verbose])
          
          fix_options = build_command_options(entry, options)
          
          command.execute(instruction, fix_options)
        rescue => e
          puts "❌ Failed to replay fix command: #{e.message}"
          false
        end
      end

      def replay_chat_command(entry, options)
        prompt = entry[:prompt]
        return false if prompt.empty?
        
        puts "🔄 Replaying chat command with prompt: #{truncate_text(prompt, 50)}"
        
        begin
          require "railsplan/commands/chat_command"
          command = ChatCommand.new(verbose: options[:verbose])
          
          chat_options = build_command_options(entry, options)
          chat_options[:interactive] = false  # Don't make replays interactive
          
          command.execute(prompt, chat_options)
        rescue => e
          puts "❌ Failed to replay chat command: #{e.message}"
          false
        end
      end

      def extract_instruction(entry)
        # Try to extract from prompt first
        prompt = entry[:prompt]
        return prompt unless prompt.empty?
        
        # Try to extract from command
        command_parts = entry[:command].split(' ', 2)
        if command_parts.length > 1
          return command_parts[1]
        end
        
        puts "❌ Could not extract instruction from entry"
        nil
      end

      def extract_path_from_entry(entry)
        # Try to extract from metadata first
        path = entry.dig(:metadata, 'path')
        return path if path
        
        # Try to extract from command
        command_parts = entry[:command].split(' ')
        if command_parts.length > 1
          potential_path = command_parts[1]
          return potential_path if File.exist?(potential_path) || potential_path.include?('/')
        end
        
        puts "❌ Could not extract valid path from entry"
        nil
      end

      def build_command_options(entry, base_options)
        # Start with base replay options
        command_options = base_options.dup
        
        # Add metadata from log entry
        metadata = entry[:metadata] || {}
        
        # Map common metadata fields to command options
        command_options[:profile] = metadata['profile'] if metadata['profile']
        command_options[:creative] = metadata['creative'] if metadata.key?('creative')
        command_options[:max_tokens] = metadata['max_tokens'] if metadata['max_tokens']
        command_options[:format] = metadata['format'] if metadata['format']
        
        # Force some options for replay safety
        command_options[:dry_run] = true if command_options[:replay_dry_run]
        command_options[:force] = true unless command_options[:replay_interactive]
        
        command_options
      end

      def truncate_text(text, max_length)
        return text if text.length <= max_length
        "#{text[0...max_length-3]}..."
      end
    end
  end
end