#!/usr/bin/env ruby

# Simple script to initialize data for demo
require_relative 'config/environment'

begin
  # Clear existing data
  begin
    AuditLog.delete_all
  rescue
  end
  
  begin
    Workspace.delete_all
  rescue
  end
  
  begin
    User.delete_all
  rescue
  end

  # Create admin user
  admin = User.create!(
    email: 'admin@example.com',
    first_name: 'Admin',
    last_name: 'User',
    admin: true
  )
  
  # Create sample workspaces
  workspace1 = Workspace.create!(
    name: 'Sample Workspace',
    monthly_ai_credit: 100.0,
    current_month_usage: 25.50
  )
  
  workspace2 = Workspace.create!(
    name: 'Development Environment',
    monthly_ai_credit: 50.0,
    current_month_usage: 12.75
  )
  
  # Create sample audit logs
  AuditLog.create!(
    user: admin,
    action: 'login',
    description: 'Admin user logged in',
    metadata: { ip: '127.0.0.1' }.to_json
  )
  
  AuditLog.create!(
    user: admin,
    action: 'workspace_created',
    description: 'Created new workspace',
    resource_type: 'Workspace',
    resource_id: workspace1.id,
    metadata: { workspace_name: workspace1.name }.to_json
  )
  
  puts "Demo data initialized successfully!"
  puts "Admin user: #{admin.email}"
  puts "Workspaces: #{Workspace.count}"
  puts "Audit logs: #{AuditLog.count}"
  
rescue => e
  puts "Error initializing data: #{e.message}"
  puts e.backtrace.first(5)
end