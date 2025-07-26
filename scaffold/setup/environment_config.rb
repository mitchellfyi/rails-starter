# frozen_string_literal: true

# Create environment configuration file
say "🔧 Creating environment configuration..."

create_file '.env.example', <<~ENV
  # Database
  DATABASE_URL=postgresql://localhost/rails_starter_development
  
  # Redis
  REDIS_URL=redis://localhost:6379/0
  
  # Devise
  DEVISE_SECRET_KEY=your_secret_key_here
  
  # OmniAuth Providers
  GOOGLE_OAUTH_CLIENT_ID=your_google_client_id
  GOOGLE_OAUTH_CLIENT_SECRET=your_google_client_secret
  
  GITHUB_OAUTH_CLIENT_ID=your_github_client_id
  GITHUB_OAUTH_CLIENT_SECRET=your_github_client_secret
  
  SLACK_OAUTH_CLIENT_ID=your_slack_client_id
  SLACK_OAUTH_CLIENT_SECRET=your_slack_client_secret
ENV

# Create model configurations
say "📝 Configuring models..."

# Update User model with enhanced features
user_model_additions = <<~RUBY
  
  # Devise modules
  devise :database_authenticatable, :registerable, :recoverable, :rememberable, 
         :validatable, :confirmable, :lockable, :timeoutable

  # Associations
  has_many :memberships, dependent: :destroy
  has_many :workspaces, through: :memberships
  
  # Validations
  validates :first_name, :last_name, presence: true
  
  # Scopes
  scope :admins, -> { where(admin: true) }
  
  # Methods
  def full_name
    "#{first_name} #{last_name}".strip
  end
  
  def admin?
    admin == true
  end
  
  def member_of?(workspace)
    memberships.where(workspace: workspace, active: true).exists?
  end
  
  def role_in(workspace)
    memberships.find_by(workspace: workspace, active: true)&.role
  end
  
  # OmniAuth
  def self.from_omniauth(auth)
    where(email: auth.info.email).first_or_create do |user|
      user.email = auth.info.email
      user.password = Devise.friendly_token[0, 20]
      user.first_name = auth.info.first_name || auth.info.name&.split(' ')&.first || ''
      user.last_name = auth.info.last_name || auth.info.name&.split(' ')&.last || ''
      user.provider = auth.provider
      user.uid = auth.uid
      user.confirmed_at = Time.current # Auto-confirm OAuth users
    end
  end
RUBY

inject_into_file 'app/models/user.rb', user_model_additions, 
                 after: "class User < ApplicationRecord\n"

# Update Workspace model with slug and associations
workspace_model_additions = <<~RUBY
  
  extend FriendlyId
  friendly_id :name, use: :slugged
  
  # Associations
  has_many :memberships, dependent: :destroy
  has_many :users, through: :memberships
  has_many :invitations, dependent: :destroy
  
  # Validations
  validates :name, presence: true, uniqueness: true
  validates :slug, presence: true, uniqueness: true
  
  # Scopes
  scope :active, -> { joins(:memberships).where(memberships: { active: true }).distinct }
  
  # Methods
  def owners
    users.joins(:memberships).where(memberships: { role: 'owner', active: true })
  end
  
  def admins
    users.joins(:memberships).where(memberships: { role: ['owner', 'admin'], active: true })
  end
  
  def members
    users.joins(:memberships).where(memberships: { active: true })
  end
RUBY

inject_into_file 'app/models/workspace.rb', workspace_model_additions,
                 after: "class Workspace < ApplicationRecord\n"

# Update Membership model with validations and enums
membership_model_additions = <<~RUBY
  
  # Associations
  belongs_to :workspace
  belongs_to :user
  
  # Validations
  validates :role, presence: true, inclusion: { in: %w[member admin owner] }
  validates :user_id, uniqueness: { scope: :workspace_id }
  
  # Scopes
  scope :active, -> { where(active: true) }
  scope :by_role, ->(role) { where(role: role) }
  
  # Methods
  def owner?
    role == 'owner'
  end
  
  def admin?
    role.in?(['admin', 'owner'])
  end
  
  def can_manage_members?
    admin?
  end
  
  def can_invite_members?
    admin?
  end
RUBY

inject_into_file 'app/models/membership.rb', membership_model_additions,
                 after: "class Membership < ApplicationRecord\n"

# Update Invitation model
invitation_model_additions = <<~RUBY
  
  # Associations
  belongs_to :workspace
  
  # Validations
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :role, presence: true, inclusion: { in: %w[member admin] }
  validates :token, presence: true, uniqueness: true
  
  # Callbacks
  before_validation :generate_token, on: :create
  before_validation :set_expiration, on: :create
  
  # Scopes
  scope :pending, -> { where(accepted_at: nil) }
  scope :expired, -> { where('expires_at < ?', Time.current) }
  scope :valid, -> { where(accepted_at: nil).where('expires_at > ?', Time.current) }
  
  # Methods
  def accepted?
    accepted_at.present?
  end
  
  def expired?
    expires_at < Time.current
  end
  
  def accept!(user)
    return false if expired? || accepted?
    
    membership = workspace.memberships.create!(
      user: user,
      role: role,
      active: true
    )
    
    update!(accepted_at: Time.current) if membership.persisted?
    membership
  end
  
  private
  
  def generate_token
    self.token = SecureRandom.urlsafe_base64(32)
  end
  
  def set_expiration
    self.expires_at = 7.days.from_now
  end
RUBY

inject_into_file 'app/models/invitation.rb', invitation_model_additions,
                 after: "class Invitation < ApplicationRecord\n"
