# frozen_string_literal: true

require 'test_helper'

class PromptTemplateTest < ActiveSupport::TestCase
  def setup
    @template = PromptTemplate.create!(
      name: 'Test Template',
      prompt_body: 'Hello {{name}}, welcome to {{company}}!',
      output_format: 'text'
    )
  end

  test 'should be valid with required attributes' do
    template = PromptTemplate.new(
      name: 'Valid Template',
      prompt_body: 'Test prompt',
      output_format: 'text'
    )
    assert template.valid?
  end

  test 'should require name' do
    template = PromptTemplate.new(prompt_body: 'Test', output_format: 'text')
    assert_not template.valid?
    assert_includes template.errors[:name], "can't be blank"
  end

  test 'should require prompt_body' do
    template = PromptTemplate.new(name: 'Test', output_format: 'text')
    assert_not template.valid?
    assert_includes template.errors[:prompt_body], "can't be blank"
  end

  test 'should require valid output_format' do
    template = PromptTemplate.new(
      name: 'Test',
      prompt_body: 'Test',
      output_format: 'invalid'
    )
    assert_not template.valid?
    assert_includes template.errors[:output_format], 'is not included in the list'
  end

  test 'should generate slug from name if slug is blank' do
    template = PromptTemplate.create!(
      name: 'My Test Template!',
      prompt_body: 'Test',
      output_format: 'text'
    )
    assert_equal 'my_test_template', template.slug
  end

  test 'should extract variable names from prompt body' do
    variables = @template.variable_names
    assert_equal ['name', 'company'], variables
  end

  test 'should handle prompt body without variables' do
    template = PromptTemplate.new(prompt_body: 'No variables here')
    assert_equal [], template.variable_names
  end

  test 'should render with context' do
    context = { 'name' => 'John', 'company' => 'Acme Corp' }
    rendered = @template.render_with_context(context)
    assert_equal 'Hello John, welcome to Acme Corp!', rendered
  end

  test 'should render with symbol keys in context' do
    context = { name: 'John', company: 'Acme Corp' }
    rendered = @template.render_with_context(context)
    assert_equal 'Hello John, welcome to Acme Corp!', rendered
  end

  test 'should handle missing variables in context' do
    context = { 'name' => 'John' }
    rendered = @template.render_with_context(context)
    assert_equal 'Hello John, welcome to !', rendered
  end

  test 'should validate context and return true for complete context' do
    context = { 'name' => 'John', 'company' => 'Acme' }
    assert_equal true, @template.validate_context(context)
  end

  test 'should validate context and return missing variables' do
    context = { 'name' => 'John' }
    missing = @template.validate_context(context)
    assert_equal ['company'], missing
  end

  test 'should generate preview with sample context' do
    preview = @template.preview_with_sample_context
    assert_equal 'Hello [name_value], welcome to [company_value]!', preview
  end

  test 'should track versions with paper_trail' do
    assert_difference '@template.versions.count', 1 do
      @template.update!(name: 'Updated Name')
    end
  end

  test 'should create new version' do
    assert_difference 'PromptTemplate.count', 1 do
      new_version = @template.create_new_version!(name: 'New Version')
      assert_equal '1.0.1', new_version.version
      assert_not new_version.published?
    end
  end

  test 'should publish template' do
    @template.update!(published: false)
    @template.publish!
    
    assert @template.published?
    assert @template.active?
  end

  test 'should get version history' do
    new_version = @template.create_new_version!
    
    history = @template.version_history
    assert_includes history, @template
    assert_includes history, new_version
  end

  test 'should identify latest version' do
    assert @template.latest_version?
    
    new_version = @template.create_new_version!
    assert new_version.latest_version?
    
    @template.reload
    assert @template.latest_version? # Still latest by date created
  end

  test 'should get diff with version' do
    @template.update!(name: 'Updated Name')
    version = @template.versions.last
    
    diff = @template.diff_with_version(version.id)
    assert_not_nil diff
    assert_equal 'Test Template', diff[:previous][:name]
    assert_equal 'Updated Name', diff[:current][:name]
  end
end