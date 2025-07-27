# frozen_string_literal: true

# Rails version configuration for the template
# This file allows easy switching between Rails edge and stable versions

def check_ruby_version
  ruby_version = Gem::Version.new(RUBY_VERSION)
  recommended_version = Gem::Version.new('3.4.2')

  if ruby_version < Gem::Version.new('3.4.0')
    say_status :error, "Ruby #{RUBY_VERSION} is not supported. Please use Ruby >= 3.4.0"
    exit 1
  end

  if ruby_version < recommended_version
    say_status :warning, "Ruby #{RUBY_VERSION} detected. Ruby 3.4.2 is recommended for optimal compatibility."
  else
    say_status :ruby_version, "Using Ruby #{RUBY_VERSION} (recommended: 3.4.2)"
  end
end

def configure_rails_version
  # Check Ruby version compatibility first
  check_ruby_version
  
  say_status :rails_version, "Configuring Rails version..."
  
  # Check if user wants to use Rails edge or stable
  rails_version_choice = ask_with_default(
    "Rails version to use:",
    ["edge", "stable"],
    "edge"
  )
  
  case rails_version_choice
  when "edge"
    configure_rails_edge
  when "stable"
    configure_rails_stable
  end
end

def configure_rails_edge
  # Rails edge is already configured in the main Gemfile
  say_status :rails_version, "Using Rails edge (main branch) for latest features"
  
  # Add a note to the Gemfile about the edge version
  inject_into_file 'Gemfile', after: "# Use Rails edge (main branch) by default, with Rails 8 as fallback\n" do
    <<~RUBY
      # Rails edge provides the latest features and improvements
      # If you encounter issues, consider switching to Rails 8 stable
    RUBY
  end
end

def configure_rails_stable
  # Comment out edge and uncomment stable
  gsub_file 'Gemfile', /gem 'rails', github: 'rails\/rails', branch: 'main'/, '# gem \'rails\', github: \'rails/rails\', branch: \'main\''
  gsub_file 'Gemfile', /# gem 'rails', '~> 8\.0\.0'/, "gem 'rails', '~> 8.0.0'"
  
  say_status :rails_version, "Using Rails 8 stable version"
  
  # Add a note about the stable version
  inject_into_file 'Gemfile', after: "gem 'rails', '~> 8.0.0'\n" do
    <<~RUBY
      # Rails 8 stable provides a reliable, production-ready foundation
      # For latest features, consider switching to Rails edge
    RUBY
  end
end

def ask_with_default(question, choices, default)
  puts question
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
    ask_with_default(question, choices, default)
  end
end 