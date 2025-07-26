# frozen_string_literal: true

require 'rails/generators/named_base'

module Rails
  module Generators
    class ModularScaffoldGenerator < NamedBase
      argument :attributes, type: :array, default: [],
                           banner: "field:type field:type"

      class_option :domain, type: :string, required: true,
                            desc: "The domain (e.g., auth, billing) for the scaffold"
      class_option :modular, type: :boolean, default: true,
                             desc: "Generate modular scaffold within the domain"

      def create_modular_scaffold
        return unless options[:modular]

        domain_path = "app/domains/#{options[:domain]}"
        unless Dir.exist?(Rails.root.join(domain_path))
          say_status :error, "Domain directory not found: #{domain_path}"
          exit 1
        end

        # Generate model in the main app/models directory (not in domain)
        # This keeps models centralized while domain logic goes in subfolders
        invoke "rails:model", [name, attributes.map(&:to_s)]

        # Generate controller within the domain
        invoke "rails:controller", [name.pluralize, "--no-helper", "--no-assets"],
               dir: "#{domain_path}/app/controllers"

        # Generate views within the domain
        # This is a simplified example; a real scaffold would generate more views
        %w[index show new edit].each do |view|
          create_file "#{domain_path}/app/views/#{name.pluralize}/#{view}.html.erb" do
            "<!-- #{name.pluralize.capitalize} #{view} view -->"
          end
        end

        # Generate tests within the domain
        invoke "rspec:model", [name, attributes.map(&:to_s)],
               dir: "spec/domains/#{options[:domain]}/models"
        invoke "rspec:request", [name.pluralize],
               dir: "spec/domains/#{options[:domain]}/requests"

        say_status :success, "Modular scaffold for #{name} created in #{domain_path}"
      end

      def create_regular_scaffold
        return if options[:modular]

        # Fallback to regular Rails scaffold if --modular is false
        invoke "rails:scaffold", [name, attributes.map(&:to_s)]
      end
    end
  end
end
