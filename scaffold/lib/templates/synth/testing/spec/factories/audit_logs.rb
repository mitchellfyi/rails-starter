# frozen_string_literal: true

FactoryBot.define do
  factory :audit_log do
    user
    action { 'create' }
    resource_type { 'User' }
    resource_id { user.id }
    changes { { 'email' => ['old@example.com', 'new@example.com'] } }
    ip_address { '192.168.1.1' }
    user_agent { 'Mozilla/5.0' }
    
    trait :update_action do
      action { 'update' }
      changes { { 'name' => ['Old Name', 'New Name'] } }
    end
    
    trait :delete_action do
      action { 'destroy' }
      changes { {} }
    end
    
    trait :admin_action do
      action { 'admin_impersonation' }
      resource_type { 'User' }
    end
  end
end