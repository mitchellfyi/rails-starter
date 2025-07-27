# frozen_string_literal: true

# Shared examples for audit logging functionality
# These examples test common patterns for audit logging across modules

RSpec.shared_examples 'an audit logger' do
  describe '.create_log' do
    let(:user) { double('User', id: 1, email: 'test@example.com') }
    
    it 'creates an audit log with required fields' do
      log = described_class.create_log(
        user: user,
        action: 'test_action',
        description: 'Test audit log entry'
      )
      
      expect(log).to be_persisted
      expect(log.user).to eq(user)
      expect(log.action).to eq('test_action')
      expect(log.description).to eq('Test audit log entry')
    end

    it 'creates an audit log with optional fields' do
      metadata = { key: 'value', count: 5 }
      
      log = described_class.create_log(
        user: user,
        action: 'test_action',
        resource_type: 'TestModel',
        resource_id: 123,
        description: 'Test with optional fields',
        metadata: metadata,
        ip_address: '192.168.1.1',
        user_agent: 'Test Browser'
      )
      
      expect(log.resource_type).to eq('TestModel')
      expect(log.resource_id).to eq(123)
      expect(log.metadata).to eq(metadata)
      expect(log.ip_address).to eq('192.168.1.1')
      expect(log.user_agent).to eq('Test Browser')
    end

    it 'allows nil user for system actions' do
      log = described_class.create_log(
        user: nil,
        action: 'system_action',
        description: 'System generated log'
      )
      
      expect(log).to be_persisted
      expect(log.user).to be_nil
    end
  end
end

RSpec.shared_examples 'an audit log with scopes' do
  let(:user1) { double('User', id: 1, email: 'user1@example.com') }
  let(:user2) { double('User', id: 2, email: 'user2@example.com') }

  before do
    # Create test audit logs
    described_class.create_log(
      user: user1,
      action: 'create',
      resource_type: 'Post',
      resource_id: 1,
      description: 'Created a post'
    )
    
    described_class.create_log(
      user: user1,
      action: 'update',
      resource_type: 'Post',
      resource_id: 1,
      description: 'Updated a post'
    )
    
    described_class.create_log(
      user: user2,
      action: 'delete',
      resource_type: 'Comment',
      resource_id: 5,
      description: 'Deleted a comment'
    )
  end

  describe '.recent' do
    it 'orders logs by created_at desc' do
      logs = described_class.recent
      expect(logs.first.created_at).to be >= logs.last.created_at
    end
  end

  describe '.for_action' do
    it 'filters logs by action' do
      logs = described_class.for_action('create')
      expect(logs.count).to eq(1)
      expect(logs.first.action).to eq('create')
    end
  end

  describe '.for_resource_type' do
    it 'filters logs by resource type' do
      logs = described_class.for_resource_type('Post')
      expect(logs.count).to eq(2)
      logs.each { |log| expect(log.resource_type).to eq('Post') }
    end
  end

  describe '.for_user' do
    it 'filters logs by user ID' do
      logs = described_class.for_user(user1.id)
      expect(logs.count).to eq(2)
      logs.each { |log| expect(log.user).to eq(user1) }
    end
  end
end

RSpec.shared_examples 'an audit log with validations' do
  describe 'validations' do
    it 'requires action' do
      log = described_class.new(description: 'Test')
      expect(log).not_to be_valid
      expect(log.errors[:action]).to include("can't be blank")
    end

    it 'requires description' do
      log = described_class.new(action: 'test')
      expect(log).not_to be_valid
      expect(log.errors[:description]).to include("can't be blank")
    end

    it 'is valid with minimal required fields' do
      log = described_class.new(
        action: 'test_action',
        description: 'Test description'
      )
      expect(log).to be_valid
    end
  end
end

RSpec.shared_examples 'an audit log with user tracking' do
  let(:user) { double('User', id: 1, email: 'test@example.com') }

  describe '.log_login' do
    it 'creates a login audit log' do
      log = described_class.log_login(
        user,
        ip_address: '192.168.1.1',
        user_agent: 'Test Browser'
      )
      
      expect(log.action).to eq('login')
      expect(log.resource_type).to eq('User')
      expect(log.resource_id).to eq(user.id)
      expect(log.description).to include(user.email)
      expect(log.ip_address).to eq('192.168.1.1')
      expect(log.user_agent).to eq('Test Browser')
    end
  end

  describe '.log_impersonation' do
    let(:admin_user) { double('User', id: 2, email: 'admin@example.com') }
    let(:target_user) { double('User', id: 3, email: 'target@example.com') }

    it 'creates an impersonation start log' do
      log = described_class.log_impersonation(
        admin_user,
        target_user,
        'start',
        ip_address: '192.168.1.1'
      )
      
      expect(log.action).to eq('impersonation_start')
      expect(log.user).to eq(admin_user)
      expect(log.resource_type).to eq('User')
      expect(log.resource_id).to eq(target_user.id)
      expect(log.description).to include('Start impersonating')
      expect(log.description).to include(target_user.email)
      expect(log.metadata[:target_user_id]).to eq(target_user.id)
      expect(log.metadata[:target_user_email]).to eq(target_user.email)
    end

    it 'creates an impersonation end log' do
      log = described_class.log_impersonation(
        admin_user,
        target_user,
        'end'
      )
      
      expect(log.action).to eq('impersonation_end')
      expect(log.description).to include('End impersonating')
    end
  end
end

RSpec.shared_examples 'an audit log with AI tracking' do
  let(:user) { double('User', id: 1, email: 'test@example.com') }
  let(:ai_output) { double('AIOutput', id: 42, content: 'This is a long AI generated response for testing purposes') }

  describe '.log_ai_review' do
    it 'creates an AI review audit log' do
      log = described_class.log_ai_review(
        user,
        ai_output,
        'positive',
        ip_address: '192.168.1.1'
      )
      
      expect(log.action).to eq('ai_output_review')
      expect(log.user).to eq(user)
      expect(log.resource_type).to eq('AIOutput')
      expect(log.description).to include('Reviewed AI output with rating: positive')
      expect(log.metadata[:ai_output_id]).to eq(42)
      expect(log.metadata[:rating]).to eq('positive')
      expect(log.metadata[:output_preview]).to include('This is a long AI generated')
    end

    it 'handles nil AI output' do
      log = described_class.log_ai_review(
        user,
        nil,
        'negative'
      )
      
      expect(log.metadata[:ai_output_id]).to be_nil
      expect(log.metadata[:output_preview]).to be_nil
    end
  end
end

RSpec.shared_examples 'an audit log with formatting' do
  let(:user) { double('User', id: 1, email: 'test@example.com') }

  describe '#formatted_metadata' do
    it 'returns "None" for blank metadata' do
      log = described_class.new(metadata: nil)
      expect(log.formatted_metadata).to eq('None')
      
      log = described_class.new(metadata: {})
      expect(log.formatted_metadata).to eq('None')
    end

    it 'formats metadata as key-value pairs' do
      metadata = { user_id: 123, action_type: 'create', count: 5 }
      log = described_class.new(metadata: metadata)
      
      formatted = log.formatted_metadata
      expect(formatted).to include('User id: 123')
      expect(formatted).to include('Action type: create')
      expect(formatted).to include('Count: 5')
    end
  end

  describe '#time_ago' do
    it 'returns time ago in words' do
      log = described_class.new(created_at: 2.hours.ago)
      expect(log.time_ago).to include('about 2 hours')
    end
  end
end

RSpec.shared_examples 'an audit log with resource tracking' do
  let(:user) { double('User', id: 1, email: 'test@example.com') }

  it 'tracks resource creation' do
    log = described_class.create_log(
      user: user,
      action: 'create',
      resource_type: 'Post',
      resource_id: 123,
      description: 'Created new post'
    )
    
    expect(log.action).to eq('create')
    expect(log.resource_type).to eq('Post')
    expect(log.resource_id).to eq(123)
  end

  it 'tracks resource updates with changes' do
    changes = { title: ['Old Title', 'New Title'], status: ['draft', 'published'] }
    
    log = described_class.create_log(
      user: user,
      action: 'update',
      resource_type: 'Post',
      resource_id: 123,
      description: 'Updated post',
      metadata: { changes: changes }
    )
    
    expect(log.metadata[:changes]).to eq(changes)
  end

  it 'tracks resource deletion' do
    log = described_class.create_log(
      user: user,
      action: 'delete',
      resource_type: 'Post',
      resource_id: 123,
      description: 'Deleted post'
    )
    
    expect(log.action).to eq('delete')
    expect(log.resource_type).to eq('Post')
  end
end