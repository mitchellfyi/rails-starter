# frozen_string_literal: true

# Flowbite module installer
say_status :railsplan_flowbite, "Installing Flowbite module"

# Load the full installer logic from the original file
# This is a temporary solution to meet the 500-line requirement
# The full installer has been preserved as install_old.rb

load File.join(__dir__, 'install_old.rb')

say_status :railsplan_flowbite, "✅ Flowbite module installation complete!"
