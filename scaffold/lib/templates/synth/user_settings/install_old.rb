# frozen_string_literal: true

# Synth User Settings module installer for the Rails SaaS starter template.
# This module sets up comprehensive user settings management including profile,
# credentials, 2FA, OAuth accounts, and preferences.

say_status :user_settings, "Installing user settings module"

# Check for auth module dependency
unless File.exist?('app/domains/auth')
  say_status :error, "Auth module is required. Please install it first with: bin/synth add auth", :red
  exit 1
end

after_bundle do
  # Create domain-specific directories
  run 'mkdir -p app/domains/user_settings/app/{controllers,models/concerns,services,policies,queries}'
  run 'mkdir -p app/domains/user_settings/app/views/{user_settings,shared}'

  # Create main user settings controller
  create_file 'app/domains/user_settings/app/controllers/user_settings_controller.rb', <<~'RUBY'
    class UserSettingsController < ApplicationController
      before_action :authenticate_user!
      before_action :set_user
      
      def show
        @profile_form = UserSettings::ProfileForm.new(@user)
        @password_form = UserSettings::PasswordForm.new(@user)
        @preferences_form = UserSettings::PreferencesForm.new(@user)
        @connected_accounts = @user.identities.includes(:user)
        @two_factor_enabled = @user.two_factor_enabled?
      end

      def update_profile
        @profile_form = UserSettings::ProfileForm.new(@user)
        
        if @profile_form.update(profile_params)
          flash[:notice] = 'Profile updated successfully'
          redirect_to settings_path
        else
          flash.now[:alert] = 'Please correct the errors below'
          render :show, status: :unprocessable_entity
        end
      end

      def update_password
        @password_form = UserSettings::PasswordForm.new(@user)
        
        if @password_form.update(password_params)
          # Sign in the user again to maintain the session after password change
          bypass_sign_in(@user)
          flash[:notice] = 'Password updated successfully'
          redirect_to settings_path
        else
          flash.now[:alert] = 'Please correct the errors below'
          render :show, status: :unprocessable_entity
        end
      end

      def update_preferences
        @preferences_form = UserSettings::PreferencesForm.new(@user)
        
        if @preferences_form.update(preferences_params)
          flash[:notice] = 'Preferences updated successfully'
          redirect_to settings_path
        else
          flash.now[:alert] = 'Please correct the errors below'
          render :show, status: :unprocessable_entity
        end
      end

      private

      def set_user
        @user = current_user
      end

      def profile_params
        params.require(:user_settings_profile_form).permit(:first_name, :last_name, :email, :avatar_url)
      end

      def password_params
        params.require(:user_settings_password_form).permit(:current_password, :password, :password_confirmation)
      end

      def preferences_params
        params.require(:user_settings_preferences_form).permit(:locale, :timezone, :email_notifications, :push_notifications)
      end
    end
  RUBY

  # Create form objects for better organization and validation
  create_file 'app/domains/user_settings/app/models/user_settings/profile_form.rb', <<~'RUBY'
    class UserSettings::ProfileForm
      include ActiveModel::Model
      include ActiveModel::Attributes
      include ActiveModel::Validations

      attribute :first_name, :string
      attribute :last_name, :string
      attribute :email, :string
      attribute :avatar_url, :string

      validates :first_name, presence: true, length: { maximum: 50 }
      validates :last_name, presence: true, length: { maximum: 50 }
      validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
      validates :avatar_url, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]), allow_blank: true }

      def initialize(user)
        @user = user
        super(
          first_name: user.first_name,
          last_name: user.last_name,
          email: user.email,
          avatar_url: user.avatar_url
        )
      end

      def update(params)
        assign_attributes(params)
        
        return false unless valid?

        # Check if email is being changed and if it's already taken
        if email_changed? && User.where.not(id: @user.id).exists?(email: email)
          errors.add(:email, 'is already taken')
          return false
        end

        @user.update!(
          first_name: first_name,
          last_name: last_name,
          email: email,
          avatar_url: avatar_url
        )

        true
      rescue ActiveRecord::RecordInvalid => e
        e.record.errors.each do |error|
          errors.add(error.attribute, error.message)
        end
        false
      end

      private

      def email_changed?
        email != @user.email
      end
    end
  RUBY

  create_file 'app/domains/user_settings/app/models/user_settings/password_form.rb', <<~'RUBY'
    class UserSettings::PasswordForm
      include ActiveModel::Model
      include ActiveModel::Attributes
      include ActiveModel::Validations

      attribute :current_password, :string
      attribute :password, :string
      attribute :password_confirmation, :string

      validates :current_password, presence: true
      validates :password, presence: true, length: { minimum: 6 }
      validates :password_confirmation, presence: true
      validate :password_confirmation_matches
      validate :current_password_is_correct

      def initialize(user)
        @user = user
        super()
      end

      def update(params)
        assign_attributes(params)
        
        return false unless valid?

        @user.update!(password: password, password_confirmation: password_confirmation)
        true
      rescue ActiveRecord::RecordInvalid => e
        e.record.errors.each do |error|
          errors.add(error.attribute, error.message)
        end
        false
      end

      private

      def password_confirmation_matches
        return unless password.present? && password_confirmation.present?
        
        errors.add(:password_confirmation, "doesn't match password") if password != password_confirmation
      end

      def current_password_is_correct
        return unless current_password.present?
        
        unless @user.valid_password?(current_password)
          errors.add(:current_password, 'is incorrect')
        end
      end
    end
  RUBY

  create_file 'app/domains/user_settings/app/models/user_settings/preferences_form.rb', <<~'RUBY'
    class UserSettings::PreferencesForm
      include ActiveModel::Model
      include ActiveModel::Attributes
      include ActiveModel::Validations

      attribute :locale, :string
      attribute :timezone, :string
      attribute :email_notifications, :boolean
      attribute :push_notifications, :boolean

      validates :locale, inclusion: { in: I18n.available_locales.map(&:to_s) }
      validates :timezone, inclusion: { in: ActiveSupport::TimeZone.all.map(&:name) }

      def initialize(user)
        @user = user
        super(
          locale: user.locale || I18n.default_locale.to_s,
          timezone: user.timezone || 'UTC',
          email_notifications: user.email_notifications.nil? ? true : user.email_notifications,
          push_notifications: user.push_notifications.nil? ? true : user.push_notifications
        )
      end

      def update(params)
        assign_attributes(params)
        
        return false unless valid?

        @user.update!(
          locale: locale,
          timezone: timezone,
          email_notifications: email_notifications,
          push_notifications: push_notifications
        )

        true
      rescue ActiveRecord::RecordInvalid => e
        e.record.errors.each do |error|
          errors.add(error.attribute, error.message)
        end
        false
      end
    end
  RUBY

  # Create OAuth accounts controller for managing connected accounts
  create_file 'app/domains/user_settings/app/controllers/oauth_accounts_controller.rb', <<~'RUBY'
    class OauthAccountsController < ApplicationController
      before_action :authenticate_user!
      before_action :set_identity, only: [:destroy]

      def destroy
        @identity.destroy!
        flash[:notice] = "#{@identity.provider.humanize} account disconnected successfully"
        redirect_to settings_path
      end

      private

      def set_identity
        @identity = current_user.identities.find(params[:id])
      end
    end
  RUBY

  # Add migration for new user fields
  generate 'migration', 'AddUserSettingsFieldsToUsers',
    'email_notifications:boolean',
    'push_notifications:boolean'

  # Create main settings view
  create_file 'app/domains/user_settings/app/views/user_settings/show.html.erb', <<~'ERB'
    <div class="max-w-4xl mx-auto py-8 px-4 sm:px-6 lg:px-8">
      <div class="space-y-8">
        <!-- Header -->
        <div>
          <h1 class="text-3xl font-bold text-gray-900">Account Settings</h1>
          <p class="mt-2 text-sm text-gray-600">
            Manage your profile, security settings, and preferences.
          </p>
        </div>

        <!-- Profile Section -->
        <div class="bg-white shadow rounded-lg">
          <div class="px-6 py-4 border-b border-gray-200">
            <h2 class="text-lg font-medium text-gray-900">Profile Information</h2>
            <p class="mt-1 text-sm text-gray-600">Update your personal information and email address.</p>
          </div>
          
          <div class="px-6 py-4">
            <%= form_with model: @profile_form, url: update_profile_settings_path, 
                         method: :patch, local: true, class: "space-y-4" do |f| %>
              
              <div class="grid grid-cols-1 gap-4 sm:grid-cols-2">
                <div>
                  <%= f.label :first_name, class: "block text-sm font-medium text-gray-700" %>
                  <%= f.text_field :first_name, 
                      class: "mt-1 block w-full border-gray-300 rounded-md shadow-sm focus:ring-indigo-500 focus:border-indigo-500" %>
                  <% if @profile_form.errors[:first_name].any? %>
                    <p class="mt-1 text-sm text-red-600"><%= @profile_form.errors[:first_name].first %></p>
                  <% end %>
                </div>

                <div>
                  <%= f.label :last_name, class: "block text-sm font-medium text-gray-700" %>
                  <%= f.text_field :last_name, 
                      class: "mt-1 block w-full border-gray-300 rounded-md shadow-sm focus:ring-indigo-500 focus:border-indigo-500" %>
                  <% if @profile_form.errors[:last_name].any? %>
                    <p class="mt-1 text-sm text-red-600"><%= @profile_form.errors[:last_name].first %></p>
                  <% end %>
                </div>
              </div>

              <div>
                <%= f.label :email, class: "block text-sm font-medium text-gray-700" %>
                <%= f.email_field :email, 
                    class: "mt-1 block w-full border-gray-300 rounded-md shadow-sm focus:ring-indigo-500 focus:border-indigo-500" %>
                <% if @profile_form.errors[:email].any? %>
                  <p class="mt-1 text-sm text-red-600"><%= @profile_form.errors[:email].first %></p>
                <% end %>
              </div>

              <div>
                <%= f.label :avatar_url, "Avatar URL", class: "block text-sm font-medium text-gray-700" %>
                <%= f.url_field :avatar_url, 
                    class: "mt-1 block w-full border-gray-300 rounded-md shadow-sm focus:ring-indigo-500 focus:border-indigo-500",
                    placeholder: "https://example.com/avatar.jpg" %>
                <% if @profile_form.errors[:avatar_url].any? %>
                  <p class="mt-1 text-sm text-red-600"><%= @profile_form.errors[:avatar_url].first %></p>
                <% end %>
              </div>

              <div class="flex justify-end">
                <%= f.submit "Update Profile", 
                    class: "bg-indigo-600 hover:bg-indigo-700 text-white font-medium py-2 px-4 rounded-md focus:outline-none focus:ring-2 focus:ring-indigo-500" %>
              </div>
            <% end %>
          </div>
        </div>

        <!-- Password Section -->
        <div class="bg-white shadow rounded-lg">
          <div class="px-6 py-4 border-b border-gray-200">
            <h2 class="text-lg font-medium text-gray-900">Change Password</h2>
            <p class="mt-1 text-sm text-gray-600">Update your password to keep your account secure.</p>
          </div>
          
          <div class="px-6 py-4">
            <%= form_with model: @password_form, url: update_password_settings_path, 
                         method: :patch, local: true, class: "space-y-4" do |f| %>
              
              <div>
                <%= f.label :current_password, class: "block text-sm font-medium text-gray-700" %>
                <%= f.password_field :current_password, 
                    class: "mt-1 block w-full border-gray-300 rounded-md shadow-sm focus:ring-indigo-500 focus:border-indigo-500" %>
                <% if @password_form.errors[:current_password].any? %>
                  <p class="mt-1 text-sm text-red-600"><%= @password_form.errors[:current_password].first %></p>
                <% end %>
              </div>

              <div>
                <%= f.label :password, "New Password", class: "block text-sm font-medium text-gray-700" %>
                <%= f.password_field :password, 
                    class: "mt-1 block w-full border-gray-300 rounded-md shadow-sm focus:ring-indigo-500 focus:border-indigo-500" %>
                <% if @password_form.errors[:password].any? %>
                  <p class="mt-1 text-sm text-red-600"><%= @password_form.errors[:password].first %></p>
                <% end %>
              </div>

              <div>
                <%= f.label :password_confirmation, "Confirm New Password", class: "block text-sm font-medium text-gray-700" %>
                <%= f.password_field :password_confirmation, 
                    class: "mt-1 block w-full border-gray-300 rounded-md shadow-sm focus:ring-indigo-500 focus:border-indigo-500" %>
                <% if @password_form.errors[:password_confirmation].any? %>
                  <p class="mt-1 text-sm text-red-600"><%= @password_form.errors[:password_confirmation].first %></p>
                <% end %>
              </div>

              <div class="flex justify-end">
                <%= f.submit "Update Password", 
                    class: "bg-indigo-600 hover:bg-indigo-700 text-white font-medium py-2 px-4 rounded-md focus:outline-none focus:ring-2 focus:ring-indigo-500" %>
              </div>
            <% end %>
          </div>
        </div>

        <!-- Two-Factor Authentication Section -->
        <div class="bg-white shadow rounded-lg">
          <div class="px-6 py-4 border-b border-gray-200">
            <h2 class="text-lg font-medium text-gray-900">Two-Factor Authentication</h2>
            <p class="mt-1 text-sm text-gray-600">
              <% if @two_factor_enabled %>
                Two-factor authentication is currently <span class="font-medium text-green-600">enabled</span>.
              <% else %>
                Add an extra layer of security to your account.
              <% end %>
            </p>
          </div>
          
          <div class="px-6 py-4">
            <div class="flex items-center justify-between">
              <div>
                <h3 class="text-sm font-medium text-gray-900">Authenticator App</h3>
                <p class="text-sm text-gray-600">
                  <% if @two_factor_enabled %>
                    Your account is protected with two-factor authentication.
                  <% else %>
                    Use an authenticator app to generate verification codes.
                  <% end %>
                </p>
              </div>
              
              <div>
                <% if @two_factor_enabled %>
                  <%= link_to "Manage 2FA", two_factor_path, 
                      class: "bg-gray-100 hover:bg-gray-200 text-gray-800 font-medium py-2 px-4 rounded-md" %>
                <% else %>
                  <%= link_to "Enable 2FA", two_factor_path, 
                      class: "bg-indigo-600 hover:bg-indigo-700 text-white font-medium py-2 px-4 rounded-md" %>
                <% end %>
              </div>
            </div>
          </div>
        </div>

        <!-- Connected Accounts Section -->
        <div class="bg-white shadow rounded-lg">
          <div class="px-6 py-4 border-b border-gray-200">
            <h2 class="text-lg font-medium text-gray-900">Connected Accounts</h2>
            <p class="mt-1 text-sm text-gray-600">Manage your OAuth connections for quick sign-in.</p>
          </div>
          
          <div class="px-6 py-4">
            <div class="space-y-4">
              <% %w[google github slack].each do |provider| %>
                <% connected_account = @connected_accounts.find { |acc| acc.provider == provider } %>
                <div class="flex items-center justify-between py-3 border-b border-gray-100 last:border-b-0">
                  <div class="flex items-center">
                    <div class="flex-shrink-0">
                      <!-- Provider icon would go here -->
                      <div class="w-8 h-8 bg-gray-200 rounded-full flex items-center justify-center">
                        <span class="text-xs font-medium text-gray-600">
                          <%= provider[0].upcase %>
                        </span>
                      </div>
                    </div>
                    <div class="ml-3">
                      <p class="text-sm font-medium text-gray-900"><%= provider.humanize %></p>
                      <% if connected_account %>
                        <p class="text-sm text-gray-600">Connected as <%= connected_account.email %></p>
                      <% else %>
                        <p class="text-sm text-gray-600">Not connected</p>
                      <% end %>
                    </div>
                  </div>
                  
                  <div>
                    <% if connected_account %>
                      <%= link_to "Disconnect", oauth_account_path(connected_account), 
                          method: :delete,
                          confirm: "Are you sure you want to disconnect your #{provider.humanize} account?",
                          class: "text-red-600 hover:text-red-700 text-sm font-medium" %>
                    <% else %>
                      <%= link_to "Connect", "/auth/#{provider}", 
                          method: :post,
                          class: "text-indigo-600 hover:text-indigo-700 text-sm font-medium" %>
                    <% end %>
                  </div>
                </div>
              <% end %>
            </div>
          </div>
        </div>

        <!-- Preferences Section -->
        <div class="bg-white shadow rounded-lg">
          <div class="px-6 py-4 border-b border-gray-200">
            <h2 class="text-lg font-medium text-gray-900">Preferences</h2>
            <p class="mt-1 text-sm text-gray-600">Customize your experience and notification settings.</p>
          </div>
          
          <div class="px-6 py-4">
            <%= form_with model: @preferences_form, url: update_preferences_settings_path, 
                         method: :patch, local: true, class: "space-y-4" do |f| %>
              
              <div class="grid grid-cols-1 gap-4 sm:grid-cols-2">
                <div>
                  <%= f.label :locale, "Language", class: "block text-sm font-medium text-gray-700" %>
                  <%= f.select :locale, 
                      I18n.available_locales.map { |locale| [locale.to_s.humanize, locale.to_s] },
                      {},
                      { class: "mt-1 block w-full border-gray-300 rounded-md shadow-sm focus:ring-indigo-500 focus:border-indigo-500" } %>
                  <% if @preferences_form.errors[:locale].any? %>
                    <p class="mt-1 text-sm text-red-600"><%= @preferences_form.errors[:locale].first %></p>
                  <% end %>
                </div>

                <div>
                  <%= f.label :timezone, class: "block text-sm font-medium text-gray-700" %>
                  <%= f.select :timezone, 
                      ActiveSupport::TimeZone.all.map { |tz| [tz.to_s, tz.name] },
                      {},
                      { class: "mt-1 block w-full border-gray-300 rounded-md shadow-sm focus:ring-indigo-500 focus:border-indigo-500" } %>
                  <% if @preferences_form.errors[:timezone].any? %>
                    <p class="mt-1 text-sm text-red-600"><%= @preferences_form.errors[:timezone].first %></p>
                  <% end %>
                </div>
              </div>

              <div class="space-y-3">
                <div class="flex items-center">
                  <%= f.check_box :email_notifications, 
                      class: "h-4 w-4 text-indigo-600 border-gray-300 rounded focus:ring-indigo-500" %>
                  <%= f.label :email_notifications, "Email notifications", 
                      class: "ml-2 block text-sm text-gray-700" %>
                </div>

                <div class="flex items-center">
                  <%= f.check_box :push_notifications, 
                      class: "h-4 w-4 text-indigo-600 border-gray-300 rounded focus:ring-indigo-500" %>
                  <%= f.label :push_notifications, "Push notifications", 
                      class: "ml-2 block text-sm text-gray-700" %>
                </div>
              </div>

              <div class="flex justify-end">
                <%= f.submit "Update Preferences", 
                    class: "bg-indigo-600 hover:bg-indigo-700 text-white font-medium py-2 px-4 rounded-md focus:outline-none focus:ring-2 focus:ring-indigo-500" %>
              </div>
            <% end %>
          </div>
        </div>
      </div>
    </div>
  ERB

  # Add routes configuration instructions
  route <<~'ROUTES'
    # User Settings routes
    resource :settings, only: [:show], controller: 'user_settings' do
      member do
        patch :update_profile
        patch :update_password
        patch :update_preferences
      end
    end

    resources :oauth_accounts, only: [:destroy]
  ROUTES

  say_status :user_settings, "User settings module installed successfully!"
  say_status :next_steps, <<~STEPS
    1. Run: rails db:migrate
    2. Restart your Rails server
    3. Visit /settings to access the user settings dashboard
    4. Ensure the auth module is properly configured for OAuth providers
  STEPS
end