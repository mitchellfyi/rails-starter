# frozen_string_literal: true

require_relative 'base_command'

module Synth
  module Commands
    # Command to list available and installed modules
    class ListCommand < BaseCommand
      def execute(options = {})
        if options[:installed]
          show_installed_modules
        elsif options[:available]
          show_available_modules  
        else
          show_available_modules
          puts ""
          show_installed_modules
        end
      end
    end
  end
end