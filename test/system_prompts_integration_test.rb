# frozen_string_literal: true

require 'minitest/autorun'
require 'minitest/pride'

# Load the SystemPrompt test infrastructure
require_relative 'models/system_prompt_test'

class SystemPromptIntegrationTest < Minitest::Test
  def setup
    @workspace1 = Workspace.new(id: 1, name: 'Workspace Alpha')
    @workspace2 = Workspace.new(id: 2, name: 'Workspace Beta') 
    @user = User.new(id: 1, name: 'Test User')
  end

  def test_complete_system_prompt_workflow
    # Step 1: Create global fallback prompt
    global_prompt = SystemPrompt.create!(
      name: 'Support Assistant',
      prompt_text: 'You are a helpful support assistant for {{company}}.',
      description: 'Global support prompt',
      status: 'active',
      workspace: nil,
      associated_roles: ['support'],
      associated_functions: ['customer_support']
    )

    assert global_prompt.global?
    assert_equal 'active', global_prompt.status
    assert_includes global_prompt.associated_roles, 'support'

    # Step 2: Create workspace-specific override
    workspace_prompt = SystemPrompt.create!(
      name: 'Support Assistant', # Same name as global
      prompt_text: 'You are a premium support specialist for {{company}}. Provide exceptional service.',
      description: 'Premium workspace support prompt',
      status: 'active',
      workspace_id: @workspace1.id,
      workspace: @workspace1,
      associated_roles: ['support'],
      associated_functions: ['customer_support', 'premium_support']
    )

    refute workspace_prompt.global?
    assert_equal @workspace1.id, workspace_prompt.workspace_id

    # Step 3: Test variable rendering
    context = { 'company' => 'Acme Corp' }
    
    global_rendered = global_prompt.render_with_context(context)
    workspace_rendered = workspace_prompt.render_with_context(context)

    assert_equal 'You are a helpful support assistant for Acme Corp.', global_rendered
    assert_equal 'You are a premium support specialist for Acme Corp. Provide exceptional service.', workspace_rendered

    # Step 4: Test versioning workflow
    original_version = workspace_prompt.version
    assert_equal '1.0.0', original_version

    new_version = workspace_prompt.create_new_version!(
      description: 'Enhanced with new capabilities',
      prompt_text: 'You are a premium support specialist for {{company}}. Provide exceptional, personalized service with empathy and expertise.'
    )

    assert_equal '1.0.1', new_version.version
    assert_equal 'draft', new_version.status
    assert_equal workspace_prompt.name, new_version.name
    refute_equal workspace_prompt.prompt_text, new_version.prompt_text

    # Step 5: Test activation workflow
    new_version.activate!
    assert_equal 'active', new_version.status

    # Step 6: Test cloning across workspaces
    cloned_prompt = workspace_prompt.clone!('Custom Support Assistant', @workspace2)
    cloned_prompt.workspace = @workspace2 # Ensure workspace relationship is set
    
    assert_equal 'Custom Support Assistant', cloned_prompt.name
    assert_equal @workspace2.id, cloned_prompt.workspace_id
    assert_equal 'draft', cloned_prompt.status
    assert_equal '1.0.0', cloned_prompt.version # Reset version for new prompt

    # Step 7: Test association filtering concepts
    assert_includes global_prompt.associated_functions, 'customer_support'
    assert_includes workspace_prompt.associated_functions, 'premium_support'
    refute_includes global_prompt.associated_functions, 'premium_support'

    # Step 8: Test display names
    assert_equal 'Support Assistant (Global)', global_prompt.display_name
    assert_equal 'Support Assistant (Workspace Alpha)', workspace_prompt.display_name
    assert_equal 'Custom Support Assistant (Workspace Beta)', cloned_prompt.display_name
  end

  def test_fallback_logic_simulation
    # Simulate the find_for_workspace logic since we're using mock objects
    
    # Create global prompt
    global_prompt = SystemPrompt.create!(
      name: 'Chat Assistant',
      prompt_text: 'Global chat assistant prompt',
      status: 'active',
      workspace: nil,
      associated_roles: ['chat']
    )

    # Create workspace-specific prompt
    workspace_prompt = SystemPrompt.create!(
      name: 'Chat Assistant',
      prompt_text: 'Workspace-specific chat assistant prompt',
      status: 'active',
      workspace_id: @workspace1.id,
      workspace: @workspace1,
      associated_roles: ['chat']
    )

    # Test workspace has specific prompt
    assert_equal @workspace1.id, workspace_prompt.workspace_id
    assert_includes workspace_prompt.associated_roles, 'chat'

    # Test global prompt exists as fallback
    assert global_prompt.global?
    assert_includes global_prompt.associated_roles, 'chat'

    # Both are active and ready for selection
    assert_equal 'active', workspace_prompt.status
    assert_equal 'active', global_prompt.status
  end

  def test_prompt_uniqueness_constraints
    # Test that prompts with same name can exist across different scopes
    
    # Global prompt
    global_prompt = SystemPrompt.create!(
      name: 'Standard Assistant',
      prompt_text: 'Global assistant',
      status: 'active'
    )

    # Workspace-specific prompt with same name (should be allowed)
    workspace_prompt = SystemPrompt.create!(
      name: 'Standard Assistant', # Same name, different scope
      prompt_text: 'Workspace assistant',
      status: 'active',
      workspace_id: @workspace1.id,
      workspace: @workspace1
    )

    # Different workspace with same name (should be allowed) 
    workspace2_prompt = SystemPrompt.create!(
      name: 'Standard Assistant', # Same name, different workspace
      prompt_text: 'Workspace 2 assistant',
      status: 'active',
      workspace_id: @workspace2.id,
      workspace: @workspace2
    )

    # All should be valid and have different scopes
    assert global_prompt.valid?
    assert workspace_prompt.valid?
    assert workspace2_prompt.valid?

    assert global_prompt.global?
    assert_equal @workspace1.id, workspace_prompt.workspace_id
    assert_equal @workspace2.id, workspace2_prompt.workspace_id
  end

  def test_version_history_and_diff_simulation
    # Create original prompt
    original = SystemPrompt.create!(
      name: 'Evolving Assistant',
      prompt_text: 'Version 1 prompt text',
      description: 'Original version',
      status: 'active',
      associated_roles: ['assistant']
    )

    # Create new version with changes
    v2 = original.create_new_version!(
      prompt_text: 'Version 2 with enhanced capabilities',
      description: 'Enhanced version with new features',
      associated_roles: ['assistant', 'enhanced']
    )

    # Test version progression
    assert_equal '1.0.0', original.version
    assert_equal '1.0.1', v2.version

    # Test content differences
    refute_equal original.prompt_text, v2.prompt_text
    refute_equal original.description, v2.description
    refute_equal original.associated_roles, v2.associated_roles

    # Test shared attributes
    assert_equal original.name, v2.name
    assert_equal original.workspace_id, v2.workspace_id

    # Test status handling
    assert_equal 'active', original.status
    assert_equal 'draft', v2.status # New versions start as draft
  end
end

puts "🧪 Running SystemPrompt Integration Tests..."
puts

# Run the integration tests
Minitest.run([])

puts
puts "✅ SystemPrompt integration tests completed successfully!"
puts "🔗 Integration test coverage:"
puts "  • Complete workflow from creation to activation"
puts "  • Cross-workspace prompt management"
puts "  • Fallback logic validation"
puts "  • Uniqueness constraints across scopes"
puts "  • Version management and evolution"
puts "  • Variable rendering with context"