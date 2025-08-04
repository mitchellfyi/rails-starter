# frozen_string_literal: true

module Railsplan
  module Web
    class Engine < ::Rails::Engine
      isolate_namespace Railsplan::Web
      
      # Configure the engine
      config.generators do |g|
        g.test_framework :test_unit, fixture: false
        g.assets false
        g.helper false
      end
      
      # Auto-mount in development and test environments only if Rails.application exists
      initializer "railsplan.web.auto_mount" do |app|
        if defined?(Rails.application) && (Rails.env.development? || Rails.env.test?)
          app.routes.append do
            mount Railsplan::Web::Engine, at: "/railsplan"
          end
        end
      end
      
      # Load routes
      config.paths.add "config/routes.rb", with: "config/routes"
    end
  end
end