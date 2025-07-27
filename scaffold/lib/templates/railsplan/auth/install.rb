# frozen_string_literal: true

# Synth Auth module installer for the Rails SaaS starter template.
# This module sets up comprehensive authentication with Devise, OmniAuth, and 2FA.

say_status :auth, "Installing authentication module with Devise and OmniAuth"

# Add authentication gems (only if not already present)
unless File.read('Gemfile').include?('devise')
  add_gem 'devise', '~> 4.9'
end

unless File.read('Gemfile').include?('omniauth')
  add_gem 'omniauth', '~> 2.1'
end

unless File.read('Gemfile').include?('omniauth-google-oauth2')
  add_gem 'omniauth-google-oauth2', '~> 1.1'
end

unless File.read('Gemfile').include?('omniauth-github')
  add_gem 'omniauth-github', '~> 2.0'
end

unless File.read('Gemfile').include?('omniauth-rails-csrf-protection')
  add_gem 'omniauth-rails-csrf-protection', '~> 1.0'
end

# Always add 2FA specific gems as they're specific to this module
add_gem 'rotp', '~> 6.3' # For 2FA
add_gem 'rqrcode', '~> 2.2' # For QR codes

after_bundle do
  # Create domain-specific directories
  run 'mkdir -p app/domains/auth/app/{controllers,services,jobs,mailers,policies,queries}'
  run 'mkdir -p app/models/concerns' # Ensure models directory exists

  # Set up Devise
  generate 'devise:install'
  generate 'devise', 'User'
  
  # Generate User model with additional fields
  generate 'migration', 'AddFieldsToUsers',
    'first_name:string',
    'last_name:string',
    'avatar_url:string',
    'timezone:string',
    'locale:string',
    'two_factor_secret:string',
    'two_factor_enabled:boolean',
    'two_factor_backup_codes:text',
    'last_login_at:datetime',
    'login_count:integer'

  # Set up OmniAuth
  initializer 'omniauth.rb', <<~'RUBY'
    Rails.application.config.middleware.use OmniAuth::Builder do
      provider :google_oauth2, 
               Rails.application.credentials.google&.client_id,
               Rails.application.credentials.google&.client_secret,
               scope: 'userinfo.email,userinfo.profile'
      
      provider :github,
               Rails.application.credentials.github&.client_id,
               Rails.application.credentials.github&.client_secret,
               scope: 'user:email'
    end

    OmniAuth.config.allowed_request_methods = [:post, :get]
    OmniAuth.config.silence_get_warning = true
  RUBY

  # Create Identity model for OAuth providers
  generate 'model', 'Identity', 'user:references', 'provider:string', 'uid:string', 'email:string', 'name:string', 'image_url:string'
  # Identity model is generated in central models directory (correct location)
  # The migration will remain in db/migrate

  # Create sessions controller in domain-specific path
  create_file 'app/domains/auth/app/controllers/sessions_controller.rb', <<~'RUBY'
    class SessionsController < Devise::SessionsController
      def omniauth
        identity = Identity.find_or_create_by(
          provider: auth_params[:provider],
          uid: auth_params[:uid]
        ) do |i|
          i.email = auth_params[:info][:email]
          i.name = auth_params[:info][:name]
          i.image_url = auth_params[:info][:image]
        end

        if identity.user
          sign_in(identity.user)
          redirect_to after_sign_in_path_for(identity.user)
        else
          # Create new user from OAuth
          user = create_user_from_oauth(identity)
          if user.persisted?
            identity.update!(user: user)
            sign_in(user)
            redirect_to after_sign_in_path_for(user)
          else
            redirect_to new_user_registration_path, alert: 'Unable to create account'
          end
        end
      end

      private

      def auth_params
        request.env['omniaiauth.auth']
      end

      def create_user_from_oauth(identity)
        User.create!(
          email: identity.email,
          first_name: identity.name&.split&.first,
          last_name: identity.name&.split&.last,
          avatar_url: identity.image_url,
          password: Devise.friendly_token[0, 20],
          confirmed_at: Time.current
        )
      end
    end
  RUBY

  # Create 2FA controller in domain-specific path
  create_file 'app/domains/auth/app/controllers/two_factor_controller.rb', <<~'RUBY'
    class TwoFactorController < ApplicationController
      before_action :authenticate_user!

      def show
        if current_user.two_factor_enabled?
          @qr_code = nil
        else
          secret = current_user.two_factor_secret || generate_secret
          current_user.update!(two_factor_secret: secret)
          
          issuer = Rails.application.class.name.split('::').first
          qr_code = RQRCode::QRCode.new(
            ROTP::TOTP.new(secret, issuer: issuer).provisioning_uri(current_user.email)
          )
          @qr_code = qr_code.as_svg(module_size: 4)
        end
        
        @backup_codes = current_user.two_factor_backup_codes&.split(',') || []
      end

      def enable
        totp = ROTP::TOTP.new(current_user.two_factor_secret)
        
        if totp.verify(params[:code], drift_ahead: 30, drift_behind: 30)
          backup_codes = generate_backup_codes
          current_user.update!(
            two_factor_enabled: true,
            two_factor_backup_codes: backup_codes.join(',')
          )
          
          flash[:notice] = 'Two-factor authentication enabled successfully'
          redirect_to two_factor_path
        else
          flash[:alert] = 'Invalid verification code'
          redirect_to two_factor_path
        end
      end

      def disable
        current_user.update!(
          two_factor_enabled: false,
          two_factor_secret: nil,
          two_factor_backup_codes: nil
        )
        
        flash[:notice] = 'Two-factor authentication disabled'
        redirect_to two_factor_path
      end

      private

      def generate_secret
        ROTP::Base32.random
      end

      def generate_backup_codes
        10.times.map { SecureRandom.hex(4) }
      end
    end
  RUBY

  # Create User model enhancements in domain-specific path
  create_file 'app/models/concerns/user_authentication.rb', <<~'RUBY'
    module UserAuthentication
      extend ActiveSupport::Concern

      included do
        has_many :identities, dependent: :destroy
        
        validates :email, presence: true, uniqueness: true
        
        before_save :normalize_email
        after_sign_in :track_login
      end

      def full_name
        [first_name, last_name].compact.join(' ')
      end

      def initials
        [first_name&.first, last_name&.first].compact.join.upcase
      end

      def avatar
        avatar_url.present? ? avatar_url : gravatar_url
      end

      def two_factor_qr_code
        return nil unless two_factor_secret

        issuer = Rails.application.class.name.split('::').first
        totp = ROTP::TOTP.new(two_factor_secret, issuer: issuer)
        qr_code = RQRCode::QRCode.new(totp.provisioning_uri(email))
        qr_code.as_svg(module_size: 4)
      end

      def verify_two_factor(code)
        return false unless two_factor_enabled?

        totp = ROTP::TOTP.new(two_factor_secret)
        totp.verify(code, drift_ahead: 30, drift_behind: 30) ||
          verify_backup_code(code)
      end

      private

      def normalize_email
        self.email = email.downcase.strip if email.present?
      end

      def track_login
        self.last_login_at = Time.current
        self.login_count = (login_count || 0) + 1
        save!(validate: false)
      end

      def gravatar_url
        hash = Digest::MD5.hexdigest(email.downcase)
        "https://www.gravatar.com/avatar/#{hash}?d=identicon"
      end

      def verify_backup_code(code)
        return false unless two_factor_backup_codes.present?

        codes = two_factor_backup_codes.split(',')
        if codes.include?(code)
          codes.delete(code)
          update!(two_factor_backup_codes: codes.join(','))
          true
        else
          false
        end
      end
    end
  RUBY

  # Include UserAuthentication concern in the main User model
  inject_into_file 'app/models/user.rb', after: "class User < ApplicationRecord\n" do
    <<~RUBY
      include UserAuthentication
    RUBY
  end

  # Add authentication routes
  route <<~'RUBY'
    # Auth domain routes
    scope module: :auth do
      devise_for :users, controllers: {
        sessions: 'sessions',
        omniauth_callbacks: 'sessions'
      }
      resource :two_factor, only: [:show, :enable, :disable]
    end
  RUBY

  say_status :auth, "Authentication module installed. Next steps:"
  say_status :auth, "1. Run rails db:migrate"
  say_status :auth, "2. Configure OAuth credentials in Rails credentials"
  say_status :auth, "3. Review and adjust routes in config/routes.rb if needed"
end