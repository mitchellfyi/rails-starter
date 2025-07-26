# frozen_string_literal: true

# Configure JSON:API serializers
say "📋 Setting up JSON:API serializers..."

run 'mkdir -p app/serializers'

create_file 'app/serializers/application_serializer.rb', <<~RUBY
  # frozen_string_literal: true

class ApplicationSerializer
    include JSONAPI::Serializer
  end
RUBY

create_file 'app/serializers/user_serializer.rb', <<~RUBY
  # frozen_string_literal: true

  class UserSerializer < ApplicationSerializer
    attributes :id, :email, :first_name, :last_name, :created_at, :updated_at
    
    has_many :memberships
    has_many :workspaces, through: :memberships
  end
RUBY

create_file 'app/serializers/workspace_serializer.rb', <<~RUBY
  # frozen_string_literal: true

  class WorkspaceSerializer < ApplicationSerializer
    attributes :id, :name, :slug, :description, :created_at, :updated_at
    
    has_many :memberships
    has_many :users, through: :memberships
  end
RUBY
