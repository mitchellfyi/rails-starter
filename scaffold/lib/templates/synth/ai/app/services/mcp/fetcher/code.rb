# frozen_string_literal: true

module Mcp
  module Fetcher
    # Code fetcher for introspecting the application codebase to find method
    # definitions, comments, and other code-related information for context.
    #
    # Example:
    #   # Register for code search
    #   Mcp::Registry.register(:find_methods, Mcp::Fetcher::Code)
    #
    #   # Use in context
    #   context.fetch(:find_methods,
    #     search_term: "authenticate",
    #     search_type: :method_name,
    #     file_pattern: "**/*.rb",
    #     include_comments: true
    #   )
    class Code < Base
      def self.allowed_params
        [:search_term, :search_type, :file_pattern, :include_comments, :include_tests,
         :max_results, :context_lines, :root_path, :exclude_paths]
      end

      def self.required_params
        [:search_term]
      end

      def self.required_param?(param)
        required_params.include?(param)
      end

      def self.description
        "Searches codebase for method definitions, comments, and code patterns"
      end

      def self.fetch(search_term:, search_type: :method_name, file_pattern: "**/*.rb",
                     include_comments: true, include_tests: false, max_results: 20,
                     context_lines: 3, root_path: nil, exclude_paths: [], **)
        
        validate_all_params!(
          search_term: search_term, search_type: search_type, file_pattern: file_pattern,
          include_comments: include_comments, include_tests: include_tests, max_results: max_results,
          context_lines: context_lines, root_path: root_path, exclude_paths: exclude_paths
        )

        # Set default root path to Rails.root if available
        root_path ||= defined?(Rails) ? Rails.root.to_s : Dir.pwd
        
        # Get list of files to search
        files = get_files_to_search(root_path, file_pattern, include_tests, exclude_paths)
        
        # Perform search based on type
        results = case search_type.to_sym
                 when :method_name
                   search_method_names(files, search_term, context_lines)
                 when :method_content
                   search_method_content(files, search_term, context_lines)
                 when :class_name
                   search_class_names(files, search_term, context_lines)
                 when :comments
                   search_comments(files, search_term, context_lines)
                 when :content
                   search_file_content(files, search_term, context_lines)
                 else
                   raise ArgumentError, "Invalid search_type: #{search_type}"
                 end

        # Filter out comments if not requested
        results = filter_comments(results) unless include_comments

        # Limit results
        results = results.take(max_results)

        {
          search_term: search_term,
          search_type: search_type,
          files_searched: files.size,
          results_count: results.size,
          max_results: max_results,
          results: results.map { |result| format_code_result(result) },
          search_performed_at: Time.current
        }
      end

      def self.fallback_data(search_term: nil, **)
        {
          search_term: search_term,
          search_type: :unknown,
          files_searched: 0,
          results_count: 0,
          max_results: 0,
          results: [],
          error: 'Failed to search codebase'
        }
      end

      private

      # Get list of files to search
      def self.get_files_to_search(root_path, file_pattern, include_tests, exclude_paths)
        search_pattern = File.join(root_path, file_pattern)
        files = Dir.glob(search_pattern)

        # Filter out test files if not requested
        unless include_tests
          files = files.reject { |file| file.match?(%r{/(test|spec)/}) }
        end

        # Filter out excluded paths
        exclude_paths.each do |exclude_path|
          files = files.reject { |file| file.include?(exclude_path) }
        end

        # Filter out common directories to exclude
        default_excludes = %w[node_modules vendor .git tmp log coverage]
        default_excludes.each do |exclude|
          files = files.reject { |file| file.include?("/#{exclude}/") }
        end

        files.select { |file| File.file?(file) && File.readable?(file) }
      end

      # Search for method names (def method_name)
      def self.search_method_names(files, search_term, context_lines)
        regex = /^\s*def\s+#{Regexp.escape(search_term)}\b/
        search_with_regex(files, regex, context_lines, :method_definition)
      end

      # Search for content within method definitions
      def self.search_method_content(files, search_term, context_lines)
        results = []
        
        files.each do |file|
          begin
            content = File.read(file)
            lines = content.lines
            
            in_method = false
            method_start = 0
            method_name = nil
            indent_level = 0
            
            lines.each_with_index do |line, index|
              # Check for method definition
              if line.match(/^\s*def\s+(\w+)/)
                in_method = true
                method_start = index
                method_name = $1
                indent_level = line.match(/^(\s*)/)[1].length
              elsif in_method && line.match(/^\s*end\b/) && 
                    line.match(/^(\s*)/)[1].length <= indent_level
                # End of method
                in_method = false
                method_name = nil
              elsif in_method && line.include?(search_term)
                # Found search term within method
                results << {
                  file: file,
                  line_number: index + 1,
                  content: line.strip,
                  context: get_context_lines(lines, index, context_lines),
                  method_name: method_name,
                  type: :method_content
                }
              end
            end
          rescue => e
            Rails.logger.warn("MCP Code: Error reading file #{file}: #{e.message}")
          end
        end
        
        results
      end

      # Search for class names
      def self.search_class_names(files, search_term, context_lines)
        regex = /^\s*class\s+#{Regexp.escape(search_term)}\b/
        search_with_regex(files, regex, context_lines, :class_definition)
      end

      # Search in comments
      def self.search_comments(files, search_term, context_lines)
        regex = /#.*#{Regexp.escape(search_term)}/
        search_with_regex(files, regex, context_lines, :comment)
      end

      # Search general file content
      def self.search_file_content(files, search_term, context_lines)
        regex = /#{Regexp.escape(search_term)}/
        search_with_regex(files, regex, context_lines, :content)
      end

      # Generic regex search helper
      def self.search_with_regex(files, regex, context_lines, result_type)
        results = []
        
        files.each do |file|
          begin
            content = File.read(file)
            lines = content.lines
            
            lines.each_with_index do |line, index|
              if line.match(regex)
                results << {
                  file: file,
                  line_number: index + 1,
                  content: line.strip,
                  context: get_context_lines(lines, index, context_lines),
                  type: result_type
                }
              end
            end
          rescue => e
            Rails.logger.warn("MCP Code: Error reading file #{file}: #{e.message}")
          end
        end
        
        results
      end

      # Get context lines around a match
      def self.get_context_lines(lines, target_index, context_lines)
        start_index = [0, target_index - context_lines].max
        end_index = [lines.length - 1, target_index + context_lines].min
        
        context = {}
        
        # Before lines
        if start_index < target_index
          context[:before] = lines[start_index...target_index].map.with_index(start_index + 1) do |line, idx|
            { line_number: idx, content: line.rstrip }
          end
        end
        
        # Target line
        context[:match] = {
          line_number: target_index + 1,
          content: lines[target_index].rstrip
        }
        
        # After lines
        if end_index > target_index
          context[:after] = lines[(target_index + 1)..end_index].map.with_index(target_index + 2) do |line, idx|
            { line_number: idx, content: line.rstrip }
          end
        end
        
        context
      end

      # Filter out comment results if not requested
      def self.filter_comments(results)
        results.reject { |result| result[:type] == :comment }
      end

      # Format code search result
      def self.format_code_result(result)
        relative_file = result[:file].gsub(Rails.root.to_s + '/', '') if defined?(Rails)
        relative_file ||= File.basename(result[:file])
        
        {
          file: relative_file,
          full_path: result[:file],
          line_number: result[:line_number],
          content: result[:content],
          context: result[:context],
          type: result[:type],
          method_name: result[:method_name]
        }
      end

      # Get method signature and documentation
      def self.get_method_info(file, method_name)
        begin
          content = File.read(file)
          lines = content.lines
          
          method_line_index = lines.index { |line| line.match(/^\s*def\s+#{Regexp.escape(method_name)}\b/) }
          return nil unless method_line_index
          
          # Get method signature
          signature = lines[method_line_index].strip
          
          # Look for documentation comments above the method
          docs = []
          (method_line_index - 1).downto(0) do |i|
            line = lines[i].strip
            if line.start_with?('#')
              docs.unshift(line[1..-1].strip)
            elsif line.empty?
              next
            else
              break
            end
          end
          
          {
            signature: signature,
            documentation: docs,
            file: file,
            line_number: method_line_index + 1
          }
        rescue => e
          Rails.logger.warn("MCP Code: Error getting method info for #{method_name} in #{file}: #{e.message}")
          nil
        end
      end
    end
  end
end