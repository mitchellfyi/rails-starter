# frozen_string_literal: true

module Auth
  # This module serves as the entry point for the Auth domain.
  # It can be used to define configuration, constants, or helper methods
  # that are specific to the authentication functionality.

  def self.table_name_prefix
    'auth_'
  end
end
