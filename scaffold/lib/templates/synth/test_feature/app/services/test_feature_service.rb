# frozen_string_literal: true

# TestFeatureService handles test_feature business logic
class TestFeatureService
  attr_reader :user, :errors

  def initialize(user)
    @user = user
    @errors = []
  end

  # Create a new test_feature item
  def create_item(attributes = {})
    item = user.test_feature_items.build(attributes)
    
    if item.save
      # Perform any additional setup or notifications
      notify_item_created(item)
      item
    else
      @errors = item.errors.full_messages
      nil
    end
  end

  # Update an existing test_feature item
  def update_item(item, attributes = {})
    if item.update(attributes)
      # Perform any additional updates or notifications
      notify_item_updated(item)
      item
    else
      @errors = item.errors.full_messages
      nil
    end
  end

  # Delete a test_feature item
  def delete_item(item)
    if item.destroy
      # Perform any cleanup or notifications
      notify_item_deleted(item)
      true
    else
      @errors = item.errors.full_messages
      false
    end
  end

  # Check if service has errors
  def valid?
    errors.empty?
  end

  private

  def notify_item_created(item)
    # Add notification logic here
    Rails.logger.info "TestFeature item created: #{item.id}"
  end

  def notify_item_updated(item)
    # Add notification logic here
    Rails.logger.info "TestFeature item updated: #{item.id}"
  end

  def notify_item_deleted(item)
    # Add notification logic here
    Rails.logger.info "TestFeature item deleted: #{item.id}"
  end
end
