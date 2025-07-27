# frozen_string_literal: true

require 'test_helper'

class AiProviderTest < ActiveSupport::TestCase
  setup do
    @ai_provider = AiProvider.new(
      name: "Test Provider",
      slug: "test_provider",
      description: "A test AI provider",
      api_base_url: "https://api.test.com",
      supported_models: ["test-model-1", "test-model-2"],
      default_config: { temperature: 0.7, max_tokens: 1000 }
    )
  end

  test "should be valid with required attributes" do
    assert @ai_provider.valid?
  end

  test "should require name" do
    @ai_provider.name = nil
    assert_not @ai_provider.valid?
    assert_includes @ai_provider.errors[:name], "can't be blank"
  end

  test "should require unique name" do
    @ai_provider.save!
    duplicate = AiProvider.new(
      name: @ai_provider.name,
      slug: "different_slug",
      api_base_url: "https://api.different.com"
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:name], "has already been taken"
  end

  test "should require valid api_base_url format" do
    @ai_provider.api_base_url = "invalid-url"
    assert_not @ai_provider.valid?
    assert_includes @ai_provider.errors[:api_base_url], "is invalid"
  end

  test "should generate slug from name if blank" do
    @ai_provider.slug = nil
    @ai_provider.valid?
    assert_equal "test_provider", @ai_provider.slug
  end

  test "should check if model is supported" do
    @ai_provider.save!
    assert @ai_provider.supports_model?("test-model-1")
    assert @ai_provider.supports_model?(:test_model_2)
    assert_not @ai_provider.supports_model?("unsupported-model")
  end

  test "should return config for model" do
    @ai_provider.save!
    config = @ai_provider.config_for_model("test-model-1")
    assert_equal "test-model-1", config[:model]
    assert_equal 0.7, config[:temperature]
    assert_equal 1000, config[:max_tokens]
  end

  test "should scope active providers" do
    @ai_provider.active = false
    @ai_provider.save!
    
    active_provider = AiProvider.create!(
      name: "Active Provider",
      slug: "active_provider",
      api_base_url: "https://api.active.com",
      active: true
    )
    
    assert_includes AiProvider.active, active_provider
    assert_not_includes AiProvider.active, @ai_provider
  end

  test "should order by priority" do
    @ai_provider.priority = 2
    @ai_provider.save!
    
    high_priority = AiProvider.create!(
      name: "High Priority",
      slug: "high_priority",
      api_base_url: "https://api.high.com",
      priority: 1
    )
    
    providers = AiProvider.by_priority
    assert_equal high_priority, providers.first
    assert_equal @ai_provider, providers.last
  end
end